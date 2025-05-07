import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final location = details['geometry']?['location'];
    final lat = location != null ? location['lat'] : null;
    final lng = location != null ? location['lng'] : null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text(address),
              onTap: lat != null && lng != null
                  ? () => _launchUrl(context, 'https://www.google.com/maps/search/?api=1&query=$lat,$lng')
                  : null,
            ),
            if (phone != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(phone),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone number copied to clipboard')),
                    );
                  },
                ),
                onTap: () => _launchUrl(context, 'tel:$phone'),
              ),
            if (website != null)
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Website'),
                subtitle: Text(website),
                onTap: () {
                  final trimmedWebsite = website.trim();
                  final fixedUrl = trimmedWebsite.toLowerCase().startsWith('http') 
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
                    const Text('Opening Hours:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...openingHours.map((line) => Text(line)).toList(),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (lat != null && lng != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl(context, 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
                    icon: const Icon(Icons.directions),
                    label: const Text('Google Maps'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl(context, 'https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
                    icon: const Icon(Icons.directions_car),
                    label: const Text('Waze'),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: phone != null && phone.isNotEmpty
                    ? () async {
                        final sanitizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
                        final telUrl = 'tel:$sanitizedPhone';
                        _launchUrl(context, telUrl);
                    }
                    : null,
                icon: const Icon(Icons.local_phone),
                label: const Text('Book Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
