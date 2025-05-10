import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:bumptobaby/models/health_schedule.dart';
import 'package:bumptobaby/models/health_survey.dart';

class HealthScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save health survey to Firestore
  Future<void> saveHealthSurvey(HealthSurvey survey) async {
    try {
      await _firestore
          .collection('health_surveys')
          .doc(survey.userId)
          .collection('surveys')
          .add(survey.toJson());
    } catch (e) {
      if (kDebugMode) {
        print("Error saving health survey: $e");
      }
      throw Exception("Failed to save health survey: $e");
    }
  }

  // Save health schedule to Firestore
  Future<void> saveHealthSchedule(HealthSchedule schedule) async {
    try {
      await _firestore
          .collection('health_schedules')
          .doc(schedule.userId)
          .set({
        'generatedAt': schedule.generatedAt.toIso8601String(),
        'items': schedule.items.map((item) => item.toJson()).toList(),
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error saving health schedule: $e");
      }
      throw Exception("Failed to save health schedule: $e");
    }
  }

  // Get latest health schedule for a user
  Future<HealthSchedule?> getLatestHealthSchedule(String userId) async {
    try {
      final doc = await _firestore
          .collection('health_schedules')
          .doc(userId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data()!;
      return HealthSchedule(
        userId: userId,
        items: (data['items'] as List)
            .map((item) => HealthScheduleItem.fromJson(item))
            .toList(),
        generatedAt: DateTime.parse(data['generatedAt']),
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error getting health schedule: $e");
      }
      throw Exception("Failed to get health schedule: $e");
    }
  }

  // Update health schedule item (mark as completed)
  Future<void> updateScheduleItem(String userId, HealthScheduleItem updatedItem) async {
    try {
      // First get the current schedule
      final schedule = await getLatestHealthSchedule(userId);
      if (schedule == null) {
        throw Exception("No schedule found for user");
      }

      // Find and update the item
      final updatedItems = schedule.items.map((item) {
        if (item.title == updatedItem.title && 
            item.scheduledDate.isAtSameMomentAs(updatedItem.scheduledDate) &&
            item.category == updatedItem.category) {
          return updatedItem;
        }
        return item;
      }).toList();

      // Save the updated schedule
      final updatedSchedule = HealthSchedule(
        userId: userId,
        items: updatedItems,
        generatedAt: schedule.generatedAt,
      );

      await saveHealthSchedule(updatedSchedule);
    } catch (e) {
      if (kDebugMode) {
        print("Error updating schedule item: $e");
      }
      throw Exception("Failed to update schedule item: $e");
    }
  }
} 