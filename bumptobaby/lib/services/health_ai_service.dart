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
      return await _retryWithBackoff(() async {
        final response = await _callGeminiApi(prompt);
        return await _parseAIResponse(response, userId);
      }, maxRetries: 3);
    } catch (e) {
      if (kDebugMode) {
        print("Error generating health schedule: $e");
      }
      return _createDefaultSchedule(survey, userId);
    }
  }

  Future<HealthSchedule> _retryWithBackoff(
    Future<HealthSchedule> Function() action, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        return await action();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;

        if (kDebugMode) {
          print('Retry attempt $attempt failed: $e');
        }

        await Future.delayed(delay);
        delay *= 2;
      }
    }

    throw Exception('Failed after $maxRetries attempts');
  }

  HealthSchedule _createDefaultSchedule(HealthSurvey survey, String userId) {
    final now = DateTime.now();
    final List<HealthScheduleItem> defaultItems = [];

    if (survey.isPregnant && survey.dueDate != null) {
      defaultItems.addAll([
        HealthScheduleItem(
          title: 'First Trimester Check-up',
          description: 'Initial prenatal visit and health assessment',
          scheduledDate: now.add(Duration(days: 30)),
          category: 'checkup',
        ),
        HealthScheduleItem(
          title: 'Prenatal Vitamins',
          description: 'Daily prenatal vitamin intake',
          scheduledDate: now,
          category: 'supplement',
        ),
        HealthScheduleItem(
          title: 'Genetic Screening',
          description: 'Optional genetic screening test',
          scheduledDate: now.add(Duration(days: 60)),
          category: 'checkup',
        ),
      ]);
    } else if (!survey.isPregnant && survey.babyBirthDate != null) {
      defaultItems.addAll([
        HealthScheduleItem(
          title: 'First Pediatric Check-up',
          description: 'Initial pediatric visit and health assessment',
          scheduledDate: now.add(Duration(days: 30)),
          category: 'checkup',
        ),
        HealthScheduleItem(
          title: 'First Vaccine',
          description: 'First round of infant vaccines',
          scheduledDate: now.add(Duration(days: 60)),
          category: 'vaccine',
        ),
        HealthScheduleItem(
          title: 'Vitamin D Supplement',
          description: 'Daily vitamin D drops for infant',
          scheduledDate: now,
          category: 'supplement',
        ),
      ]);
    }

    return HealthSchedule(
      userId: userId,
      items: defaultItems,
      generatedAt: now,
    );
  }

  String _buildPrompt(HealthSurvey survey) {
    final now = DateTime.now();
    String prompt = """
You are a healthcare assistant specializing in pregnancy and infant care.
Current Date: ${now.toIso8601String()}
User Status: ${survey.isPregnant ? 'Pregnant' : 'New Parent'}
""";

    if (survey.age != null) {
      prompt += "User Age: ${survey.age}\n";
    }
    if (survey.location != null) {
      prompt += "User Location: ${survey.location}\n";
    }
    if (survey.prefersNaturalRemedies == true) {
      prompt += "User prefers natural/home remedies.\n";
    }
    if (survey.isBreastfeeding == true) {
      prompt += "User is breastfeeding.\n";
    }
    if (survey.dietaryPreference != null) {
      prompt += "Dietary Preference: ${survey.dietaryPreference}\n";
    }

    if (survey.isPregnant && survey.dueDate != null) {
      final pregnancyDuration = survey.dueDate!.difference(now).inDays;
      final pregnancyWeeks = 40 - (pregnancyDuration / 7).floor();
      prompt += "Due Date: ${survey.dueDate!.toIso8601String()}\n";
      prompt += "Current Pregnancy Week: $pregnancyWeeks\n";
      if (pregnancyWeeks >= 28) {
        prompt += "User is in third trimester, focus on late-pregnancy care and delivery prep.\n";
      }
      prompt += """
Generate a detailed pregnancy health schedule with sections:
1️⃣ Check-ups
2️⃣ Vaccines
3️⃣ Milestones
4️⃣ Supplements

Your final response must be in this JSON format:

{
  "items": [
    {
      "title": "32-Week Checkup",
      "description": "Monitor fetal growth, position, and mother's health.",
      "scheduledDate": "2025-06-01",
      "category": "checkup"
    },
    ...
  ]
}

- The key must be 'items' (not 'vaccine', 'checkups' etc.)
- 'category' must be one of: checkup, vaccine, supplement, milestone
- Dates in YYYY-MM-DD format
- Output ONLY pure JSON
""";
    }

    if (!survey.isPregnant && survey.babyBirthDate != null) {
      final babyAge = now.difference(survey.babyBirthDate!).inDays;
      final monthsOld = babyAge ~/ 30;
      prompt += "Baby Birth Date: ${survey.babyBirthDate!.toIso8601String()}\n";
      prompt += "Baby Age (months): $monthsOld\n";
      prompt += """
Generate a complete infant health schedule based on Malaysia's National Immunisation Programme (NIP), and include the following four sections:

1️⃣ Vaccines (based on Malaysian NIP):
- Follow the Malaysian schedule (BCG, Hep B, DTaP-IPV-Hib, Pneumococcal, MMR, etc.)
- Include missed vaccines if any (mark as 'Due ASAP')

2️⃣ Check-ups:
- Pediatric visits
- Growth and development assessments
- Vision and hearing screening

3️⃣ Milestones:
- Tummy time, rolling over, crawling, first words, walking, social play
- Feeding milestones (breastfeeding, introducing solids, self-feeding)
- Mark expected month and brief description

4️⃣ Supplements:
- Vitamin D drops
- Iron (if needed)
- Any others relevant for Malaysian infants

⛔️ Response Format Requirements:
- JSON must have a top-level key 'items'
- Each item must include: title, description, scheduledDate (YYYY-MM-DD), category
- Category must be: vaccine, checkup, milestone, or supplement
- Return ONLY valid pure JSON (no markdown, no ```json)

Here's an example of the required format:
{
  "items": [
    {
      "title": "6-Month Checkup",
      "description": "Assess baby's weight, reflexes, and vaccination status.",
      "scheduledDate": "2025-08-11",
      "category": "checkup"
    },
    {
      "title": "Vitamin D Drops",
      "description": "Give baby daily vitamin D drops for bone health.",
      "scheduledDate": "2025-03-01",
      "category": "supplement"
    }
  ]
}
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
        "temperature": 0.3,
        "maxOutputTokens": 3000,
        "topP": 0.8,
        "topK": 20
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

  Future<HealthSchedule> _parseAIResponse(String aiResponse, String userId) {
    try {
      return compute(
        _parseScheduleInIsolate,
        {
          'aiResponse': aiResponse,
          'userId': userId,
        },
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

HealthSchedule _parseScheduleInIsolate(Map<String, dynamic> payload) {
  final String aiResponse = payload['aiResponse'];
  final String userId = payload['userId'];

  final cleanedResponse = aiResponse
      .replaceAll('```json', '')
      .replaceAll('```', '')
      .trim();

  dynamic jsonData;
  try {
    if (cleanedResponse.startsWith('{') && !cleanedResponse.endsWith('}')) {
      final fixedResponse = cleanedResponse + '}';
      jsonData = json.decode(fixedResponse);
    } else {
      jsonData = json.decode(cleanedResponse);
    }
  } catch (e) {
    final jsonMatch = RegExp(r'\{.*\}', multiLine: true, dotAll: true).firstMatch(cleanedResponse);
    if (jsonMatch != null) {
      jsonData = json.decode(jsonMatch.group(0)!);
    } else {
      throw Exception("Could not extract valid JSON");
    }
  }

  if (!jsonData.containsKey('items') || jsonData['items'] is! List) {
    throw Exception("Invalid JSON format: missing 'items' array.");
  }

  final items = jsonData['items'] as List;
  final scheduleItems = items.map((item) {
    final date = DateTime.tryParse(item['scheduledDate'].toString());
    if (date == null) return null;
    return HealthScheduleItem(
      title: item['title'] ?? '',
      description: item['description'] ?? '',
      scheduledDate: date,
      category: item['category'] ?? 'milestone',
    );
  }).whereType<HealthScheduleItem>().toList();

  if (scheduleItems.isEmpty) {
    throw Exception("No valid schedule items parsed.");
  }

  scheduleItems.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

  return HealthSchedule(
    userId: userId,
    items: scheduleItems,
    generatedAt: DateTime.now(),
  );
}
