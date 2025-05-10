import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PerspectiveApiService {
  // Access API key from .env file
  static String get apiKey => dotenv.env['PERSPECTIVE_API_KEY'] ?? '';
  static const String endpoint = 'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze';

  /// Analyze text content for toxicity and other attributes
  /// Returns true if content passes moderation, false if it fails
  static Future<ModeratedContent> moderateContent(String text) async {
    if (text.trim().isEmpty) {
      return ModeratedContent(isAcceptable: true, scores: {});
    }

    try {
      final response = await http.post(
        Uri.parse('$endpoint?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'comment': {
            'text': text
          },
          'languages': ['en'],
          'requestedAttributes': {
            'TOXICITY': {},
            'SEVERE_TOXICITY': {},
            'IDENTITY_ATTACK': {},
            'INSULT': {},
            'PROFANITY': {},
            'THREAT': {},
            'SEXUALLY_EXPLICIT': {},
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final attributeScores = data['attributeScores'];
        
        // Extract scores for each attribute
        Map<String, double> scores = {};
        bool isAcceptable = true;
        
        attributeScores.forEach((attribute, scoreData) {
          final score = scoreData['summaryScore']['value'] as double;
          scores[attribute] = score;
          
          // Apply threshold checks - you can adjust these thresholds as needed
          if (attribute == 'TOXICITY' && score > 0.7 ||
              attribute == 'SEVERE_TOXICITY' && score > 0.5 ||
              attribute == 'IDENTITY_ATTACK' && score > 0.7 ||
              attribute == 'INSULT' && score > 0.7 ||
              attribute == 'PROFANITY' && score > 0.8 ||
              attribute == 'THREAT' && score > 0.5 ||
              attribute == 'SEXUALLY_EXPLICIT' && score > 0.7) {
            isAcceptable = false;
          }
        });
        
        return ModeratedContent(
          isAcceptable: isAcceptable,
          scores: scores,
        );
      } else {
        print('Perspective API error: ${response.statusCode} - ${response.body}');
        // On API error, we'll allow the content (you might want to handle this differently)
        return ModeratedContent(isAcceptable: true, scores: {});
      }
    } catch (e) {
      print('Error calling Perspective API: $e');
      // On error, we'll allow the content (you might want to handle this differently)
      return ModeratedContent(isAcceptable: true, scores: {});
    }
  }
  
  // Display a warning dialog for potentially problematic content
  static Future<bool> confirmPostContent(BuildContext context, String content) async {
    final result = await moderateContent(content);
    
    if (!result.isAcceptable) {
      // Show warning dialog
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Content Warning'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Our system detected potentially inappropriate content. Please review before posting:'),
              SizedBox(height: 12),
              Text('- ${_getIssueDescription(result.scores)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Edit'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Post Anyway'),
            ),
          ],
        ),
      ) ?? false;
    }
    
    return true; // Content is acceptable
  }
  
  // Helper method to provide human-readable issue description
  static String _getIssueDescription(Map<String, double> scores) {
    if (scores.containsKey('TOXICITY') && scores['TOXICITY']! > 0.7) {
      return 'This content may be perceived as toxic or negative';
    } else if (scores.containsKey('IDENTITY_ATTACK') && scores['IDENTITY_ATTACK']! > 0.7) {
      return 'This content may contain identity-based attacks';
    } else if (scores.containsKey('INSULT') && scores['INSULT']! > 0.7) {
      return 'This content may contain insults';
    } else if (scores.containsKey('PROFANITY') && scores['PROFANITY']! > 0.8) {
      return 'This content contains profanity';
    } else if (scores.containsKey('THREAT') && scores['THREAT']! > 0.5) {
      return 'This content may contain threatening language';
    } else if (scores.containsKey('SEXUALLY_EXPLICIT') && scores['SEXUALLY_EXPLICIT']! > 0.7) {
      return 'This content may contain sexually explicit language';
    } else {
      return 'This content may violate community guidelines';
    }
  }
}

class ModeratedContent {
  final bool isAcceptable;
  final Map<String, double> scores;
  
  ModeratedContent({
    required this.isAcceptable,
    required this.scores,
  });
} 