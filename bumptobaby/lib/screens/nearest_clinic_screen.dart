import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../widgets/clinic_details_sheet.dart';
import 'booking_screen.dart';

class NearestClinicMapScreen extends StatefulWidget {
  const NearestClinicMapScreen({Key? key}) : super(key: key);

  @override
  State<NearestClinicMapScreen> createState() => _NearestClinicMapScreenState();
}

class _NearestClinicMapScreenState extends State<NearestClinicMapScreen> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  LatLng? _currentLocation;
  String status = 'Loading map...';
  List<dynamic> clinics = [];
  List<dynamic> filteredClinics = [];
  double _selectedRadius = 3000;
  final List<double> _radiusOptions = [1000, 2000, 3000, 5000, 10000];

  bool showListView = false;
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  
  // Filter options
  bool _showHospitals = true;
  bool _showClinics = true;
  bool _showPharmacies = false;
  bool _showOpenOnly = false;
  
  // Animation controllers
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;
  bool _isFilterExpanded = false;

  // Map style
  final MapType _currentMapType = MapType.normal;
  bool _mapLoaded = false;

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
    _loadMapAndClinics();
  }
  
  @override
  void dispose() {
    _filterAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFilterPanel() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
      if (_isFilterExpanded) {
        _filterAnimationController.forward();
      } else {
        _filterAnimationController.reverse();
      }
    });
  }

  Future<void> _loadMapAndClinics() async {
    try {
      setState(() {
        status = 'Loading map...';
        _mapLoaded = false;
      });
      
      final locationService = LocationService();
      final placesService = PlacesService();

      Position position = await locationService.getCurrentLocation();
      LatLng userLatLng = LatLng(position.latitude, position.longitude);

      // Fetch clinics and hospitals
      final loadedClinics = await placesService.findCombinedClinics(
        position,
        radius: _selectedRadius,
      );
      
      // Always fetch pharmacies but only display if filter is enabled
      List<dynamic> pharmacies = await placesService.findPharmacies(
        position,
        radius: _selectedRadius,
      );
      
      // Add category to pharmacies for easier filtering
      for (var pharmacy in pharmacies) {
        pharmacy['category'] = 'pharmacy';
      }
      
      // Combine all results
      final allPlaces = [...loadedClinics, ...pharmacies];
      
      Set<Marker> markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: userLatLng,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      };

      for (var place in allPlaces) {
        final lat = place['geometry']['location']['lat'];
        final lng = place['geometry']['location']['lng'];
        final placeId = place['place_id'];
        final name = place['name'];
        final types = List<String>.from(place['types'] ?? []);
        final rating = place['rating']?.toString() ?? 'N/A';
        final category = place['category'] ?? '';

        // Determine marker color based on place type
        BitmapDescriptor markerIcon;
        
        // Prioritize maternity clinics and hospitals
        if (name.toLowerCase().contains('maternity') || 
            name.toLowerCase().contains('prenatal') || 
            name.toLowerCase().contains('gynecology') ||
            name.toLowerCase().contains('obstetrician') ||
            category == 'maternity') {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
        } else if (types.contains('hospital')) {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        } else if (types.contains('doctor') || category == 'vaccination') {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        } else if (types.contains('pharmacy') || category == 'pharmacy') {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        } else {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
        }

        final marker = Marker(
          markerId: MarkerId(placeId),
          position: LatLng(lat, lng),
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: name,
            snippet: 'Rating: $rating ★',
            onTap: () async {
              try {
                final details = await placesService.getPlaceDetails(placeId);
                if (!mounted) return;
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: ClinicDetailsSheet(details: details),
                  ),
                );
              } catch (e) {
                debugPrint('Error loading details: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to load place details.')),
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
        clinics = allPlaces;
        _applyFilters();
        status = clinics.isEmpty ? 'No places found nearby.' : 'Places loaded!';
        _mapLoaded = true;
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
  
  void _applyFilters() {
    setState(() {
      filteredClinics = clinics.where((place) {
        // Apply search filter
        final name = place['name'].toString().toLowerCase();
        final matchesSearch = searchQuery.isEmpty || name.contains(searchQuery.toLowerCase());
        
        // Apply type filters
        final types = List<String>.from(place['types'] ?? []);
        final category = place['category'] ?? '';
        
        bool matchesType = false;
        
        // Check for maternity clinics and hospitals first (highest priority)
        if (_showHospitals) {
          if (types.contains('hospital') || 
              name.toLowerCase().contains('maternity') || 
              name.toLowerCase().contains('prenatal') ||
              name.toLowerCase().contains('gynecology') ||
              name.toLowerCase().contains('obstetrician') ||
              category == 'maternity') {
            matchesType = true;
          }
        }
        
        // Check for regular clinics and vaccination centers
        if (_showClinics) {
          if (types.contains('doctor') || category == 'vaccination') {
            matchesType = true;
          }
        }
        
        // Check for pharmacies
        if (_showPharmacies) {
          if (types.contains('pharmacy') || category == 'pharmacy') {
            matchesType = true;
          }
        }
        
        // If no filters are selected, show everything
        if (!_showHospitals && !_showClinics && !_showPharmacies) {
          matchesType = true;
        }
        
        // Apply open/closed filter
        bool matchesOpenStatus = true;
        if (_showOpenOnly) {
          final openingHoursInfo = place['opening_hours'];
          final isOpenNow = openingHoursInfo?['open_now'] ?? false;
          matchesOpenStatus = isOpenNow;
        }
        
        return matchesSearch && matchesType && matchesOpenStatus;
      }).toList();
      
      // Update markers based on filtered clinics
      _updateMarkers();
    });
  }
  
  void _updateMarkers() {
    if (_currentLocation == null) return;
    
    // Keep the user marker
    Set<Marker> updatedMarkers = {
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: 'You are here'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };
    
    // Add markers for filtered places
    for (var place in filteredClinics) {
      final lat = place['geometry']['location']['lat'];
      final lng = place['geometry']['location']['lng'];
      final placeId = place['place_id'];
      final name = place['name'];
      final types = List<String>.from(place['types'] ?? []);
      final rating = place['rating']?.toString() ?? 'N/A';
      final category = place['category'] ?? '';
      final openingHoursInfo = place['opening_hours'];
      final isOpenNow = openingHoursInfo?['open_now'] ?? false;
      
      // Determine marker color based on place type
      BitmapDescriptor markerIcon;
      
      if (name.toLowerCase().contains('maternity') || 
          name.toLowerCase().contains('prenatal') || 
          name.toLowerCase().contains('gynecology') ||
          name.toLowerCase().contains('obstetrician') ||
          category == 'maternity') {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
      } else if (types.contains('hospital')) {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      } else if (types.contains('doctor') || category == 'vaccination') {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      } else if (types.contains('pharmacy') || category == 'pharmacy') {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      }
      
      final marker = Marker(
        markerId: MarkerId(placeId),
        position: LatLng(lat, lng),
        icon: markerIcon,
        infoWindow: InfoWindow(
          title: name,
          snippet: 'Rating: $rating ★',
          onTap: () async {
            try {
              final placesService = PlacesService();
              final details = await placesService.getPlaceDetails(placeId);
              if (!mounted) return;
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: ClinicDetailsSheet(details: details),
                ),
              );
            } catch (e) {
              debugPrint('Error loading details: $e');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to load place details.')),
              );
            }
          },
        ),
      );
      
      updatedMarkers.add(marker);
    }
    
    _markers = updatedMarkers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final accentColor = theme.colorScheme.secondary;
    
    return Scaffold(
      body: Stack(
        children: [
          // Map or List View
          _currentLocation == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(status, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              : showListView
                  ? _buildListView(primaryColor)
                  : _buildMap(),
                  
          // Top Bar with Search and Filters
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Container(
                            height: 48,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search places...',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      searchQuery = '';
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(_isFilterExpanded ? Icons.close : Icons.filter_list),
                          onPressed: _toggleFilterPanel,
                        ),
                        IconButton(
                          icon: Icon(showListView ? Icons.map : Icons.list),
                          onPressed: () {
                            setState(() {
                              showListView = !showListView;
                            });
                          },
                        ),
                      ],
                    ),
                    SizeTransition(
                      sizeFactor: _filterAnimation,
                      child: Column(
                        children: [
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Filter by Type',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildFilterChip(
                                      label: 'Maternity & Hospitals',
                                      selected: _showHospitals,
                                      onSelected: (selected) {
                                        setState(() {
                                          _showHospitals = selected;
                                          _applyFilters();
                                        });
                                      },
                                      color: Colors.pink[300]!,
                                    ),
                                    _buildFilterChip(
                                      label: 'Clinics',
                                      selected: _showClinics,
                                      onSelected: (selected) {
                                        setState(() {
                                          _showClinics = selected;
                                          _applyFilters();
                                        });
                                      },
                                      color: Colors.blue[300]!,
                                    ),
                                    _buildFilterChip(
                                      label: 'Pharmacies',
                                      selected: _showPharmacies,
                                      onSelected: (selected) {
                                        setState(() {
                                          _showPharmacies = selected;
                                          _applyFilters();
                                        });
                                      },
                                      color: Colors.green[300]!,
                                    ),
                                    _buildFilterChip(
                                      label: 'Open Now',
                                      selected: _showOpenOnly,
                                      onSelected: (selected) {
                                        setState(() {
                                          _showOpenOnly = selected;
                                          _applyFilters();
                                        });
                                      },
                                      color: Colors.amber[300]!,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Distance',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 40,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _radiusOptions.length,
                                    itemBuilder: (context, index) {
                                      final radius = _radiusOptions[index];
                                      final isSelected = _selectedRadius == radius;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          label: Text('${(radius / 1000).toStringAsFixed(1)} km'),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedRadius = radius;
                                                status = 'Reloading places...';
                                              });
                                              _loadMapAndClinics();
                                            }
                                          },
                                          backgroundColor: Colors.grey[200],
                                          selectedColor: accentColor,
                                          labelStyle: TextStyle(
                                            color: isSelected ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom info panel
          if (_mapLoaded && !showListView)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildLegendItem(Colors.pink, 'Maternity'),
                            const SizedBox(width: 16),
                            _buildLegendItem(Colors.red, 'Hospitals'),
                            const SizedBox(width: 16),
                            _buildLegendItem(Colors.blue, 'Clinics'),
                            const SizedBox(width: 16),
                            _buildLegendItem(Colors.green, 'Pharmacies'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Found ${filteredClinics.length} places within ${(_selectedRadius / 1000).toStringAsFixed(1)} km',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.local_hospital),
                        label: const Text('Book Medical Services'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          _showBookingOptions(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
    required Color color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (selected) {
        onSelected(selected);
        // Ensure markers update immediately
        setState(() {
          _updateMarkers();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: color.withOpacity(0.8),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? color : Colors.grey.shade300,
          width: selected ? 1.5 : 1,
        ),
      ),
      elevation: selected ? 2 : 0,
      pressElevation: 4,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
  
  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentLocation!,
        zoom: 14,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      mapType: _currentMapType,
      onMapCreated: (controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
    );
  }
  
  Widget _buildListView(Color primaryColor) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 80,
        bottom: 0,
      ),
      child: filteredClinics.isEmpty
          ? const Center(child: Text('No places found matching your criteria.'))
          : ListView.builder(
              itemCount: filteredClinics.length,
              itemBuilder: (context, index) {
                final place = filteredClinics[index];
                final name = place['name'];
                final vicinity = place['vicinity'] ?? '';
                final rating = place['rating']?.toString() ?? 'N/A';
                final lat = place['geometry']['location']['lat'];
                final lng = place['geometry']['location']['lng'];
                final types = List<String>.from(place['types'] ?? []);
                final category = place['category'] ?? '';
                final openingHoursInfo = place['opening_hours'];
                final isOpenNow = openingHoursInfo?['open_now'] ?? false;
                
                // Determine place type
                IconData placeIcon;
                Color iconColor;
                
                if (name.toLowerCase().contains('maternity') || 
                    name.toLowerCase().contains('prenatal') || 
                    name.toLowerCase().contains('gynecology') ||
                    name.toLowerCase().contains('obstetrician') ||
                    category == 'maternity') {
                  placeIcon = Icons.pregnant_woman;
                  iconColor = Colors.pink;
                } else if (types.contains('hospital')) {
                  placeIcon = Icons.local_hospital;
                  iconColor = Colors.red;
                } else if (types.contains('doctor') || category == 'vaccination') {
                  placeIcon = Icons.medical_services;
                  iconColor = Colors.blue;
                } else if (types.contains('pharmacy') || category == 'pharmacy') {
                  placeIcon = Icons.local_pharmacy;
                  iconColor = Colors.green;
                } else {
                  placeIcon = Icons.location_on;
                  iconColor = Colors.amber;
                }
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: iconColor.withOpacity(0.2),
                        child: Icon(placeIcon, color: iconColor),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOpenNow ? Colors.green[50] : Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isOpenNow ? Colors.green[300]! : Colors.red[300]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isOpenNow ? 'Open' : 'Closed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isOpenNow ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            vicinity,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$rating',
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 2,
                        ),
                        child: const Text('Details'),
                        onPressed: () async {
                          try {
                            final placesService = PlacesService();
                            final details = await placesService.getPlaceDetails(place['place_id']);
                            if (!mounted) return;
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => Container(
                                height: MediaQuery.of(context).size.height * 0.7,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                child: ClinicDetailsSheet(details: details),
                              ),
                            );
                          } catch (e) {
                            debugPrint('Error loading details: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to load place details.')),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showBookingOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Book Medical Services',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select a service to find nearby places',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                _buildServiceCard(
                  context,
                  title: 'Book Maternity Checkup',
                  description: 'Schedule prenatal appointments for your pregnancy',
                  icon: Icons.pregnant_woman,
                  color: Colors.pink,
                  onTap: () => _navigateToBookingScreen(context, 'Maternity Clinic'),
                ),
                const SizedBox(height: 16),
                _buildServiceCard(
                  context,
                  title: 'Emergency Labor Information',
                  description: 'Find hospitals with labor & delivery services',
                  icon: Icons.emergency,
                  color: Colors.red,
                  onTap: () => _navigateToBookingScreen(context, 'Hospital', service: 'Emergency'),
                ),
                const SizedBox(height: 16),
                _buildServiceCard(
                  context,
                  title: 'Book Vaccination',
                  description: 'Schedule vaccination appointments for you or your baby',
                  icon: Icons.vaccines,
                  color: Colors.purple,
                  onTap: () => _navigateToBookingScreen(context, 'Vaccination Center'),
                ),
                const SizedBox(height: 16),
                _buildServiceCard(
                  context,
                  title: 'Book Body Checkup',
                  description: 'Schedule a comprehensive health examination',
                  icon: Icons.health_and_safety,
                  color: Colors.blue,
                  onTap: () => _navigateToBookingScreen(context, 'Hospital', service: 'Body Checkup'),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.location_on),
                    label: const Text('Find Places on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _navigateToBookingScreen(BuildContext context, String placeType, {String? service}) {
    // Find a suitable place based on type
    final places = filteredClinics.where((place) {
      final types = List<String>.from(place['types'] ?? []);
      final category = place['category'] ?? '';
      final name = place['name'].toString().toLowerCase();
      
      if (placeType == 'Maternity Clinic') {
        return name.toLowerCase().contains('maternity') || 
               name.toLowerCase().contains('prenatal') || 
               name.toLowerCase().contains('gynecology') ||
               name.toLowerCase().contains('obstetrician') ||
               category == 'maternity';
      } else if (placeType == 'Hospital') {
        return types.contains('hospital');
      } else if (placeType == 'Vaccination Center') {
        return name.contains('vaccination') || 
               name.contains('immunization') || 
               category == 'vaccination';
      } else if (placeType == 'Pharmacy') {
        return types.contains('pharmacy') || category == 'pharmacy';
      } else {
        return true; // Default to any place
      }
    }).toList();
    
    if (places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No suitable places found for this service.')),
      );
      Navigator.pop(context);
      return;
    }
    
    // Use the first suitable place
    final selectedPlace = places.first;
    
    Navigator.pop(context); // Close the bottom sheet
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          placeId: selectedPlace['place_id'],
          placeName: selectedPlace['name'],
          placeType: placeType,
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required Function() onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(double lat, double lng, String name) async {
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.circle, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
