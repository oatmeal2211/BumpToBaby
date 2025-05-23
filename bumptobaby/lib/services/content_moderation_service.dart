import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bumptobaby/services/perspective_api_service.dart';
import 'package:bumptobaby/services/pubmed_rag_service.dart';
import 'package:bumptobaby/models/medical_info.dart';

class ContentModerationResult {
  final bool isHarmful;
  final String category;
  final bool isMedicalMisinformation;
  final MedicalFactCheck? factCheck;
  final double? severity;
  final bool autoBlock;

  ContentModerationResult({
    required this.isHarmful,
    required this.category,
    required this.isMedicalMisinformation,
    this.factCheck,
    this.severity,
    this.autoBlock = false,
  });

  bool get shouldFlag => isHarmful || isMedicalMisinformation;
  
  String getModerationType() {
    if (isMedicalMisinformation) return 'medical_misinformation';
    return category;
  }
  
  String getExplanation() {
    if (isMedicalMisinformation && factCheck != null) {
      return factCheck!.explanation;
    }
    return '';
  }
}

class ContentModerationService {
  final PerspectiveApiService _perspectiveService = PerspectiveApiService();
  final PubMedRagService _pubmedRagService = PubMedRagService();
  
  // Check content for both toxic content and medical misinformation
  Future<ContentModerationResult> checkContent(String text) async {
    try {
      // First check with Perspective API for toxicity
      final toxicityRating = await PerspectiveApiService.checkContent(text);
      
      // If it's severely harmful or threatening, block immediately
      if (toxicityRating.isHarmful && toxicityRating.autoBlock) {
        return ContentModerationResult(
          isHarmful: true,
          category: toxicityRating.category,
          isMedicalMisinformation: false,
          severity: toxicityRating.severity,
          autoBlock: true,
        );
      }
      
      // Check for medical misinformation using RAG
      final factCheck = await _pubmedRagService.checkForMisinformation(text);
      
      // Generate combined result
      return ContentModerationResult(
        isHarmful: toxicityRating.isHarmful,
        category: toxicityRating.category,
        isMedicalMisinformation: factCheck.isMisinformation,
        factCheck: factCheck,
        severity: toxicityRating.severity,
        autoBlock: toxicityRating.autoBlock || factCheck.isMisinformation,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error in content moderation: $e');
      }
      
      // Return safe default on error
      return ContentModerationResult(
        isHarmful: false,
        category: 'clean',
        isMedicalMisinformation: false,
      );
    }
  }
  
  // Process content for posting, with UI dialog
  Future<bool> processContent(BuildContext context, String content) async {
    try {
      final moderationResult = await checkContent(content);
      
      // If content is clean, allow immediately
      if (!moderationResult.shouldFlag) {
        return true;
      }
      
      // Auto-block content that violates policies
      if (moderationResult.autoBlock) {
        _showBlockedContentDialog(context, moderationResult);
        return false;
      }
      
      // Show appropriate warning dialog
      final userDecision = await _showWarningDialog(context, moderationResult);
      return userDecision;
    } catch (e) {
      if (kDebugMode) {
        print('Error processing content: $e');
      }
      return true; // Default to allowing if error
    }
  }
  
  // Show warning dialog with different content based on moderation result
  Future<bool> _showWarningDialog(BuildContext context, ContentModerationResult result) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          result.isMedicalMisinformation 
            ? 'Medical Information Warning' 
            : 'Content Warning'
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.isHarmful && !result.isMedicalMisinformation) ...[
                Text('Our system detected potentially inappropriate content:'),
                SizedBox(height: 8),
                Text('- ${_getToxicityWarningMessage(result.category)}', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ],
              
              if (result.isMedicalMisinformation && result.factCheck != null) ...[
                Text('Our medical fact-checking system found potential misinformation:'),
                SizedBox(height: 8),
                Text(result.factCheck!.explanation, 
                  style: TextStyle(fontWeight: FontWeight.w500)),
                SizedBox(height: 12),
                if (result.factCheck!.relatedSources.isNotEmpty) ...[
                  Text('Based on medical sources:', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  ...result.factCheck!.relatedSources.take(2).map((source) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${source.title}', 
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    )
                  ),
                ],
              ],
              
              SizedBox(height: 12),
              Text('Please consider editing your message before posting.'),
            ],
          ),
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
  
  // Show dialog for auto-blocked content
  void _showBlockedContentDialog(BuildContext context, ContentModerationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Content Blocked'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.isMedicalMisinformation
                    ? 'This content has been blocked because it contains medical misinformation that could potentially harm others.'
                    : 'This content violates our community guidelines and cannot be posted.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              if (result.isMedicalMisinformation && result.factCheck != null) ...[
                Text(result.factCheck!.explanation),
                SizedBox(height: 8),
              ],
              Text('Please edit your content to remove any harmful or misleading information.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Get human-readable warning message for toxicity
  String _getToxicityWarningMessage(String category) {
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
  
  // Create widget for displaying misinformation warning on posts
  Widget buildMisinformationWarning(MedicalFactCheck factCheck) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
              SizedBox(width: 8),
              Text(
                'Medical Information Alert',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            factCheck.explanation,
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 4),
          if (factCheck.relatedSources.isNotEmpty) ...[
            InkWell(
              onTap: () {
                // Could expand to show sources
              },
              child: Text(
                'View medical sources',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 