import 'package:flutter/material.dart';
import 'package:bumptobaby/services/pubmed_rag_service.dart';

/// A utility class to help seed the database with initial data from PubMed
class SeedPubMedData {
  final PubMedRagService _pubmedRagService = PubMedRagService();
  final BuildContext _context;
  bool _isSeeding = false;

  SeedPubMedData(this._context);

  /// Check if the database needs to be seeded with initial data
  Future<void> checkAndSeedDatabaseIfNeeded() async {
    try {
      // Check if we already have data in the database
      final testResults = await _pubmedRagService.findSimilarContent('pregnancy', limit: 1);
      
      if (testResults.isEmpty && !_isSeeding) {
        // No data found, ask user if they want to seed the database
        _showSeedDatabaseDialog();
      }
    } catch (e) {
      print('Error checking database status: $e');
      // Assume database needs seeding if error occurred
      _showSeedDatabaseDialog();
    }
  }

  /// Show a dialog to ask user if they want to seed the database
  void _showSeedDatabaseDialog() {
    showDialog(
      context: _context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Initial Setup'),
        content: Text(
          'BumpToBaby needs to download medical information for the content moderation system. '
          'This will happen in the background and only needs to be done once. '
          'Would you like to proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1E6091),
            ),
            onPressed: () {
              Navigator.pop(context);
              _startSeedingDatabase();
            },
            child: Text('Proceed'),
          ),
        ],
      ),
    );
  }

  /// Start the database seeding process
  Future<void> _startSeedingDatabase() async {
    if (_isSeeding) return; // Prevent multiple seeding operations
    
    _isSeeding = true;
    
    // Show progress indicator
    final snackBar = SnackBar(
      content: Row(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text('Downloading medical information...'),
          ),
        ],
      ),
      duration: Duration(seconds: 30),
    );
    
    ScaffoldMessenger.of(_context).showSnackBar(snackBar);
    
    try {
      // Start the seeding process
      await _pubmedRagService.seedInitialData();
      
      // Dismiss ongoing snackbar
      ScaffoldMessenger.of(_context).hideCurrentSnackBar();
      
      // Show success message
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text('Medical information downloaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error seeding database: $e');
      
      // Dismiss ongoing snackbar
      ScaffoldMessenger.of(_context).hideCurrentSnackBar();
      
      // Show error message
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text('Error downloading medical information. Please try again later.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      _isSeeding = false;
    }
  }
} 