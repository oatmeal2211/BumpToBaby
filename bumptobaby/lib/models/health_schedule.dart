class HealthScheduleItem {
  final String title;
  final String description;
  final DateTime scheduledDate;
  final String category; // 'checkup', 'vaccine', 'milestone', 'supplement'
  final bool isCompleted;

  HealthScheduleItem({
    required this.title,
    required this.description,
    required this.scheduledDate,
    required this.category,
    this.isCompleted = false,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'scheduledDate': scheduledDate.toIso8601String(),
      'category': category,
      'isCompleted': isCompleted,
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
    );
  }

  // Create a copy with updated fields
  HealthScheduleItem copyWith({
    String? title,
    String? description,
    DateTime? scheduledDate,
    String? category,
    bool? isCompleted,
  }) {
    return HealthScheduleItem(
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
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