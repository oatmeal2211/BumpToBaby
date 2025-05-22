class HealthScheduleItem {
  final String title;
  final String description;
  final DateTime scheduledDate;
  final String category; // 'checkup', 'vaccine', 'milestone', 'supplement', 'risk_alert', 'prediction'
  final bool isCompleted;
  final String? severity; // 'low', 'medium', 'high' for risk alerts
  final Map<String, dynamic>? additionalData; // For storing extra information related to the item

  HealthScheduleItem({
    required this.title,
    required this.description,
    required this.scheduledDate,
    required this.category,
    this.isCompleted = false,
    this.severity,
    this.additionalData,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'scheduledDate': scheduledDate.toIso8601String(),
      'category': category,
      'isCompleted': isCompleted,
      'severity': severity,
      'additionalData': additionalData,
    };
  }

  // Create from JSON
  factory HealthScheduleItem.fromJson(Map<String, dynamic> json) {
    return HealthScheduleItem(
      title: json['title'],
      description: json['description'],
      scheduledDate: DateTime.parse(json['scheduledDate']),
      category: json['category'],
      isCompleted: json['isCompleted'] ?? false,
      severity: json['severity'],
      additionalData: json['additionalData'],
    );
  }

  // Create a copy with updated fields
  HealthScheduleItem copyWith({
    String? title,
    String? description,
    DateTime? scheduledDate,
    String? category,
    bool? isCompleted,
    String? severity,
    Map<String, dynamic>? additionalData,
  }) {
    return HealthScheduleItem(
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      severity: severity ?? this.severity,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}

class HealthSchedule {
  final String userId;
  final List<HealthScheduleItem> items;
  final DateTime generatedAt;

  HealthSchedule({
    required this.userId,
    required this.items,
    required this.generatedAt,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory HealthSchedule.fromJson(Map<String, dynamic> json) {
    return HealthSchedule(
      userId: json['userId'],
      items: (json['items'] as List)
          .map((item) => HealthScheduleItem.fromJson(item))
          .toList(),
      generatedAt: DateTime.parse(json['generatedAt']),
    );
  }
} 