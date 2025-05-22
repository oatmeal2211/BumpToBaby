class HealthSurvey {
  final String userId;
  final bool isPregnant;
  final DateTime? dueDate;
  final DateTime? babyBirthDate;
  final String? babyGender;
  final double? babyWeight;
  final double? babyHeight;
  final List<String>? healthConditions;
  final List<String>? allergies;
  final List<String>? medications;
  final DateTime createdAt;
  final int? age;
  final String? location;
  final bool? prefersNaturalRemedies;
  final bool? isBreastfeeding;
  final String? dietaryPreference;

  HealthSurvey({
    required this.userId,
    required this.isPregnant,
    this.dueDate,
    this.babyBirthDate,
    this.babyGender,
    this.babyWeight,
    this.babyHeight,
    this.healthConditions,
    this.allergies,
    this.medications,
    required this.createdAt,
    this.age,
    this.location,
    this.prefersNaturalRemedies,
    this.isBreastfeeding,
    this.dietaryPreference,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isPregnant': isPregnant,
      'dueDate': dueDate?.toIso8601String(),
      'babyBirthDate': babyBirthDate?.toIso8601String(),
      'babyGender': babyGender,
      'babyWeight': babyWeight,
      'babyHeight': babyHeight,
      'healthConditions': healthConditions,
      'allergies': allergies,
      'medications': medications,
      'createdAt': createdAt.toIso8601String(),
      'age': age,
      'location': location,
      'prefersNaturalRemedies': prefersNaturalRemedies,
      'isBreastfeeding': isBreastfeeding,
      'dietaryPreference': dietaryPreference,
    };
  }

  // Create from JSON
  factory HealthSurvey.fromJson(Map<String, dynamic> json) {
    return HealthSurvey(
      userId: json['userId'],
      isPregnant: json['isPregnant'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      babyBirthDate: json['babyBirthDate'] != null ? DateTime.parse(json['babyBirthDate']) : null,
      babyGender: json['babyGender'],
      babyWeight: json['babyWeight'],
      babyHeight: json['babyHeight'],
      healthConditions: json['healthConditions'] != null
          ? List<String>.from(json['healthConditions'])
          : null,
      allergies: json['allergies'] != null
          ? List<String>.from(json['allergies'])
          : null,
      medications: json['medications'] != null
          ? List<String>.from(json['medications'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      age: json['age'],
      location: json['location'],
      prefersNaturalRemedies: json['prefersNaturalRemedies'],
      isBreastfeeding: json['isBreastfeeding'],
      dietaryPreference: json['dietaryPreference'],
    );
  }
} 