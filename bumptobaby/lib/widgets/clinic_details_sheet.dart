import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ClinicDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> details;

  const ClinicDetailsSheet({Key? key, required this.details}) : super(key: key);

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
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
                  ? () => _launchUrl('https://www.google.com/maps/search/?api=1&query=$lat,$lng')
                  : null,
            ),
            if (phone != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(phone),
                onTap: () => _launchUrl('tel:$phone'),
              ),
            if (website != null)
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Website'),
                subtitle: Text(website),
                onTap: () => _launchUrl(website),
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
                    onPressed: () => _launchUrl('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
                    icon: const Icon(Icons.directions),
                    label: const Text('Google Maps'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
                    icon: const Icon(Icons.directions_car),
                    label: const Text('Waze'),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: phone != null ? () => _launchUrl('tel:$phone') : null,
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
