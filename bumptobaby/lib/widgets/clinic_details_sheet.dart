import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/booking_screen.dart';
// Uncomment if you want to use sharing later
// import 'package:share_plus/share_plus.dart';

class ClinicDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> details;

  const ClinicDetailsSheet({Key? key, required this.details}) : super(key: key);

  void _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
  
  void _navigateToBooking(BuildContext context, String serviceType) {
    final placeId = details['place_id'] ?? '';
    final name = details['name'] ?? 'Unknown Place';
    final types = List<String>.from(details['types'] ?? []);
    final category = details['category'] ?? '';
    final website = details['website'];
    final phone = details['formatted_phone_number'];
    
    // If the place has a website, open it
    if (website != null && website.isNotEmpty) {
      _launchUrl(context, website);
      return;
    }
    
    // If no website but has phone, open phone dialer
    if (phone != null && phone.isNotEmpty) {
      final sanitizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      _launchUrl(context, 'tel:$sanitizedPhone');
      return;
    }
    
    // If no website or phone, proceed with booking screen
    
    // Determine place type
    String placeType;
    if (category == 'pharmacy' || types.contains('pharmacy')) {
      placeType = 'Pharmacy';
    } else if (category == 'maternity' || name.toLowerCase().contains('maternity') || 
              name.toLowerCase().contains('prenatal')) {
      placeType = 'Maternity Clinic';
    } else if (category == 'vaccination') {
      placeType = 'Vaccination Center';
    } else {
      placeType = 'Hospital';
    }
    
    // Close the bottom sheet
    Navigator.pop(context);
    
    // Navigate to booking screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          placeId: placeId,
          placeName: name,
          placeType: placeType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = details['name'] ?? 'No name';
    final address = details['formatted_address'] ?? 'No address';
    final phone = details['formatted_phone_number'];
    final website = details['website'];
    final openingHours = details['opening_hours']?['weekday_text'] ?? [];
    final openingHoursInfo = details['opening_hours'];
    final isOpenNow = openingHoursInfo?['open_now'] ?? false;
    final rating = details['rating']?.toString() ?? 'N/A';
    final types = List<String>.from(details['types'] ?? []);
    final category = details['category'] ?? 'Clinic';
    final location = details['geometry']?['location'];
    final lat = location != null ? location['lat'] : null;
    final lng = location != null ? location['lng'] : null;
    
    // Define colors for the baby pregnancy app theme
    const babyPink = Color(0xFFFFC0CB);
    const babyBlue = Color(0xFFADD8E6);
    const softPurple = Color(0xFFD8BFD8);
    const softGreen = Color(0xFFAFE1AF);
    const softYellow = Color(0xFFFFFACD);
    
    // Determine place type and color
    Color primaryColor;
    IconData placeIcon;
    String placeType;
    
    if (category == 'pharmacy' || types.contains('pharmacy')) {
      primaryColor = softGreen;
      placeIcon = Icons.local_pharmacy;
      placeType = 'Pharmacy';
    } else if (category == 'maternity' || name.toLowerCase().contains('maternity') || 
              name.toLowerCase().contains('prenatal')) {
      primaryColor = babyPink;
      placeIcon = Icons.pregnant_woman;
      placeType = 'Maternity Clinic';
    } else if (category == 'vaccination') {
      primaryColor = softPurple;
      placeIcon = Icons.vaccines;
      placeType = 'Vaccination Center';
    } else {
      primaryColor = babyBlue;
      placeIcon = Icons.local_hospital;
      placeType = 'Hospital';
    }

    final openColor = isOpenNow ? Colors.green[700]! : Colors.red[700]!;
    final openText = isOpenNow ? 'Open Now' : 'Currently Closed';
    final openIcon = isOpenNow ? Icons.check_circle : Icons.access_time;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with place name and type
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 24,
                    child: Icon(placeIcon, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          placeType,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Rating and open status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$rating',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(openIcon, color: openColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          openText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: openColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Address section
                _buildInfoSection(
                  title: 'Address',
                  content: address,
                  icon: Icons.location_on,
                  color: primaryColor,
                  onTap: lat != null && lng != null
                      ? () => _launchUrl(context, 'https://www.google.com/maps/search/?api=1&query=$lat,$lng')
                      : null,
                ),
                
                // Phone section
                if (phone != null)
                  _buildInfoSection(
                    title: 'Phone',
                    content: phone,
                    icon: Icons.phone,
                    color: primaryColor,
                    onTap: () {
                      final sanitizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
                      _launchUrl(context, 'tel:$sanitizedPhone');
                    },
                    trailing: IconButton(
                      icon: Icon(Icons.copy, color: primaryColor),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone number copied to clipboard')),
                        );
                      },
                    ),
                  ),
                
                // Website section
                if (website != null)
                  _buildInfoSection(
                    title: 'Website',
                    content: website,
                    icon: Icons.language,
                    color: primaryColor,
                    onTap: () {
                      final trimmedWebsite = website.trim();
                      final fixedUrl = trimmedWebsite.startsWith(RegExp(r'https?://'))
                          ? trimmedWebsite
                          : 'https://$trimmedWebsite';
                      _launchUrl(context, fixedUrl);
                    },
                  ),
                
                // Opening hours section
                if (openingHours.isNotEmpty)
                  _buildExpandableSection(
                    title: 'Opening Hours',
                    icon: Icons.access_time,
                    color: primaryColor,
                    children: openingHours
                        .map<Widget>((line) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                
                const SizedBox(height: 24),
                
                // Action buttons
                if (lat != null && lng != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Directions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context: context,
                              label: 'Google Maps',
                              icon: Icons.directions,
                              color: babyBlue,
                              onTap: () => _launchUrl(context, 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              context: context,
                              label: 'Waze',
                              icon: Icons.directions_car,
                              color: babyPink,
                              onTap: () => _launchUrl(context, 'https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                
                const SizedBox(height: 24),
                
                // Services section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (category == 'maternity' || name.toLowerCase().contains('maternity') || 
                        name.toLowerCase().contains('prenatal') || types.contains('hospital'))
                      _buildServiceButton(
                        context: context,
                        label: 'Book Maternity Checkup',
                        icon: Icons.pregnant_woman,
                        color: babyPink,
                        onTap: () => _navigateToBooking(context, 'Maternity Checkup'),
                      ),
                    if (category == 'maternity' || name.toLowerCase().contains('maternity') || 
                        name.toLowerCase().contains('prenatal') || types.contains('hospital'))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildServiceButton(
                          context: context,
                          label: 'Emergency Labor Information',
                          icon: Icons.emergency,
                          color: Colors.red[400]!,
                          onTap: () => _navigateToBooking(context, 'Emergency'),
                        ),
                      ),
                    if (!types.contains('pharmacy') && !category.contains('pharmacy'))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildServiceButton(
                          context: context,
                          label: 'Book Vaccination',
                          icon: Icons.vaccines,
                          color: softPurple,
                          onTap: () => _navigateToBooking(context, 'Vaccination'),
                        ),
                      ),
                    if (types.contains('hospital') || category == 'hospital')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildServiceButton(
                          context: context,
                          label: 'Book Body Checkup',
                          icon: Icons.health_and_safety,
                          color: babyBlue,
                          onTap: () => _navigateToBooking(context, 'Body Checkup'),
                        ),
                      ),
                    if (types.contains('pharmacy') || category == 'pharmacy')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildServiceButton(
                          context: context,
                          label: 'Order Medication',
                          icon: Icons.local_pharmacy,
                          color: softGreen,
                          onTap: () => _navigateToBooking(context, 'Medication Order'),
                        ),
                      ),
                    if (types.contains('pharmacy') || category == 'pharmacy')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildServiceButton(
                          context: context,
                          label: 'Available Milk Formula',
                          icon: Icons.baby_changing_station,
                          color: Colors.blue,
                          onTap: () => _navigateToBooking(context, 'Available Milk Formula'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoSection({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: 15,
                        color: onTap != null ? Colors.black87 : Colors.black87,
                        fontWeight: FontWeight.w500,
                        decoration: null,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                  if (onTap != null) 
                    Icon(Icons.open_in_new, size: 16, color: color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  Widget _buildServiceButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.9),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
