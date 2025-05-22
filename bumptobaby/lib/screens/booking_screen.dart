import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingScreen extends StatefulWidget {
  final String placeId;
  final String placeName;
  final String placeType;

  const BookingScreen({
    Key? key,
    required this.placeId,
    required this.placeName,
    required this.placeType,
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bookingService = BookingService();
  final _pharmacyService = PharmacyService();
  final _placesService = PlacesService();

  String? _selectedService;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  final TextEditingController _notesController = TextEditingController();
  
  bool _isVaccineBooking = false;
  bool _isMaternityBooking = false;
  bool _isEmergencyInfo = false;
  bool _isBodyCheckup = false;
  bool _isLoadingPlaces = false;
  
  Map<String, dynamic>? _selectedVaccinePackage;
  List<Map<String, dynamic>> _vaccinePackages = [];
  
  // Places data
  List<Map<String, dynamic>> _availablePlaces = [];
  Map<String, dynamic>? _selectedPlace;
  
  // New fields for available medications and milk formula
  List<Map<String, dynamic>> _availableMedications = [];
  List<Map<String, dynamic>> _availableMilkFormula = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Set default service based on place type
    if (widget.placeType == 'Maternity Clinic') {
      _selectedService = 'Maternity Checkup';
      _isMaternityBooking = true;
    } else if (widget.placeType == 'Vaccination Center') {
      _selectedService = 'Vaccination';
      _isVaccineBooking = true;
    } else if (widget.placeType == 'Hospital') {
      _selectedService = 'Body Checkup';
      _isBodyCheckup = true;
    } else if (widget.placeType == 'Pharmacy') {
      _selectedService = 'Medication Order';
    } else {
      _selectedService = 'Consultation';
    }
    
    // Set initial selected place
    _selectedPlace = {
      'place_id': widget.placeId,
      'name': widget.placeName,
      'type': widget.placeType,
    };
    
    // Load nearby places of the same type
    _loadNearbyPlaces();
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _loadNearbyPlaces() async {
    setState(() {
      _isLoadingPlaces = true;
    });
    
    try {
      // Get current location and find nearby places
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      List<dynamic> places = [];
      
      if (widget.placeType == 'Maternity Clinic') {
        // Find maternity clinics and hospitals with maternity services
        places = await _placesService.findCombinedClinics(position);
        places = places.where((place) {
          final name = place['name'].toString().toLowerCase();
          return name.contains('maternity') || 
                 name.contains('prenatal') || 
                 name.contains('gynecology') ||
                 name.contains('obstetrician');
        }).toList();
      } else if (widget.placeType == 'Hospital') {
        // Find hospitals
        places = await _placesService.findCombinedClinics(position);
        places = places.where((place) {
          final types = List<String>.from(place['types'] ?? []);
          return types.contains('hospital');
        }).toList();
      } else if (widget.placeType == 'Vaccination Center') {
        // Find clinics that might offer vaccination
        places = await _placesService.findCombinedClinics(position);
        places = places.where((place) {
          final types = List<String>.from(place['types'] ?? []);
          return types.contains('doctor') || 
                 place['category'] == 'vaccination';
        }).toList();
      } else if (widget.placeType == 'Pharmacy') {
        places = await _placesService.findPharmacies(position);
      }
      
      // Convert to format needed for dropdown
      _availablePlaces = places.map((place) => {
        'place_id': place['place_id'],
        'name': place['name'],
        'type': widget.placeType,
        'vicinity': place['vicinity'] ?? 'No address',
      }).toList();
      
      // Add current place if not in list
      if (!_availablePlaces.any((p) => p['place_id'] == widget.placeId)) {
        _availablePlaces.insert(0, _selectedPlace!);
      }
      
    } catch (e) {
      debugPrint('Error loading nearby places: $e');
    } finally {
      setState(() {
        _isLoadingPlaces = false;
      });
    }
  }
  
  void _loadData() {
    // Load vaccine packages
    _vaccinePackages = _pharmacyService.getVaccinationPackages();
    if (_vaccinePackages.isNotEmpty) {
      _selectedVaccinePackage = _vaccinePackages.first;
    }
    
    // Load available medications
    _availableMedications = _pharmacyService.getAvailableMedications();
    
    // Load available milk formula
    _availableMilkFormula = _pharmacyService.getAvailableMilkFormula();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFC0CB), // baby pink
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFC0CB), // baby pink
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Get selected place info
        final placeId = _selectedPlace?['place_id'] ?? widget.placeId;
        final placeName = _selectedPlace?['name'] ?? widget.placeName;
        
        // Try to get place details to check for website or phone
        try {
          final details = await _placesService.getPlaceDetails(placeId);
          final website = details['website'];
          final phone = details['formatted_phone_number'];
          final location = details['geometry']?['location'];
          final lat = location != null ? location['lat'] : null;
          final lng = location != null ? location['lng'] : null;
          
          // If the place has a website, open it
          if (website != null && website.isNotEmpty) {
            final uri = Uri.parse(website);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              Navigator.of(context).pop(true);
              return;
            }
          }
          
          // If no website but has phone, open phone dialer
          if (phone != null && phone.isNotEmpty) {
            final sanitizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
            final uri = Uri.parse('tel:$sanitizedPhone');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
              Navigator.of(context).pop(true);
              return;
            }
          }
          
          // If no website or phone, but has location, open maps
          if (lat != null && lng != null) {
            final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              Navigator.of(context).pop(true);
              return;
            }
          }
          
          // If all else fails, show a message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No booking options available for this place. Please contact them directly.'),
              backgroundColor: Colors.orange,
            ),
          );
          
        } catch (e) {
          debugPrint('Error getting place details: $e');
          // Show error message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to contact this place. Please try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        
        // Navigate back regardless
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: const Color(0xFFFFC0CB), // baby pink
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Place selection dropdown
                const Text(
                  'Select Place',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPlaceSelection(),
                const SizedBox(height: 24),
                
                // Service selection
                const Text(
                  'Select Service',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildServiceSelection(),
                const SizedBox(height: 24),
                
                // Date and time selection
                if (!_isEmergencyInfo) ...[
                  const Text(
                    'Select Date & Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDateTimeSelection(),
                  const SizedBox(height: 24),
                ],
                
                // Service specific options
                if (_isVaccineBooking)
                  _buildVaccinePackageSelection()
                else if (_isMaternityBooking)
                  _buildMaternityCheckupInfo()
                else if (_isEmergencyInfo)
                  _buildEmergencyInfo()
                else if (_isBodyCheckup)
                  _buildBodyCheckupInfo()
                else if (_selectedService == 'Medication Order')
                  _buildMedicationOrderInfo()
                else if (_selectedService == 'Available Milk Formula')
                  _buildMilkFormulaInfo(),
                
                const SizedBox(height: 24),
                
                // Notes field
                const Text(
                  'Additional Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    hintText: 'Add any special instructions or notes...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                
                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isEmergencyInfo ? () => Navigator.pop(context) : _submitBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEmergencyInfo ? Colors.red : const Color(0xFFADD8E6), // baby blue
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isEmergencyInfo ? 'Close' : 'Confirm Booking',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlaceSelection() {
    if (_isLoadingPlaces) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPlace?['place_id'],
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          hint: const Text('Select a place'),
          items: _availablePlaces.map((place) {
            return DropdownMenuItem<String>(
              value: place['place_id'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    place['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (place['vicinity'] != null)
                    Text(
                      place['vicinity'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? placeId) {
            if (placeId != null) {
              setState(() {
                _selectedPlace = _availablePlaces.firstWhere(
                  (place) => place['place_id'] == placeId,
                );
              });
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildServiceSelection() {
    final List<String> services = [];
    final List<String> unavailableServices = [];
    
    // Add services based on place type
    if (widget.placeType == 'Maternity Clinic') {
      services.add('Maternity Checkup');
      services.add('Ultrasound');
      services.add('Consultation');
    } else if (widget.placeType == 'Vaccination Center') {
      services.add('Vaccination');
      services.add('Consultation');
    } else if (widget.placeType == 'Hospital') {
      services.add('Body Checkup');
      services.add('Maternity Checkup');
      services.add('Emergency Labor Information');
      services.add('Vaccination');
    } else if (widget.placeType == 'Pharmacy') {
      services.add('Medication Order');
      services.add('Available Milk Formula');
    } else {
      services.add('Consultation');
    }
    
    // Determine which services might be unavailable based on place type
    if (widget.placeType != 'Maternity Clinic' && widget.placeType != 'Hospital') {
      unavailableServices.add('Maternity Checkup');
      unavailableServices.add('Ultrasound');
      unavailableServices.add('Emergency Labor Information');
    }
    
    if (widget.placeType != 'Vaccination Center' && widget.placeType != 'Hospital') {
      unavailableServices.add('Vaccination');
    }
    
    if (widget.placeType != 'Hospital') {
      unavailableServices.add('Body Checkup');
    }
    
    if (widget.placeType != 'Pharmacy') {
      unavailableServices.add('Medication Order');
      unavailableServices.add('Available Milk Formula');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...services.map((service) => _buildServiceOption(service, false)).toList(),
        if (unavailableServices.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Unavailable at this location',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ...unavailableServices.map((service) => _buildServiceOption(service, true)).toList(),
        ],
      ],
    );
  }
  
  Widget _buildServiceOption(String service, bool isUnavailable) {
    final isSelected = _selectedService == service && !isUnavailable;
    Color serviceColor;
    IconData serviceIcon;
    
    // Determine service color and icon
    if (service == 'Maternity Checkup' || service == 'Ultrasound') {
      serviceColor = const Color(0xFFFFC0CB); // baby pink
      serviceIcon = Icons.pregnant_woman;
    } else if (service == 'Vaccination') {
      serviceColor = const Color(0xFFD8BFD8); // soft purple
      serviceIcon = Icons.vaccines;
    } else if (service == 'Body Checkup') {
      serviceColor = const Color(0xFFADD8E6); // baby blue
      serviceIcon = Icons.health_and_safety;
    } else if (service == 'Emergency Labor Information') {
      serviceColor = Colors.red;
      serviceIcon = Icons.emergency;
    } else if (service == 'Medication Order') {
      serviceColor = const Color(0xFFAFE1AF); // soft green
      serviceIcon = Icons.local_pharmacy;
    } else if (service == 'Available Milk Formula') {
      serviceColor = Colors.blue;
      serviceIcon = Icons.baby_changing_station;
    } else {
      serviceColor = Colors.blue;
      serviceIcon = Icons.medical_services;
    }
    
    // Apply grey color for unavailable services
    if (isUnavailable) {
      serviceColor = Colors.grey;
    }
    
    return InkWell(
      onTap: isUnavailable 
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$service is not available at this location'),
                  backgroundColor: Colors.grey[700],
                ),
              );
            } 
          : () {
              setState(() {
                _selectedService = service;
                _isVaccineBooking = service == 'Vaccination';
                _isMaternityBooking = service == 'Maternity Checkup' || service == 'Ultrasound';
                _isEmergencyInfo = service == 'Emergency Labor Information';
                _isBodyCheckup = service == 'Body Checkup';
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? serviceColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? serviceColor.withOpacity(0.1) : Colors.white,
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: serviceColor.withOpacity(isSelected ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                serviceIcon,
                color: serviceColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isUnavailable ? Colors.grey : (isSelected ? serviceColor : Colors.black87),
                    ),
                  ),
                  if (isUnavailable)
                    const Text(
                      'Not available at this location',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            if (isUnavailable)
              const Icon(
                Icons.not_interested,
                color: Colors.grey,
                size: 20,
              )
            else if (isSelected)
              Icon(
                Icons.check_circle,
                color: serviceColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateTimeSelection() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => _selectTime(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _selectedTime.format(context),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildVaccinePackageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Vaccine Package',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_vaccinePackages.length, (index) {
          final package = _vaccinePackages[index];
          final isSelected = _selectedVaccinePackage?['id'] == package['id'];
          
          return InkWell(
            onTap: () {
              setState(() {
                _selectedVaccinePackage = package;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFFD8BFD8) : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected ? const Color(0xFFD8BFD8).withOpacity(0.1) : Colors.white,
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: package['id'],
                    groupValue: _selectedVaccinePackage?['id'],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedVaccinePackage = package;
                        });
                      }
                    },
                    activeColor: const Color(0xFFD8BFD8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          package['description'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Age: ${package['ageRange']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '\$${package['price'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFFD8BFD8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildMaternityCheckupInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Maternity Checkup Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFFFC0CB).withOpacity(0.1),
            border: Border.all(color: const Color(0xFFFFC0CB).withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFFFC0CB)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'About Maternity Checkups',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Regular prenatal checkups are important to monitor the health of both mother and baby. Your doctor will check your weight, blood pressure, and the baby\'s heartbeat.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please bring any previous medical records and a list of any medications you are taking.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildBodyCheckupInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Body Checkup Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFADD8E6).withOpacity(0.1),
            border: Border.all(color: const Color(0xFFADD8E6).withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFADD8E6)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'About Body Checkups',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'A comprehensive body checkup includes vital signs, blood tests, urine analysis, and other tests as recommended by your doctor.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please come fasting (no food or drink except water for 8-12 hours before the appointment) for accurate blood test results.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMedicationOrderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Medications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFAFE1AF).withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medical_services, color: Color(0xFFAFE1AF)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Common Medications Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._availableMedications.take(4).map((med) => _buildMedicationItem(med)).toList(),
              const SizedBox(height: 16),
              const Text(
                'Please note: Some medications may require a prescription. Contact the pharmacy directly for specific medication availability.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // Show milk formula options
                  setState(() {
                    _selectedService = 'Available Milk Formula';
                  });
                },
                icon: const Icon(Icons.baby_changing_station),
                label: const Text('See Available Milk Formula'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFAFE1AF),
                  side: const BorderSide(color: Color(0xFFAFE1AF)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMedicationItem(Map<String, dynamic> medication) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFAFE1AF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.medication, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  medication['description'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${medication['price'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    Text(
                      medication['requiresPrescription'] ? 'Requires Prescription' : 'No Prescription Required',
                      style: TextStyle(
                        fontSize: 12,
                        color: medication['requiresPrescription'] ? Colors.red[700] : Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMilkFormulaInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Milk Formula',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.blue.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.baby_changing_station, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Baby Formula Options & Market Prices',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._availableMilkFormula.take(4).map((formula) => _buildFormulaItem(formula)).toList(),
              const SizedBox(height: 16),
              const Text(
                'Prices may vary by location. Contact the pharmacy to confirm availability and current pricing.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // Show medication options
                  setState(() {
                    _selectedService = 'Medication Order';
                  });
                },
                icon: const Icon(Icons.medication),
                label: const Text('See Available Medications'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildFormulaItem(Map<String, dynamic> formula) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.baby_changing_station, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formula['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formula['description'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${formula['price'].toStringAsFixed(2)} (${formula['size']})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.blue,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${formula['rating']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Available at: ${formula['availability']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmergencyInfo() {
    // Check if the place has 24-hour service
    final openingHours = _selectedPlace?['opening_hours'] ?? {};
    final weekdayText = openingHours['weekday_text'] as List<dynamic>? ?? [];
    bool has24HourService = false;
    
    // Check if any of the opening hours mention 24 hours
    if (weekdayText.isNotEmpty) {
      for (var day in weekdayText) {
        if (day.toString().toLowerCase().contains('24 hours') || 
            day.toString().toLowerCase().contains('open 24/7') ||
            day.toString().toLowerCase().contains('24/7')) {
          has24HourService = true;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emergency, color: Colors.red[700], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Emergency Labor Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.red, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'If you are in labor or experiencing an emergency:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              _buildEmergencyItem(
                icon: Icons.call,
                title: 'Call Emergency Services',
                description: 'Dial emergency number (911, 999, or local emergency number)',
                iconColor: Colors.red,
              ),
              const SizedBox(height: 12),
              _buildEmergencyItem(
                icon: Icons.access_time,
                title: 'Time Contractions',
                description: 'Track how far apart and how long contractions last',
                iconColor: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildEmergencyItem(
                icon: Icons.local_hospital,
                title: '${_selectedPlace?['name'] ?? widget.placeName} Labor & Delivery',
                description: has24HourService 
                    ? 'This hospital has 24/7 labor and delivery services'
                    : 'This facility may NOT offer 24/7 labor services',
                iconColor: has24HourService ? Colors.green : Colors.red,
              ),
              if (!has24HourService)
                Container(
                  margin: const EdgeInsets.only(top: 8, left: 36),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Call ahead to confirm emergency services availability. You may need to go to a different hospital during off-hours.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _buildEmergencyItem(
                icon: Icons.checklist,
                title: 'What to Bring',
                description: 'ID, insurance card, hospital bag, birth plan',
                iconColor: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              if (!has24HourService)
                ElevatedButton.icon(
                  onPressed: () {
                    // Find nearby 24/7 hospitals
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Redirecting to find 24/7 emergency facilities'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Find 24/7 Emergency Facilities'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmergencyItem({
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor, width: 1),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
              ),
            ],
          ),
        ),
      ],
    );
  }
} 