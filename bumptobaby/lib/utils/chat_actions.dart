import 'package:flutter/material.dart';
import 'package:bumptobaby/screens/nearest_clinic_screen.dart';

class ChatAction {
  final String label;
  final String route;
  final Map<String, dynamic>? arguments;
  final IconData? icon;

  ChatAction({
    required this.label,
    required this.route,
    this.arguments,
    this.icon,
  });

  factory ChatAction.fromJson(Map<String, dynamic> json) {
    return ChatAction(
      label: json['label'] as String,
      route: json['route'] as String,
      arguments: json['arguments'] as Map<String, dynamic>?,
      icon: json['icon'] != null ? IconData(json['icon'] as int, fontFamily: 'MaterialIcons') : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'route': route,
      if (arguments != null) 'arguments': arguments,
      if (icon != null) 'icon': icon!.codePoint,
    };
  }
}

class ChatActionHandler {
  static void handleAction(BuildContext context, ChatAction action) {
    try {
      // Check if this is a component route
      if (action.arguments?['useComponent'] == true) {
        if (action.arguments?['component'] == 'NearestClinicMapScreen') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NearestClinicMapScreen()),
          );
          return;
        }
      }

      // For other routes, use named routing
      if (ModalRoute.of(context)?.settings.name == action.route) {
        return;
      }

      Navigator.of(context).pushNamed(
        action.route,
        arguments: action.arguments,
      ).then((value) {
        // Handle navigation result if needed
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not navigate to ${action.label}'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Predefined actions with proper route names and icons
  static ChatAction growthTracker = ChatAction(
    label: "Open Growth Tracker",
    route: '/growth_development_screen',
    icon: Icons.trending_up,
    arguments: {'source': 'chatbot'},
  );

  static ChatAction nutritionGuide = ChatAction(
    label: "Open Nutrition Guide",
    route: '/nutrition_meals',
    icon: Icons.restaurant_menu,
    arguments: {'source': 'chatbot'},
  );

  static ChatAction healthTracker = ChatAction(
    label: "Open Health Tracker",
    route: '/smart_health_tracker',
    icon: Icons.favorite,
    arguments: {'source': 'chatbot'},
  );

  static ChatAction familyPlanning = ChatAction(
    label: "Open Family Planning",
    route: '/family_planning',
    icon: Icons.family_restroom,
    arguments: {'source': 'chatbot'},
  );

  static ChatAction nearestClinic = ChatAction(
    label: "Find Nearest Clinic",
    route: 'nearest_clinic_map_screen',
    icon: Icons.local_hospital,
    arguments: {
      'source': 'chatbot',
      'useComponent': true,  // Flag to indicate this should use component routing
      'component': 'NearestClinicMapScreen'
    },
  );

  static ChatAction community = ChatAction(
    label: "Join Community",
    route: '/community',
    icon: Icons.people,
    arguments: {'source': 'chatbot'},
  );

  static ChatAction audioVisualLearning = ChatAction(
    label: "Find Learning Resources",
    route: '/learning_resources',
    icon: Icons.play_circle_outline,
    arguments: {'source': 'chatbot'},
  );

  // Get all available actions
  static List<ChatAction> getAllActions() {
    return [
      growthTracker,
      nutritionGuide,
      healthTracker,
      familyPlanning,
      nearestClinic,
      community,
      audioVisualLearning,
    ];
  }

  // Find action by route
  static ChatAction? findActionByRoute(String route) {
    try {
      return getAllActions().firstWhere((action) => action.route == route);
    } catch (e) {
      return null;
    }
  }
} 