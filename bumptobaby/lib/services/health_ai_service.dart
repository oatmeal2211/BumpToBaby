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
      // Calculate weeks of pregnancy
      final weeksUntilDue = survey.dueDate!.difference(now).inDays ~/ 7;
      final currentWeek = 40 - weeksUntilDue;
      
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
        // Add default risk alert
        HealthScheduleItem(
          title: 'Monitor for Pregnancy Symptoms',
          description: 'Watch for severe nausea, spotting, or abdominal pain. Contact your healthcare provider immediately if these occur.',
          scheduledDate: now,
          category: 'risk_alert',
          severity: 'medium',
          additionalData: {
            'symptoms': 'Severe nausea, spotting, abdominal pain',
            'action': 'Contact healthcare provider immediately'
          },
        ),
        // Add default prediction
        HealthScheduleItem(
          title: 'Prepare for Morning Sickness',
          description: 'Morning sickness typically peaks around weeks 8-12. Stock up on crackers, ginger tea, and small snacks to help manage nausea.',
          scheduledDate: now.add(Duration(days: 14)),
          category: 'prediction',
          additionalData: {
            'essentials': 'Crackers, ginger tea, small snacks',
            'timing': 'Peaks at weeks 8-12'
          },
        ),
      ]);
      
      // Add mental health check-in if mental health score is low
      if (survey.mentalHealthScore != null && survey.mentalHealthScore! < 5) {
        defaultItems.add(
          HealthScheduleItem(
            title: 'Mental Health Check-in',
            description: 'Schedule an appointment with a mental health professional to discuss your feelings and get support during pregnancy.',
            scheduledDate: now.add(Duration(days: 7)),
            category: 'risk_alert',
            severity: 'medium',
            additionalData: {
              'reason': 'Low mental health score reported',
              'action': 'Schedule appointment with mental health professional'
            },
          )
        );
      }
      
    } else if (!survey.isPregnant && survey.babyBirthDate != null) {
      // Calculate baby's age in months
      final babyAgeInDays = now.difference(survey.babyBirthDate!).inDays;
      final babyAgeInMonths = (babyAgeInDays / 30.44).floor(); // Average days in a month
      
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
        // Add default risk alert
        HealthScheduleItem(
          title: 'Monitor for Fever After Vaccination',
          description: 'Watch for fever or unusual irritability after vaccination. Contact your pediatrician if temperature exceeds 101°F (38.3°C).',
          scheduledDate: now.add(Duration(days: 60)),
          category: 'risk_alert',
          severity: 'medium',
          additionalData: {
            'symptoms': 'Fever, unusual irritability',
            'action': 'Contact pediatrician if temperature exceeds 101°F (38.3°C)'
          },
        ),
        // Add default prediction based on baby's age
        HealthScheduleItem(
          title: babyAgeInMonths < 6 ? 'Prepare for Solid Foods' : 'Prepare for Mobility',
          description: babyAgeInMonths < 6 
              ? 'Your baby will likely be ready to start solid foods around 6 months. Stock up on baby spoons, bibs, and first foods.'
              : 'Your baby will become more mobile soon. Ensure your home is baby-proofed with outlet covers and cabinet locks.',
          scheduledDate: now.add(Duration(days: 30)),
          category: 'prediction',
          additionalData: {
            'essentials': babyAgeInMonths < 6 ? 'Baby spoons, bibs, first foods' : 'Outlet covers, cabinet locks, baby gates',
            'timing': babyAgeInMonths < 6 ? 'Around 6 months' : 'Coming weeks'
          },
        ),
      ]);
      
      // Add weight monitoring if weight is provided and concerning
      if (survey.babyWeight != null) {
        double expectedWeight = 3.5 + (babyAgeInMonths * 0.5); // Very rough estimate
        if (survey.babyWeight! < expectedWeight * 0.8) {
          defaultItems.add(
            HealthScheduleItem(
              title: 'Weight Monitoring',
              description: 'Baby\'s weight appears to be lower than expected. Schedule a check-up with your pediatrician to discuss growth and feeding.',
              scheduledDate: now.add(Duration(days: 7)),
              category: 'risk_alert',
              severity: 'medium',
              additionalData: {
                'reason': 'Weight below expected range',
                'action': 'Schedule pediatrician appointment'
              },
            )
          );
        }
      }
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

IMPORTANT: Generate a HIGHLY PERSONALIZED health schedule that directly addresses the user's specific concerns, lifestyle, and health status. Include risk alerts and predictions based on the information provided.
""";

    if (survey.isPregnant) {
      prompt += """
Pregnancy Information:
Due Date: ${survey.dueDate?.toIso8601String() ?? 'Unknown'}
""";
      
      // Add mental health information for pregnant mothers
      if (survey.mentalHealthScore != null) {
        prompt += "Mental Health Score: ${survey.mentalHealthScore}/10\n";
        
        // Add specific guidance for concerning mental health scores
        if (survey.mentalHealthScore! < 5) {
          prompt += "CRITICAL: User has reported low mental health score. Include risk alerts and mental health support recommendations.\n";
        }
      }
      if (survey.energyLevel != null) {
        prompt += "Energy Level: ${survey.energyLevel}/10\n";
        
        // Add specific guidance for low energy levels
        if (survey.energyLevel! < 5) {
          prompt += "CRITICAL: User has reported low energy levels. Include specific recommendations for energy management and rest.\n";
        }
      }
      if (survey.mood != null) {
        prompt += "Current Mood: ${survey.mood}\n";
        
        // Add specific guidance for concerning moods
        if (survey.mood == 'Anxious' || survey.mood == 'Stressed' || survey.mood == 'Sad') {
          prompt += "CRITICAL: User has reported ${survey.mood} mood. Include specific mental health support recommendations and risk alerts.\n";
        }
      }
      if (survey.lastMentalHealthCheckIn != null) {
        prompt += "Last Mental Health Check-in: ${survey.lastMentalHealthCheckIn!.toIso8601String()}\n";
      }
    } else if (survey.babyBirthDate != null) {
      // Calculate baby's age in months
      final babyAgeInDays = now.difference(survey.babyBirthDate!).inDays;
      final babyAgeInMonths = (babyAgeInDays / 30.44).floor(); // Average days in a month
      
      prompt += """
Baby Information:
Birth Date: ${survey.babyBirthDate!.toIso8601String()}
Age: ${babyAgeInMonths} month${babyAgeInMonths != 1 ? 's' : ''}
Gender: ${survey.babyGender ?? 'Unknown'}
""";

      if (survey.babyWeight != null) {
        prompt += "Weight: ${survey.babyWeight} kg\n";
        
        // Check for weight concerns based on age
        if (babyAgeInMonths <= 12) {
          // Very rough estimate - this should be replaced with proper growth chart data
          double expectedWeight = 3.5 + (babyAgeInMonths * 0.5);
          if (survey.babyWeight! < expectedWeight * 0.8) {
            prompt += "CRITICAL: Baby's weight appears to be lower than expected for age. Include risk alerts for weight monitoring.\n";
          }
        }
      }
      if (survey.babyHeight != null) {
        prompt += "Height: ${survey.babyHeight} cm\n";
      }
      
      // Add baby environment information
      if (survey.babyEnvironment != null && survey.babyEnvironment!.isNotEmpty) {
        prompt += "Baby's Environment:\n";
        survey.babyEnvironment!.forEach((key, value) {
          prompt += "- $key: $value\n";
        });
        prompt += "IMPORTANT: Customize recommendations based on the baby's environment details above.\n";
      }
    }

    if (survey.healthConditions != null && survey.healthConditions!.isNotEmpty) {
      prompt += "Health Conditions: ${survey.healthConditions!.join(', ')}\n";
      prompt += "CRITICAL: User has reported health conditions. Include specific risk alerts and monitoring recommendations for these conditions.\n";
    }
    if (survey.allergies != null && survey.allergies!.isNotEmpty) {
      prompt += "Allergies: ${survey.allergies!.join(', ')}\n";
      prompt += "IMPORTANT: Include specific precautions and monitoring for reported allergies.\n";
    }
    if (survey.medications != null && survey.medications!.isNotEmpty) {
      prompt += "Medications: ${survey.medications!.join(', ')}\n";
      prompt += "IMPORTANT: Consider medication schedule and potential interactions in recommendations.\n";
    }
    if (survey.age != null) {
      prompt += "Parent Age: ${survey.age}\n";
      if (survey.isPregnant && (survey.age! < 18 || survey.age! > 35)) {
        prompt += "CRITICAL: Parent age may indicate higher risk pregnancy. Include appropriate risk alerts and monitoring.\n";
      }
    }
    if (survey.location != null) {
      prompt += "Location: ${survey.location}\n";
      prompt += "IMPORTANT: Tailor recommendations to healthcare resources available in ${survey.location}.\n";
    }
    if (survey.prefersNaturalRemedies != null) {
      prompt += "Prefers Natural Remedies: ${survey.prefersNaturalRemedies! ? 'Yes' : 'No'}\n";
      if (survey.prefersNaturalRemedies!) {
        prompt += "IMPORTANT: Include natural remedy options alongside conventional treatments where appropriate.\n";
      }
    }
    if (survey.isBreastfeeding != null) {
      prompt += "Breastfeeding: ${survey.isBreastfeeding! ? 'Yes' : 'No'}\n";
      if (survey.isBreastfeeding!) {
        prompt += "IMPORTANT: Include breastfeeding support and monitoring recommendations.\n";
      }
    }
    if (survey.dietaryPreference != null) {
      prompt += "Dietary Preference: ${survey.dietaryPreference}\n";
      prompt += "IMPORTANT: Ensure nutritional recommendations align with dietary preferences.\n";
    }
    
    // Add new fields
    if (survey.parentConcerns != null && survey.parentConcerns!.isNotEmpty) {
      prompt += "Parent Concerns: ${survey.parentConcerns!.join(', ')}\n";
      prompt += "CRITICAL: Directly address each of the parent's concerns with specific recommendations, monitoring, and support.\n";
    }
    if (survey.lifestyle != null && survey.lifestyle!.isNotEmpty) {
      prompt += "Lifestyle Information:\n";
      survey.lifestyle!.forEach((key, value) {
        prompt += "- $key: $value\n";
      });
      prompt += "IMPORTANT: Tailor all recommendations to fit the user's lifestyle details above.\n";
    }

    // Enhanced prompt for generating health schedule
    if (survey.isPregnant) {
      prompt += """
Generate a complete pregnancy health schedule with the following sections:

1️⃣ Checkups:
- Regular prenatal visits
- Tests and screenings
- Specialist consultations if needed
- PERSONALIZE based on health conditions and concerns

2️⃣ Milestones:
- Key pregnancy milestones by trimester
- Baby development stages
- Preparation activities for birth
- PERSONALIZE based on parent concerns and lifestyle

3️⃣ Supplements:
- Prenatal vitamins
- Any additional supplements based on health conditions
- PERSONALIZE based on dietary preferences and health needs

4️⃣ Mental Health:
- Regular mental health check-ins
- Mood and energy level monitoring
- Self-care suggestions based on current mental state
- PERSONALIZE based on reported mental health score, energy level, and mood

5️⃣ Risk Alerts:
- Personalized risk alerts based on health conditions, age, mental health, or concerns
- Warning signs to watch for
- MUST INCLUDE at least 2-3 specific risk alerts based on the user's data
- For each risk alert, include clear actions to take

6️⃣ Predictions:
- Upcoming needs and preparations
- Suggested purchases and timing
- Reminders for important appointments
- MUST INCLUDE at least 2-3 specific predictions based on the user's stage of pregnancy

⛔️ Response Format Requirements:
- JSON must have a top-level key 'items'
- Each item must include: title, description, scheduledDate (YYYY-MM-DD), category
- Category must be: checkup, milestone, supplement, risk_alert, or prediction
- For risk_alert items, include a 'severity' field with value 'low', 'medium', or 'high'
- Include relevant additionalData as needed
- Return ONLY valid pure JSON (no markdown, no ```json)
""";
    } else {
      prompt += """
Generate a complete infant health schedule based on Malaysia's National Immunisation Programme (NIP), and include the following sections:

1️⃣ Vaccines (based on Malaysian NIP):
- Follow the Malaysian schedule (BCG, Hep B, DTaP-IPV-Hib, Pneumococcal, MMR, etc.)
- Include missed vaccines if any (mark as 'Due ASAP')
- PERSONALIZE based on parent concerns, allergies, or baby's environment

2️⃣ Check-ups:
- Pediatric visits
- Growth and development assessments
- Vision and hearing screening
- PERSONALIZE based on specific health concerns and baby's development

3️⃣ Milestones:
- Tummy time, rolling over, crawling, first words, walking, social play
- Feeding milestones (breastfeeding, introducing solids, self-feeding)
- Mark expected month and brief description
- PERSONALIZE based on baby's current development and parent concerns

4️⃣ Supplements:
- Vitamin D drops
- Iron (if needed)
- Any others relevant for Malaysian infants
- PERSONALIZE based on baby's diet and health needs

5️⃣ Risk Alerts:
- Generate personalized risk alerts based on baby's weight, height, and development
- Include severity level (low, medium, high)
- Suggest appropriate actions (e.g., pediatric visit)
- MUST INCLUDE at least 2-3 specific risk alerts based on the baby's data
- For each risk alert, include clear actions to take

6️⃣ Predictions:
- Predict upcoming needs based on baby's age
- Suggest essential purchases with timing
- Reminder for important developmental stages
- MUST INCLUDE at least 2-3 specific predictions based on the baby's age and development

⛔️ Response Format Requirements:
- JSON must have a top-level key 'items'
- Each item must include: title, description, scheduledDate (YYYY-MM-DD), category
- Category must be: vaccine, checkup, milestone, supplement, risk_alert, or prediction
- For risk_alert items, include a 'severity' field with value 'low', 'medium', or 'high'
- Include relevant additionalData as needed
- Return ONLY valid pure JSON (no markdown, no ```json)
""";
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
        "temperature": 0.7,
        "maxOutputTokens": 3000,
        "topP": 0.9,
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
    
    // Extract severity for risk alerts
    String? severity;
    if (item['category'] == 'risk_alert' && item.containsKey('severity')) {
      severity = item['severity'];
    }
    
    // Extract additional data if available
    Map<String, dynamic>? additionalData;
    if (item.containsKey('additionalData')) {
      additionalData = Map<String, dynamic>.from(item['additionalData']);
    }
    
    return HealthScheduleItem(
      title: item['title'] ?? '',
      description: item['description'] ?? '',
      scheduledDate: date,
      category: item['category'] ?? 'milestone',
      isCompleted: item['isCompleted'] ?? false,
      severity: severity,
      additionalData: additionalData,
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
