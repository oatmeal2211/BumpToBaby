import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyPlanningData {
  final String userId;
  final String planningGoal; // "want_more_children", "no_more_children", "undecided"
  final List<String> contraceptiveMethodsUsed;
  final DateTime lastPeriodDate;
  final int cycleDuration; // Average cycle length in days
  final List<DateTime> periodDates; // History of period dates
  final List<DateTime> pillTakenDates; // Dates when pills were taken
  final List<DateTime> injectionDates; // Dates of contraceptive injections
  
  FamilyPlanningData({
    required this.userId,
    required this.planningGoal,
    this.contraceptiveMethodsUsed = const [],
    required this.lastPeriodDate,
    this.cycleDuration = 28,
    this.periodDates = const [],
    this.pillTakenDates = const [],
    this.injectionDates = const [],
  });
  
  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'planningGoal': planningGoal,
      'contraceptiveMethodsUsed': contraceptiveMethodsUsed,
      'lastPeriodDate': lastPeriodDate,
      'cycleDuration': cycleDuration,
      'periodDates': periodDates.map((date) => Timestamp.fromDate(date)).toList(),
      'pillTakenDates': pillTakenDates.map((date) => Timestamp.fromDate(date)).toList(),
      'injectionDates': injectionDates.map((date) => Timestamp.fromDate(date)).toList(),
    };
  }
  
  // Create from Firestore document
  factory FamilyPlanningData.fromMap(Map<String, dynamic> map) {
    return FamilyPlanningData(
      userId: map['userId'],
      planningGoal: map['planningGoal'],
      contraceptiveMethodsUsed: List<String>.from(map['contraceptiveMethodsUsed'] ?? []),
      lastPeriodDate: (map['lastPeriodDate'] as Timestamp).toDate(),
      cycleDuration: map['cycleDuration'] ?? 28,
      periodDates: (map['periodDates'] as List?)
          ?.map((timestamp) => (timestamp as Timestamp).toDate())
          .toList() ?? [],
      pillTakenDates: (map['pillTakenDates'] as List?)
          ?.map((timestamp) => (timestamp as Timestamp).toDate())
          .toList() ?? [],
      injectionDates: (map['injectionDates'] as List?)
          ?.map((timestamp) => (timestamp as Timestamp).toDate())
          .toList() ?? [],
    );
  }
} 