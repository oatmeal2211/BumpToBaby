import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlacesService {
  final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;

  Future<List<dynamic>> findCombinedClinics(Position position, {double radius = 3000}) async {
    final maternityUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&radius=$radius'
      '&type=hospital'
      '&keyword=maternity OR prenatal OR pregnancy OR gynecology OR women health clinic'
      '&key=$apiKey',
    );

    final vaccinationUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&radius=$radius'
      '&type=hospital'
      '&keyword=vaccination OR immunization'
      '&key=$apiKey',
    );

    final maternityDoctorUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&radius=$radius'
      '&type=doctor'
      '&keyword=maternity OR prenatal OR pregnancy OR gynecology OR women health clinic'
      '&key=$apiKey',
    );

    final vaccinationDoctorUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&radius=$radius'
      '&type=doctor'
      '&keyword=vaccination OR immunization'
      '&key=$apiKey',
    );

    try {
      final maternityHospitalResults = await _fetchAllPages(maternityUrl, category: 'maternity');
      final maternityDoctorResults = await _fetchAllPages(maternityDoctorUrl, category: 'maternity');
      final vaccinationHospitalResults = await _fetchAllPages(vaccinationUrl, category: 'vaccination');
      final vaccinationDoctorResults = await _fetchAllPages(vaccinationDoctorUrl, category: 'vaccination');


      // Combine and deduplicate by place_id
      final Map<String, dynamic> combinedMap = {};
      for (var item in maternityHospitalResults) {
        combinedMap[item['place_id']] = item;
      }
      for (var item in maternityDoctorResults) {
        combinedMap[item['place_id']] = item;
      }
      for (var item in vaccinationHospitalResults) {
        combinedMap[item['place_id']] = item;
      }
      for (var item in vaccinationDoctorResults) {
        combinedMap[item['place_id']] = item;
      }

      final combinedList = combinedMap.values.toList();
      print('Combined API call successful: ${combinedList.length} unique results');
      return combinedList;

    } catch (e) {
      print('Error in findCombinedClinics(): $e');
      throw Exception('Error fetching combined clinics: $e');
    }
  }
  
  Future<List<dynamic>> findPharmacies(Position position, {double radius = 3000}) async {
    final pharmacyUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&radius=$radius'
      '&type=pharmacy'
      '&key=$apiKey',
    );

    try {
      final pharmacyResults = await _fetchAllPages(pharmacyUrl, category: 'pharmacy');
      print('Pharmacy API call successful: ${pharmacyResults.length} results');
      return pharmacyResults;
    } catch (e) {
      print('Error in findPharmacies(): $e');
      throw Exception('Error fetching pharmacies: $e');
    }
  }

  Future<List<dynamic>> _fetchAllPages(Uri url, {required String category}) async {
    List<dynamic> allResults = [];
    String? nextPageToken;

    do {
      final response = await http.get(url.replace(queryParameters: {
        ...url.queryParameters,
        if (nextPageToken != null) 'pagetoken': nextPageToken,
      }));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch $category clinics. Status code: ${response.statusCode}');
      }

      final jsonData = json.decode(response.body);
      final status = jsonData['status'];
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        final errorMessage = jsonData['error_message'] ?? status;
        throw Exception('$category API error: $errorMessage');
      }

      final results = (jsonData['results'] ?? []) as List<dynamic>;

      // Tag category on each item
      for (var item in results) {
        item['category'] = category;
      }

      allResults.addAll(results);

      nextPageToken = jsonData['next_page_token'];
      if (nextPageToken != null) {
        // Google requires a short delay before using next_page_token
        await Future.delayed(const Duration(seconds: 2));
      }
    } while (nextPageToken != null);

    return allResults;
  }

  // Renamed from getClinicDetails to getPlaceDetails for broader use
  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=name,formatted_address,formatted_phone_number,opening_hours,website,geometry,rating,types,photos'
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
        throw Exception('Failed to fetch place details. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getPlaceDetails(): $e');
      throw Exception('Error fetching place details: $e');
    }
  }
  
  // Keep the old method for backward compatibility
  Future<Map<String, dynamic>> getClinicDetails(String placeId) async {
    return getPlaceDetails(placeId);
  }
}
