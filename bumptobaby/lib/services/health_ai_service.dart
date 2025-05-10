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
    final now = DateTime.now();
    String prompt = """
You are a healthcare assistant specializing in pregnancy and infant care.
Current Date: ${now.toIso8601String()}
User Status: ${survey.isPregnant ? 'Pregnant' : 'New Parent'}
""";

    if (survey.isPregnant && survey.dueDate != null) {
      final pregnancyDuration = survey.dueDate!.difference(now).inDays;
      final pregnancyWeeks = 40 - (pregnancyDuration / 7).floor();
      prompt += "Due Date: ${survey.dueDate!.toIso8601String()}\n";
      prompt += "Current Pregnancy Week: $pregnancyWeeks\n";
      prompt += """
Generate a detailed pregnancy health schedule covering these 4 key sections:

1️⃣ Check-up Schedule:
   - Regular prenatal visits (adjust frequency as due date approaches)
   - Ultrasounds and screenings
   - Blood tests and monitoring
   - Mental health check-ins

2️⃣ Vaccine Schedule:
   - Flu shot (if in season)
   - Tdap vaccine (whooping cough)
   - COVID vaccine or booster (if recommended)
   - Any other pregnancy-specific vaccines

3️⃣ Milestones:
   - Fetal movement tracking/kick counts
   - Trimester transitions
   - Glucose screening
   - Hospital bag preparation
   - Birth plan creation
   - Childbirth classes
   - Nursery setup

4️⃣ Supplements:
   - Prenatal vitamins
   - Folic acid
   - Iron
   - Calcium
   - DHA/Omega-3

Example JSON format:
{
  "items": [
    {
      "title": "32-Week Checkup",
      "description": "Monitor fetal growth, position, and mother's health.",
      "scheduledDate": "2025-06-01",
      "category": "checkup"
    },
    {
      "title": "Daily Prenatal Vitamins",
      "description": "Take one tablet daily with food.",
      "scheduledDate": "2025-05-11",
      "category": "supplement"
    }
  ]
}

IMPORTANT:
- Provide enough checkups to cover until the due date.
- Include important milestones and preparation tasks.
- List only ~5 key supplements with daily instructions.
- Dates must be after ${now.toIso8601String()}.
- Dates must use YYYY-MM-DD format.
- Categories must be: checkup, vaccine, milestone, supplement.
- Output ONLY pure JSON (no ```json or markdown).
""";
    }

    if (!survey.isPregnant && survey.babyBirthDate != null) {
      final babyAge = now.difference(survey.babyBirthDate!).inDays;
      prompt += "Baby's Birth Date: ${survey.babyBirthDate!.toIso8601String()}\n";
      prompt += "Baby's Age in Days: $babyAge\n";
      if (survey.babyGender != null) prompt += "Baby's Gender: ${survey.babyGender}\n";
      if (survey.babyWeight != null) prompt += "Baby's Weight: ${survey.babyWeight} kg\n";
      if (survey.babyHeight != null) prompt += "Baby's Height: ${survey.babyHeight} cm\n";

      prompt += """
Generate a detailed infant health schedule covering these 4 key sections:

1️⃣ Check-up Schedule:
   - Regular pediatric visits
   - Growth assessments
   - Developmental screenings
   - Vision and hearing checks

2️⃣ Vaccine Schedule:
   - Standard newborn/infant immunizations (HepB, DTaP, Hib, PCV, IPV, RV, etc.)
   - Seasonal vaccines (like flu)
   - Follow the standard CDC/WHO immunization schedule

3️⃣ Milestones:
   - Physical milestones (tummy time, rolling over, sitting, crawling, walking)
   - Cognitive milestones (tracking objects, recognizing faces, first words)
   - Feeding milestones (introducing solids, self-feeding)
   - Social milestones (smiling, laughing, playing)

4️⃣ Supplements:
   - Vitamin D drops
   - Iron drops (if needed)
   - Any other supplements based on baby's needs

Use same JSON format as above.
""";
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

    return prompt;
  }

  Future<String> _callGeminiApi(String prompt) async {
    if (_apiKey == null) {
      throw Exception("API Key not found.");
    }

    const model = "gemini-1.5-flash-latest";
    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey");

    final headers = {'Content-Type': 'application/json'};

    final body = jsonEncode({
      "contents": [
        {"parts": [{"text": prompt}]}
      ],
      "generationConfig": {
        "temperature": 0.1,
        "maxOutputTokens": 3000,
        "topP": 0.8,
        "topK": 40
      }
    });

    try {
      if (kDebugMode) print("Calling Gemini API...");

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final text = responseBody['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          return text.trim();
        }
        throw Exception("No valid text in API response.");
      } else {
        throw Exception("API request failed with status ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      if (kDebugMode) print("Error calling Gemini API: $e");
      rethrow;
    }
  }

  HealthSchedule _parseAIResponse(String aiResponse, String userId) {
    try {
      String cleanedResponse = aiResponse
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final jsonData = json.decode(cleanedResponse);

      if (!jsonData.containsKey('items') || jsonData['items'] is! List) {
        throw Exception("Invalid JSON format: missing 'items' array.");
      }

      final items = jsonData['items'] as List;
      final List<HealthScheduleItem> scheduleItems = [];

      for (var item in items) {
        if (item['title'] == null ||
            item['description'] == null ||
            item['scheduledDate'] == null ||
            item['category'] == null) {
          continue;
        }

        final date = DateTime.tryParse(item['scheduledDate'].toString());
        if (date == null) continue;

        scheduleItems.add(HealthScheduleItem(
          title: item['title'].toString(),
          description: item['description'].toString(),
          scheduledDate: date,
          category: item['category'].toString(),
        ));
      }

      if (scheduleItems.isEmpty) {
        throw Exception("No valid schedule items parsed.");
      }

      return HealthSchedule(
        userId: userId,
        items: scheduleItems,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print("Failed to parse AI response: $e");
        print("AI response was: $aiResponse");
      }
      throw Exception("Failed to parse AI response: $e");
    }
  }
}
