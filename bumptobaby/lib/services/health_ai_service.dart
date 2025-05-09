import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bumptobaby/models/health_survey.dart';
import 'package:bumptobaby/models/health_schedule.dart';

class HealthAIService {
  final String? _apiKey;

  HealthAIService() : _apiKey = dotenv.env['GEMINI_API_KEY'];

  Future<HealthSchedule> generateHealthSchedule(HealthSurvey survey, String userId) async {
    if (_apiKey == null) {
      throw Exception("API Key not found. Make sure your .env file is set up correctly.");
    }

    // Prepare the prompt for the AI
    final String prompt = _buildPrompt(survey);

    try {
      final response = await _callGeminiApi(prompt);
      return _parseAIResponse(response, userId);
    } catch (e) {
      if (kDebugMode) {
        print("Error generating health schedule: $e");
      }
      throw Exception("Failed to generate health schedule: $e");
    }
  }

  String _buildPrompt(HealthSurvey survey) {
    String prompt = """
You are a healthcare assistant specializing in pregnancy and infant care. 
Generate a comprehensive health schedule based on the following information:

User Status: ${survey.isPregnant ? 'Pregnant' : 'New Parent'}
""";

    if (survey.isPregnant && survey.dueDate != null) {
      prompt += "Due Date: ${survey.dueDate!.toIso8601String()}\n";
    }

    if (!survey.isPregnant && survey.babyBirthDate != null) {
      prompt += "Baby's Birth Date: ${survey.babyBirthDate!.toIso8601String()}\n";
      if (survey.babyGender != null) prompt += "Baby's Gender: ${survey.babyGender}\n";
      if (survey.babyWeight != null) prompt += "Baby's Weight: ${survey.babyWeight} kg\n";
      if (survey.babyHeight != null) prompt += "Baby's Height: ${survey.babyHeight} cm\n";
    }

    if (survey.healthConditions != null && survey.healthConditions!.isNotEmpty) {
      prompt += "Health Conditions: ${survey.healthConditions!.join(', ')}\n";
    }

    if (survey.allergies != null && survey.allergies!.isNotEmpty) {
      prompt += "Allergies: ${survey.allergies!.join(', ')}\n";
    }

    if (survey.medications != null && survey.medications!.isNotEmpty) {
      prompt += "Medications: ${survey.medications!.join(', ')}\n";
    }

    prompt += """
Please generate a detailed health schedule including:
1. Check-up appointments (with dates, purpose, and importance)
2. Vaccine schedule (with dates, vaccine names, and purpose)
3. Developmental milestones to watch for
4. Recommended supplements and their benefits

Format your response as a structured JSON object with the following format:
{
  "items": [
    {
      "title": "First Trimester Check-up",
      "description": "Regular check-up to monitor pregnancy progress",
      "scheduledDate": "2023-06-15",
      "category": "checkup"
    },
    {
      "title": "Vitamin D Supplement",
      "description": "Take 10mcg daily for bone development",
      "scheduledDate": "2023-06-01",
      "category": "supplement"
    }
  ]
}

Ensure all dates are in ISO format (YYYY-MM-DD) and categories are one of: 'checkup', 'vaccine', 'milestone', or 'supplement'.
""";

    return prompt;
  }

  Future<String> _callGeminiApi(String prompt) async {
    if (_apiKey == null) {
      return "Error: API Key is not configured.";
    }

    const model = "gemini-1.5-flash-latest"; // Or your preferred model
    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey");

    final headers = {
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.2,
        "maxOutputTokens": 2000,
      }
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['candidates'] != null &&
            responseBody['candidates'][0]['content'] != null &&
            responseBody['candidates'][0]['content']['parts'] != null &&
            responseBody['candidates'][0]['content']['parts'][0]['text'] != null) {
          return responseBody['candidates'][0]['content']['parts'][0]['text']
              .trim();
        } else {
          if (kDebugMode) print("Error parsing Gemini response: ${response.body}");
          throw Exception("Could not parse response from API. Details: ${responseBody['error']?['message'] ?? 'Unknown structure'}");
        }
      } else {
        if (kDebugMode) print("Gemini API Error ${response.statusCode}: ${response.body}");
        throw Exception("API request failed with status ${response.statusCode}. Details: ${response.body}");
      }
    } catch (e) {
      if (kDebugMode) print("Error calling Gemini API: $e");
      throw Exception("Failed to connect to API. $e");
    }
  }

  HealthSchedule _parseAIResponse(String aiResponse, String userId) {
    try {
      // Extract JSON from the AI response
      final RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
      final match = jsonRegex.firstMatch(aiResponse);
      
      if (match == null) {
        throw Exception("Could not extract JSON from AI response");
      }
      
      final String jsonStr = match.group(0)!;
      final Map<String, dynamic> jsonData = json.decode(jsonStr);
      
      if (!jsonData.containsKey('items') || !(jsonData['items'] is List)) {
        throw Exception("Invalid JSON format: missing or invalid 'items' field");
      }
      
      final List<dynamic> items = jsonData['items'];
      final List<HealthScheduleItem> scheduleItems = [];
      
      for (var item in items) {
        try {
          scheduleItems.add(HealthScheduleItem(
            title: item['title'],
            description: item['description'],
            scheduledDate: DateTime.parse(item['scheduledDate']),
            category: item['category'],
          ));
        } catch (e) {
          if (kDebugMode) {
            print("Error parsing item: $e");
            print("Item data: $item");
          }
          // Skip invalid items
        }
      }
      
      return HealthSchedule(
        userId: userId,
        items: scheduleItems,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error parsing AI response: $e");
        print("AI response: $aiResponse");
      }
      throw Exception("Failed to parse AI response: $e");
    }
  }
} 