import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final category = details['category'] ?? 'Clinic';
    final location = details['geometry']?['location'];
    final lat = location != null ? location['lat'] : null;
    final lng = location != null ? location['lng'] : null;

    const lightBlue = Color(0xFFADD8E6);
    const lightPink = Color(0xFFFFC0CB);
    const darkerBlue = Color(0xFF5DADE2);
    const darkerPink = Color(0xFFE57373);

    final openColor = isOpenNow ? Colors.green : Colors.red;
    final openText = isOpenNow ? 'This clinic is open now!' : 'Currently closed';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkerBlue)),
              subtitle: Text(address, style: const TextStyle(fontSize: 16, color: Colors.black87)),
              onTap: lat != null && lng != null
                  ? () => _launchUrl(context, 'https://www.google.com/maps/search/?api=1&query=$lat,$lng')
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text('Rating: $rating ★', style: const TextStyle(fontSize: 16)),
              subtitle: Text('Category: $category', style: const TextStyle(fontSize: 14)),
            ),
            if (phone != null)
              ListTile(
                leading: const Icon(Icons.phone, color: darkerBlue),
                title: Text(phone, style: const TextStyle(fontSize: 16)),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, color: darkerPink),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone number copied to clipboard')),
                    );
                  },
                ),
                onTap: () {
                  final sanitizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
                  _launchUrl(context, 'tel:$sanitizedPhone');
                },
              ),
            if (website != null)
              ListTile(
                leading: const Icon(Icons.language, color: darkerBlue),
                title: const Text('Website', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text(website, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                onTap: () {
                  final trimmedWebsite = website.trim();
                  final fixedUrl = trimmedWebsite.startsWith(RegExp(r'https?://'))
                      ? trimmedWebsite
                      : 'https://$trimmedWebsite';
                  _launchUrl(context, fixedUrl);
                },
              ),
            if (openingHours.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Opening Hours:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkerPink)),
                    ...openingHours.map((line) => Text(line, style: const TextStyle(fontSize: 16, color: Colors.black87))).toList(),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (lat != null && lng != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightBlue,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => _launchUrl(context, 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
                    icon: const Icon(Icons.directions),
                    label: const Text('Google Maps'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightPink,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => _launchUrl(context, 'https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
                    icon: const Icon(Icons.directions_car),
                    label: const Text('Waze'),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Card(
              color: Colors.green[50],
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: openColor),
                        const SizedBox(width: 8),
                        Text(openText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: openColor)),
                      ],
                    ),
                    if (phone != null && phone.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.call, size: 20, color: Colors.indigo),
                        label: const Text('Book Now',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        onPressed: () {
                          final sanitizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
                          _launchUrl(context, 'tel:$sanitizedPhone');
                        },
                      ),
                  ],
                ),
              ),
            ),
            // Optional: Share button
            // Center(
            //   child: ElevatedButton.icon(
            //     onPressed: () {
            //       final shareText = '$name\n$address\n$phone\n$website';
            //       Share.share(shareText);
            //     },
            //     icon: const Icon(Icons.share),
            //     label: const Text('Share'),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
