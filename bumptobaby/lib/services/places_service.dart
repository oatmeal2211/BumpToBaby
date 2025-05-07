import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlacesService {
  final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!; // 🔑 Put your API key here

    Future<List<dynamic>> findNearbyClinics(Position position, {double radius = 3000}) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&radius=$radius'
      '&type=doctor'
      '&keyword=maternity OR prenatal OR pregnancy OR gynecology OR women health clinic'
      '&key=$apiKey',
    );

    try {
    print('Requesting URL: $url');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);

      // Check if API returned an error
      if (jsonResponse['status'] != 'OK') {
        final errorMessage = jsonResponse['error_message'] ?? jsonResponse['status'];
        throw Exception('Places API error: $errorMessage');
      }

      print('API call successful: found ${jsonResponse['results'].length} results');
      return jsonResponse['results'];
    } else {
      throw Exception('Failed to fetch clinics. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in findNearbyClinics(): $e');
    throw Exception('Error fetching nearby clinics: $e');
  }
  }

  Future<Map<String, dynamic>> getClinicDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=name,formatted_address,formatted_phone_number,opening_hours,website,geometry'
      '&key=$apiKey',
    );

    try {
      print('Requesting Details URL: $url');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] != 'OK') {
          final errorMessage = jsonResponse['error_message'] ?? jsonResponse['status'];
          throw Exception('Places Details API error: $errorMessage');
        }
        print('Details API call successful.');
        return jsonResponse['result'];
      } else {
        throw Exception('Failed to fetch clinic details. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getClinicDetails(): $e');
      throw Exception('Error fetching clinic details: $e');
    }
  }
}