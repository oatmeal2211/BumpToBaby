import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bumptobaby/screens/growth_development_screen.dart';
import 'dart:developer' as developer;

class OfflineDiaryService {
  static const String _pendingEntriesKey = 'pending_diary_entries';
  static const String _offlineEntriesKey = 'offline_diary_entries';

  // Save a diary entry to offline storage
  Future<void> saveOfflineEntry(String profileId, DiaryEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing offline entries for this profile
      final offlineEntries = await getOfflineEntries(profileId);
      
      // Remove any existing entry with the same ID
      offlineEntries.removeWhere((e) => e.id == entry.id);
      
      // Add new entry
      offlineEntries.add(entry);
      
      // Save back to SharedPreferences
      final entriesJson = offlineEntries.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('${_offlineEntriesKey}_$profileId', entriesJson);
      
      // Add to pending entries for sync
      final pendingEntries = await getPendingEntries(profileId);
      pendingEntries.removeWhere((e) => e.id == entry.id); // Remove any existing entry with same ID
      pendingEntries.add(entry);
      final pendingJson = pendingEntries.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('${_pendingEntriesKey}_$profileId', pendingJson);
      
      developer.log('Saved offline entry and added to pending sync: ${entry.id}', name: 'OfflineDiaryService');
    } catch (e) {
      developer.log('Error saving offline entry: $e', name: 'OfflineDiaryService');
      rethrow;
    }
  }

  // Get all offline entries for a profile
  Future<List<DiaryEntry>> getOfflineEntries(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getStringList('${_offlineEntriesKey}_$profileId') ?? [];
      
      return entriesJson.map((json) {
        try {
          return DiaryEntry.fromJson(jsonDecode(json));
        } catch (e) {
          developer.log('Error parsing offline entry: $e', name: 'OfflineDiaryService');
          return null;
        }
      }).where((entry) => entry != null).cast<DiaryEntry>().toList();
    } catch (e) {
      developer.log('Error getting offline entries: $e', name: 'OfflineDiaryService');
      return [];
    }
  }

  // Get pending entries that need to be synced
  Future<List<DiaryEntry>> getPendingEntries(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getStringList('${_pendingEntriesKey}_$profileId') ?? [];
      
      return entriesJson.map((json) {
        try {
          return DiaryEntry.fromJson(jsonDecode(json));
        } catch (e) {
          developer.log('Error parsing pending entry: $e', name: 'OfflineDiaryService');
          return null;
        }
      }).where((entry) => entry != null).cast<DiaryEntry>().toList();
    } catch (e) {
      developer.log('Error getting pending entries: $e', name: 'OfflineDiaryService');
      return [];
    }
  }

  // Clear pending entries after successful sync
  Future<void> clearPendingEntries(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_pendingEntriesKey}_$profileId');
      developer.log('Cleared pending entries for profile: $profileId', name: 'OfflineDiaryService');
    } catch (e) {
      developer.log('Error clearing pending entries: $e', name: 'OfflineDiaryService');
      rethrow;
    }
  }

  // Delete an offline entry
  Future<void> deleteOfflineEntry(String profileId, DiaryEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing entries
      final offlineEntries = await getOfflineEntries(profileId);
      
      // Remove the entry by ID
      offlineEntries.removeWhere((e) => e.id == entry.id);
      
      // Save back to SharedPreferences
      final entriesJson = offlineEntries.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('${_offlineEntriesKey}_$profileId', entriesJson);
      
      // Also remove from pending entries if it exists
      final pendingEntries = await getPendingEntries(profileId);
      pendingEntries.removeWhere((e) => e.id == entry.id);
      final pendingJson = pendingEntries.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('${_pendingEntriesKey}_$profileId', pendingJson);
      
      developer.log('Deleted offline entry: ${entry.id}', name: 'OfflineDiaryService');
    } catch (e) {
      developer.log('Error deleting offline entry: $e', name: 'OfflineDiaryService');
      rethrow;
    }
  }
} 