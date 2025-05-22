import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bumptobaby/screens/growth_development_screen.dart'; // Import for DiaryEntry model
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:bumptobaby/services/offline_diary_service.dart';

class DiaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OfflineDiaryService _offlineService = OfflineDiaryService();

  // Get the current user ID
  String? get _userId => _auth.currentUser?.uid;

  // Check if user is logged in
  bool get isUserLoggedIn => _userId != null;

  // Reference to user's diary entries collection
  CollectionReference<Map<String, dynamic>> _getDiaryCollection(String babyProfileId) {
    if (_userId == null) {
      throw Exception('User not logged in');
    }
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('babyProfiles')
        .doc(babyProfileId)
        .collection('diaryEntries');
  }

  // Check connectivity
  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Save a diary entry
  Future<void> saveDiaryEntry(String babyProfileId, DiaryEntry entry) async {
    try {
      if (_userId == null) {
        developer.log('Cannot save diary entry: User not logged in', name: 'DiaryService');
        throw Exception('User not logged in');
      }

      // Validate entry
      if (entry.entryType != 'fetal' && entry.entryType != 'baby') {
        developer.log('Invalid entry type: ${entry.entryType}', name: 'DiaryService');
        throw Exception('Invalid entry type: must be "fetal" or "baby"');
      }

      if (entry.title.isEmpty || entry.description.isEmpty) {
        developer.log('Missing required fields in diary entry', name: 'DiaryService');
        throw Exception('Diary entry must have title and description');
      }

      // Check connectivity
      final isOnline = await _isOnline();
      
      // Always save to offline storage first
      await _offlineService.saveOfflineEntry(babyProfileId, entry);

      if (isOnline) {
        // If online, save to Firebase and sync pending entries
        await _saveToFirebase(babyProfileId, entry);
        await _syncPendingEntries(babyProfileId);
      }
    } catch (e) {
      developer.log('Error in saveDiaryEntry: $e', name: 'DiaryService');
      rethrow;
    }
  }

  // Save entry to Firebase
  Future<void> _saveToFirebase(String babyProfileId, DiaryEntry entry) async {
    try {
      final entryData = entry.toJson();
      final String entryId = '${entry.date.millisecondsSinceEpoch}_${entry.entryType}';
      
      // Ensure the user document exists
      await _firestore.collection('users').doc(_userId).set({
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Ensure profile document exists
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('babyProfiles')
          .doc(babyProfileId)
          .set({
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Save to Firestore
      final docRef = _getDiaryCollection(babyProfileId).doc(entryId);
      await _firestore.runTransaction((transaction) async {
        transaction.set(docRef, entryData);
      });
      
      developer.log('Successfully saved diary entry to Firebase: $entryId', name: 'DiaryService');
    } catch (e) {
      developer.log('Error saving to Firebase: $e', name: 'DiaryService');
      rethrow;
    }
  }

  // Sync pending entries
  Future<void> _syncPendingEntries(String babyProfileId) async {
    try {
      final pendingEntries = await _offlineService.getPendingEntries(babyProfileId);
      
      if (pendingEntries.isEmpty) return;

      for (final entry in pendingEntries) {
        await _saveToFirebase(babyProfileId, entry);
      }

      // Clear pending entries after successful sync
      await _offlineService.clearPendingEntries(babyProfileId);
      
      developer.log('Successfully synced ${pendingEntries.length} pending entries', name: 'DiaryService');
    } catch (e) {
      developer.log('Error syncing pending entries: $e', name: 'DiaryService');
      // Don't rethrow - we don't want to interrupt the user's flow if sync fails
    }
  }

  // Get all diary entries
  Future<List<DiaryEntry>> getDiaryEntries(String babyProfileId) async {
    try {
      if (_userId == null) {
        developer.log('Cannot get diary entries: User not logged in', name: 'DiaryService');
        throw Exception('User not logged in');
      }

      // Check connectivity
      final isOnline = await _isOnline();
      
      List<DiaryEntry> entries = [];
      
      if (isOnline) {
        // If online, get from Firebase and sync pending entries
        final snapshot = await _getDiaryCollection(babyProfileId)
            .orderBy('date', descending: true)
            .get();
            
        for (var doc in snapshot.docs) {
          try {
            final entry = DiaryEntry.fromJson(doc.data());
            entries.add(entry);
          } catch (e) {
            developer.log('Error parsing diary entry ${doc.id}: $e', name: 'DiaryService');
          }
        }
        
        // Try to sync any pending entries
        await _syncPendingEntries(babyProfileId);
      }
      
      // Get offline entries
      final offlineEntries = await _offlineService.getOfflineEntries(babyProfileId);
      
      // Merge online and offline entries, removing duplicates
      final allEntries = {...entries, ...offlineEntries}.toList();
      allEntries.sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
      
      // Log distribution of entry types for debugging
      final fetalCount = allEntries.where((e) => e.entryType == 'fetal').length;
      final babyCount = allEntries.where((e) => e.entryType == 'baby').length;
      developer.log('Entry types: fetal=$fetalCount, baby=$babyCount', name: 'DiaryService');
      
      return allEntries;
    } catch (e) {
      developer.log('Error getting diary entries: $e', name: 'DiaryService');
      // Return offline entries if available
      return await _offlineService.getOfflineEntries(babyProfileId);
    }
  }

  // Delete a diary entry
  Future<void> deleteDiaryEntry(String babyProfileId, DiaryEntry entry) async {
    try {
      if (_userId == null) {
        developer.log('Cannot delete diary entry: User not logged in', name: 'DiaryService');
        throw Exception('User not logged in');
      }

      // Delete from offline storage first
      await _offlineService.deleteOfflineEntry(babyProfileId, entry);

      // Check connectivity
      final isOnline = await _isOnline();
      
      if (isOnline) {
        // If online, delete from Firebase
        final String entryId = '${entry.date.millisecondsSinceEpoch}_${entry.entryType}';
        await _getDiaryCollection(babyProfileId).doc(entryId).delete();
        developer.log('Successfully deleted diary entry from Firebase: $entryId', name: 'DiaryService');
      }
    } catch (e) {
      developer.log('Error deleting diary entry: $e', name: 'DiaryService');
      rethrow;
    }
  }

  // Save multiple diary entries
  Future<void> saveDiaryEntries(String babyProfileId, List<DiaryEntry> entries) async {
    try {
      if (_userId == null) {
        developer.log('Cannot save diary entries: User not logged in', name: 'DiaryService');
        throw Exception('User not logged in');
      }

      // Save all entries to offline storage first
      for (final entry in entries) {
        await _offlineService.saveOfflineEntry(babyProfileId, entry);
      }

      // Check connectivity
      final isOnline = await _isOnline();
      
      if (isOnline) {
        // If online, save to Firebase
        final batch = _firestore.batch();
        
        // Ensure the user document exists
        await _firestore.collection('users').doc(_userId).set({
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        for (final entry in entries) {
          if (entry.entryType != 'fetal' && entry.entryType != 'baby') {
            developer.log('Skipping entry with invalid type: ${entry.entryType}', name: 'DiaryService');
            continue;
          }
          
          final String entryId = '${entry.date.millisecondsSinceEpoch}_${entry.entryType}';
          final docRef = _getDiaryCollection(babyProfileId).doc(entryId);
          batch.set(docRef, entry.toJson());
        }
        
        await batch.commit();
        developer.log('Successfully saved ${entries.length} diary entries to Firebase', name: 'DiaryService');
      }
    } catch (e) {
      developer.log('Error saving diary entries: $e', name: 'DiaryService');
      rethrow;
    }
  }

  // Delete all diary entries
  Future<void> deleteAllDiaryEntries(String babyProfileId) async {
    try {
      if (_userId == null) {
        developer.log('Cannot delete all diary entries: User not logged in', name: 'DiaryService');
        throw Exception('User not logged in');
      }

      // Check connectivity
      final isOnline = await _isOnline();
      
      if (isOnline) {
        final snapshot = await _getDiaryCollection(babyProfileId).get();
        
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        developer.log('Successfully deleted all diary entries from Firebase', name: 'DiaryService');
      }

      // Clear offline entries
      await _offlineService.clearPendingEntries(babyProfileId);
      
    } catch (e) {
      developer.log('Error deleting all diary entries: $e', name: 'DiaryService');
      rethrow;
    }
  }
} 