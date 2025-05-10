import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PerspectiveApiService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Access API key from .env file
  static String get apiKey => dotenv.env['PERSPECTIVE_API_KEY'] ?? '';
  static const String endpoint = 'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze';

  // Threshold values for different attributes
  static const double _severeThreshold = 0.85;
  static const double _warnThreshold = 0.7;

  /// Check content using Perspective API and generate toxicity scores
  static Future<ContentRating> checkContent(String text) async {
    if (text.trim().isEmpty) {
      return ContentRating(isHarmful: false, category: 'clean');
    }

    try {
      final url = '$endpoint?key=$apiKey';
      
      // Create the request body according to Perspective API specs
      final requestBody = jsonEncode({
        'comment': {'text': text},
        'languages': ['en'],
        'requestedAttributes': {
          'TOXICITY': {},
          'SEVERE_TOXICITY': {},
          'IDENTITY_ATTACK': {},
          'THREAT': {},
          'PROFANITY': {},
          'SEXUALLY_EXPLICIT': {},
        },
        'doNotStore': true
      });

      // Make the API request
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scores = data['attributeScores'];
        
        // Check for severe harmful content first (auto-block)
        double severeToxicityScore = scores['SEVERE_TOXICITY']?['summaryScore']?['value'] ?? 0.0;
        double threatScore = scores['THREAT']?['summaryScore']?['value'] ?? 0.0;
        
        if (severeToxicityScore >= _severeThreshold) {
          return ContentRating(
            isHarmful: true,
            category: 'severe_toxicity',
            severity: severeToxicityScore,
            autoBlock: true,
          );
        }
        
        if (threatScore >= _severeThreshold) {
          return ContentRating(
            isHarmful: true,
            category: 'threat',
            severity: threatScore,
            autoBlock: true,
          );
        }
        
        // Check other attributes
        double toxicityScore = scores['TOXICITY']?['summaryScore']?['value'] ?? 0.0;
        double identityAttackScore = scores['IDENTITY_ATTACK']?['summaryScore']?['value'] ?? 0.0;
        double profanityScore = scores['PROFANITY']?['summaryScore']?['value'] ?? 0.0;
        double sexualScore = scores['SEXUALLY_EXPLICIT']?['summaryScore']?['value'] ?? 0.0;
        
        // Find the highest scoring harmful attribute
        final attributes = [
          {'name': 'toxicity', 'score': toxicityScore},
          {'name': 'identity_attack', 'score': identityAttackScore},
          {'name': 'profanity', 'score': profanityScore},
          {'name': 'sexually_explicit', 'score': sexualScore},
        ];
        
        attributes.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
        
        if ((attributes[0]['score'] as double) >= _warnThreshold) {
          return ContentRating(
            isHarmful: true,
            category: attributes[0]['name'] as String,
            severity: attributes[0]['score'] as double,
          );
        }
        
        // Content is clean
        return ContentRating(isHarmful: false, category: 'clean');
      } else {
        print('Perspective API error: ${response.statusCode}, ${response.body}');
        // Fall back to clean if API fails
        return ContentRating(isHarmful: false, category: 'clean');
      }
    } catch (e) {
      print('Error calling Perspective API: $e');
      // Fall back to clean if an exception occurs
      return ContentRating(isHarmful: false, category: 'clean');
    }
  }

  /// Process content with warning dialog if needed
  static Future<ContentProcessResult> processContent(BuildContext context, String content) async {
    final rating = await checkContent(content);
    print('Content check result: ${rating.category}, severity: ${rating.severity}, autoBlock: ${rating.autoBlock}');
    
    // Clean content - allow immediately
    if (!rating.isHarmful) {
      return ContentProcessResult(canPost: true, userOverrode: false);
    }
    
    // Auto-block content that violates strict policies
    if (rating.autoBlock) {
      _storeHarmfulContent(content, rating, 'blocked');
      _showAutomaticBlockMessage(context);
      return ContentProcessResult(canPost: false, userOverrode: false);
    }
    
    // Show warning for other harmful content
    final shouldPost = await _showWarningDialog(context, rating);
    if (shouldPost) {
      // User chose to post anyway - record but allow
      _storeHarmfulContent(content, rating, 'warned_allowed');
      return ContentProcessResult(canPost: true, userOverrode: true);
    } else {
      // User chose to edit their content
      return ContentProcessResult(canPost: false, userOverrode: false);
    }
  }
  
  /// Simplified wrapper for confirmPostContent that returns just a boolean
  static Future<bool> confirmPostContent(BuildContext context, String content) async {
    final result = await processContent(context, content);
    return result.canPost;
  }
  
  // Store harmful content in Firestore for review
  static Future<void> _storeHarmfulContent(
    String content, 
    ContentRating rating,
    String action
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _firestore.collection('harmful_content').add({
        'userId': user.uid,
        'content': content,
        'category': rating.category,
        'severity': rating.severity,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('Stored harmful content in Firestore');
    } catch (e) {
      print('Error storing harmful content: $e');
    }
  }

  // Show warning dialog for harmful content
  static Future<bool> _showWarningDialog(BuildContext context, ContentRating rating) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Content Warning'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Our system detected potentially inappropriate content:'),
            SizedBox(height: 12),
            Text('- ${_getWarningMessage(rating.category)}', 
              style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Please consider editing your message before posting.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Edit Content'),
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

  // Show automatic block message for severe violations
  static void _showAutomaticBlockMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'This content violates community guidelines and cannot be posted.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // Get human-readable warning message
  static String _getWarningMessage(String category) {
    switch (category) {
      case 'toxicity':
        return 'This content may contain toxic language';
      case 'severe_toxicity':
        return 'This content contains language that violates our community guidelines';
      case 'identity_attack':
        return 'This content may contain identity-based attacks';
      case 'threat':
        return 'This content may contain threatening language';
      case 'profanity':
        return 'This content contains profanity';
      case 'sexually_explicit':
        return 'This content may contain sexually explicit language';
      default:
        return 'This content may violate community guidelines';
    }
  }
}

/// Simple class to represent content rating
class ContentRating {
  final bool isHarmful;
  final String category; 
  final double severity;
  final bool autoBlock;
  
  ContentRating({
    required this.isHarmful,
    required this.category,
    this.severity = 0.0,
    this.autoBlock = false,
  });
}

/// Result of content processing
class ContentProcessResult {
  final bool canPost;
  final bool userOverrode;
  
  ContentProcessResult({
    required this.canPost,
    required this.userOverrode,
  });
} 