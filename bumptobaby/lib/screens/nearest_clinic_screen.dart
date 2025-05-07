import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../widgets/clinic_details_sheet.dart';


class NearestClinicMapScreen extends StatefulWidget {
  const NearestClinicMapScreen({Key? key}) : super(key: key);

  @override
  State<NearestClinicMapScreen> createState() => _NearestClinicMapScreenState();
}

class _NearestClinicMapScreenState extends State<NearestClinicMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  LatLng? _currentLocation;
  String status = 'Loading map...';
  BitmapDescriptor? clinicIcon;

  double _selectedRadius = 3000; // default 3km

  final List<double> _radiusOptions = [1000, 3000, 5000]; // 1km, 3km, 5km

  @override
  void initState() {
    super.initState();
    _loadMapAndClinics();
  }

  Future<void> _loadMapAndClinics() async {
    try {
      final locationService = LocationService();
      final placesService = PlacesService();

      Position position = await locationService.getCurrentLocation();
      LatLng userLatLng = LatLng(position.latitude, position.longitude);

      List<dynamic> clinics = await placesService.findNearbyClinics(
        position,
        radius: _selectedRadius,
      );

      Set<Marker> markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: userLatLng,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      };

      for (var clinic in clinics) {
  final lat = clinic['geometry']['location']['lat'];
  final lng = clinic['geometry']['location']['lng'];
  final placeId = clinic['place_id'];

  final marker = Marker(
  markerId: MarkerId(placeId),
  position: LatLng(lat, lng),
  icon: clinicIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
  infoWindow: InfoWindow(
    title: clinic['name'],
    onTap: () async {
      try {
        final details = await placesService.getClinicDetails(placeId);
        showModalBottomSheet(
          context: context,
          builder: (context) => ClinicDetailsSheet(details: details),
        );
      } catch (e) {
        debugPrint('Error loading details: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load clinic details.')),
        );
      }
    },
  ),
);
markers.add(marker);


  //   icon: clinicIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
  // );
  // markers.add(marker);
}


      setState(() {
        _currentLocation = userLatLng;
        _markers = markers;
        status = clinics.isEmpty ? 'No clinics found nearby.' : 'Clinics loaded!';
      });

      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(userLatLng, 14),
      );
    } catch (e) {
      setState(() {
        status = 'Error: $e';
      });
    }
  }

  Future<void> _openDirections(double lat, double lng, String name) async {
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Clinics Map'),
        actions: [
          DropdownButton<double>(
            value: _selectedRadius,
            dropdownColor: Colors.white,
            underline: Container(),
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            items: _radiusOptions.map((radius) {
              return DropdownMenuItem(
                value: radius,
                child: Text('${(radius / 1000).toStringAsFixed(1)} km'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedRadius = value;
                  status = 'Reloading clinics...';
                });
                _loadMapAndClinics();
              }
            },
          ),
        ],
      ),
      body: _currentLocation == null
          ? Center(child: Text(status))
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation!,
                zoom: 14,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) => _mapController.complete(controller),
            ),
    );
  }
}
