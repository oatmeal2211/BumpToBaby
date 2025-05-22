import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a baby profile in the application
class BabyProfile {
  final String id;
  final String name;
  final DateTime? dateOfBirth; // null if it's a pregnancy profile
  final bool isPregnancy; // true for pregnancy, false for baby
  final DateTime? dueDate; // due date for pregnancy, null for baby
  final String? gender; // Can be 'male', 'female', or null for unknown/not shared
  final int points; // Points earned for this profile

  BabyProfile({
    required this.id,
    required this.name,
    this.dateOfBirth,
    required this.isPregnancy,
    this.dueDate,
    this.gender,
    this.points = 0, // Default to 0 points
  });

  // Create from Firestore document
  factory BabyProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return BabyProfile(
      id: doc.id,
      name: data['name'] ?? 'Unnamed',
      dateOfBirth: data['dateOfBirth'] != null 
          ? (data['dateOfBirth'] as Timestamp).toDate() 
          : null,
      isPregnancy: data['isPregnancy'] ?? true,
      dueDate: data['dueDate'] != null 
          ? (data['dueDate'] as Timestamp).toDate() 
          : null,
      gender: data['gender'],
      points: data['points'] as int? ?? 0, // Get points or default to 0
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'isPregnancy': isPregnancy,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'gender': gender,
      'points': points, // Include points in Firestore data
    };
  }

  // Convert to JSON for local storage if needed
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
      'isPregnancy': isPregnancy,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'gender': gender,
      'points': points, // Include points in JSON
    };
  }

  // Create from JSON for local storage if needed
  factory BabyProfile.fromJson(Map<String, dynamic> json) {
    return BabyProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      dateOfBirth: json['dateOfBirth'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['dateOfBirth'] as int) 
          : null,
      isPregnancy: json['isPregnancy'] as bool,
      dueDate: json['dueDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['dueDate'] as int) 
          : null,
      gender: json['gender'] as String?,
      points: json['points'] as int? ?? 0, // Get points from JSON or default to 0
    );
  }

  // Create a copy with updated fields
  BabyProfile copyWith({
    String? name,
    DateTime? dateOfBirth,
    bool? isPregnancy,
    DateTime? dueDate,
    String? gender,
    int? points,
  }) {
    return BabyProfile(
      id: this.id,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      isPregnancy: isPregnancy ?? this.isPregnancy,
      dueDate: dueDate ?? this.dueDate,
      gender: gender ?? this.gender,
      points: points ?? this.points,
    );
  }
} 