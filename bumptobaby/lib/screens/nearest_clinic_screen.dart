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
  List<dynamic> clinics = [];
  double _selectedRadius = 3000;
  final List<double> _radiusOptions = [1000, 3000, 5000];

  bool showListView = false;
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

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

      final loadedClinics = await placesService.findCombinedClinics(
        position,
        radius: _selectedRadius,
      );
      print('Total combined clinics found: ${loadedClinics.length}');

      Set<Marker> markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: userLatLng,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      };

      for (var clinic in loadedClinics) {
        final lat = clinic['geometry']['location']['lat'];
        final lng = clinic['geometry']['location']['lng'];
        final placeId = clinic['place_id'];
        final name = clinic['name'];
        final types = List<String>.from(clinic['types'] ?? []);
        final rating = clinic['rating']?.toString() ?? 'N/A';

        final isMaternity = name.toLowerCase().contains('maternity') ||
            name.toLowerCase().contains('prenatal') ||
            types.contains('doctor');

        final markerColor =
            isMaternity ? BitmapDescriptor.hueRose : BitmapDescriptor.hueAzure;

        final marker = Marker(
          markerId: MarkerId(placeId),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerColor),
          infoWindow: InfoWindow(
            title: name,
            snippet: 'Rating: $rating ★',
            onTap: () async {
              try {
                final details = await placesService.getClinicDetails(placeId);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
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
      }

      setState(() {
        _currentLocation = userLatLng;
        _markers = markers;
        clinics = loadedClinics;
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

  @override
  Widget build(BuildContext context) {
    final filteredClinics = clinics.where((clinic) {
      final name = clinic['name'].toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Clinics Map'),
        actions: [
          IconButton(
            icon: Icon(showListView ? Icons.map : Icons.list),
            onPressed: () {
              setState(() {
                showListView = !showListView;
              });
            },
          ),
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
          : showListView
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search clinic name...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredClinics.length,
                        itemBuilder: (context, index) {
                          final clinic = filteredClinics[index];
                          final name = clinic['name'];
                          final vicinity = clinic['vicinity'] ?? '';
                          final rating =
                              clinic['rating']?.toString() ?? 'N/A';
                          final lat = clinic['geometry']['location']['lat'];
                          final lng = clinic['geometry']['location']['lng'];
                          return ListTile(
                            title: Text(name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(vicinity),
                                Text('Rating: $rating ★'),
                              ],
                            ),
                            trailing: TextButton(
                              child: const Text('Directions'),
                              onPressed: () {
                                _openDirections(lat, lng, name);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: 14,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) =>
                      _mapController.complete(controller),
                ),
    );
  }

  Future<void> _openDirections(
      double lat, double lng, String name) async {
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }
}
