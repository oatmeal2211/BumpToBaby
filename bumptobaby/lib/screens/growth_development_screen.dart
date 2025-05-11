import 'dart:io'; // For File operations
import 'dart:convert'; // For jsonEncode (if sending complex data to a backend)
import 'dart:developer' as developer; // For logging

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; // For Image Picker
import 'package:intl/intl.dart'; // Added for date formatting
import 'package:table_calendar/table_calendar.dart'; // Added for TableCalendar
import 'package:fl_chart/fl_chart.dart'; // Add this import at the top
// Import for Gemini API
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart'; // For data persistence

// Load the API key from the environment
final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? "YOUR_API_KEY_HERE"; // Fallback if not found

// Enum to represent the selected mode
enum GrowthScreenMode { pregnancy, baby }

// Enum for fetal size units
enum FetalSizeUnit { cm, inch }

// New Enum for general length units (for baby height)
enum LengthUnit { cm, inch }

// New Enum for weight units (for baby weight)
enum WeightUnit { kg, lb }

// Data class for User Profile
class UserProfile {
  String id;
  String name;
  // In future stages, profile-specific data like diary entries, mode, score etc. will be here

  UserProfile({required this.id, required this.name});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'],
    name: json['name'],
  );
}

// Data class for Diary Entry
class DiaryEntry {
  final DateTime date;
  final String? imagePath;
  final String title;       // New field
  final String description; // New field

  // Pregnancy-specific fields (nullable)
  final String? cravings;
  final String? mood;
  final double? fetalSize; 
  final FetalSizeUnit? fetalSizeUnit; 
  final String? pregnancyStage;

  // Baby-specific fields (nullable)
  final double? height;
  final LengthUnit? heightUnit;
  final double? weight;
  final WeightUnit? weightUnit;

  DiaryEntry({
    required this.date,
    this.imagePath,
    required this.title,
    required this.description,
    // Pregnancy fields
    this.cravings,
    this.mood,
    this.fetalSize,
    this.fetalSizeUnit,
    this.pregnancyStage,
    // Baby fields
    this.height,
    this.heightUnit,
    this.weight,
    this.weightUnit,
  });

  // Helper method to get fetal size with unit as string
  String? get fetalSizeDisplay {
    if (fetalSize == null || fetalSizeUnit == null) return null;
    String unitStr = fetalSizeUnit == FetalSizeUnit.cm ? 'cm' : 'inch';
    return '$fetalSize $unitStr';
  }

  // Helper method to get height with unit as string
  String? get heightDisplay {
    if (height == null || heightUnit == null) return null;
    String unitStr = heightUnit == LengthUnit.cm ? 'cm' : 'inch';
    return '$height $unitStr';
  }

  // Helper method to get weight with unit as string
  String? get weightDisplay {
    if (weight == null || weightUnit == null) return null;
    String unitStr = weightUnit == WeightUnit.kg ? 'kg' : 'lb';
    return '$weight $unitStr';
  }
  
  // Convert DiaryEntry to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'date': date.millisecondsSinceEpoch,
      'imagePath': imagePath,
      'title': title,
      'description': description,
      // Pregnancy fields
      'cravings': cravings,
      'mood': mood,
      'fetalSize': fetalSize,
      'fetalSizeUnit': fetalSizeUnit?.index,
      'pregnancyStage': pregnancyStage,
      // Baby fields
      'height': height,
      'heightUnit': heightUnit?.index,
      'weight': weight,
      'weightUnit': weightUnit?.index,
    };
  }

  // Create DiaryEntry from JSON data
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
      imagePath: json['imagePath'] as String?,
      title: (json['title'] as String?) ?? '', // Ensure title is non-null
      description: (json['description'] as String?) ?? '', // Ensure description is non-null
      // Pregnancy fields
      cravings: json['cravings'] as String?,
      mood: json['mood'] as String?,
      fetalSize: json['fetalSize'] as double?,
      fetalSizeUnit: json['fetalSizeUnit'] != null ? FetalSizeUnit.values[json['fetalSizeUnit'] as int] : null,
      pregnancyStage: json['pregnancyStage'] as String?,
      // Baby fields
      height: json['height'] as double?,
      heightUnit: json['heightUnit'] != null ? LengthUnit.values[json['heightUnit'] as int] : null,
      weight: json['weight'] as double?,
      weightUnit: json['weightUnit'] != null ? WeightUnit.values[json['weightUnit'] as int] : null,
    );
  }
}

class GrowthDevelopmentScreen extends StatefulWidget {
  const GrowthDevelopmentScreen({Key? key}) : super(key: key);

  @override
  State<GrowthDevelopmentScreen> createState() => _GrowthDevelopmentScreenState();
}

class _GrowthDevelopmentScreenState extends State<GrowthDevelopmentScreen> with TickerProviderStateMixin { // Add TickerProviderStateMixin
  GrowthScreenMode _selectedMode = GrowthScreenMode.pregnancy; // Default to Pregnancy
  DateTime _selectedDiaryDate = DateTime.now();
  final List<DiaryEntry> _allDiaryEntries = []; // Stores all diary entries
  bool _isCalendarExpanded = false; // State for calendar view

  // State for AI Insights
  String? _aiInsightText;
  bool _isFetchingAiInsights = false;

  // For data persistence
  bool _isLoading = true;
  int _userScore = 0; // User's score for gamification

  // Profile-related state
  List<UserProfile> _profiles = [];
  String? _currentProfileId; // Nullable to handle cases where no profile exists yet

  // TabControllers for managing tab states and listeners
  TabController? _pregnancyTabController;
  TabController? _babyTrackerTabController;

  @override
  void initState() {
    super.initState();
    _selectedDiaryDate = DateTime(_selectedDiaryDate.year, _selectedDiaryDate.month, _selectedDiaryDate.day); // Normalize to midnight
    
    // Initialize TabControllers
    _pregnancyTabController = TabController(length: 2, vsync: this); // 2 tabs for pregnancy
    _babyTrackerTabController = TabController(length: 2, vsync: this); // 2 tabs for baby tracker

    // Add listeners to TabControllers
    _pregnancyTabController?.addListener(_handlePregnancyTabSelection);
    _babyTrackerTabController?.addListener(_handleBabyTrackerTabSelection);
    
    _loadSavedData(); // This might trigger an initial fetch if the default tab is 0
  }

  @override
  void dispose() {
    _pregnancyTabController?.removeListener(_handlePregnancyTabSelection);
    _babyTrackerTabController?.removeListener(_handleBabyTrackerTabSelection);
    _pregnancyTabController?.dispose();
    _babyTrackerTabController?.dispose();
    _saveData(); // Save data when the screen is disposed
    super.dispose();
  }

  // Handler for pregnancy tab selection
  void _handlePregnancyTabSelection() {
    if (_pregnancyTabController != null && 
        _pregnancyTabController!.indexIsChanging == false && // Ensure it's a confirmed change
        _pregnancyTabController!.index == 0 && // 0 is Fetal Growth tab
        _selectedMode == GrowthScreenMode.pregnancy) { 
      if (!_isFetchingAiInsights) {
        _fetchAndSetAiInsights();
      }
    }
  }

  // Handler for baby tracker tab selection
  void _handleBabyTrackerTabSelection() {
    if (_babyTrackerTabController != null &&
        _babyTrackerTabController!.indexIsChanging == false && // Ensure it's a confirmed change
        _babyTrackerTabController!.index == 0 && // 0 is Baby Growth tab
        _selectedMode == GrowthScreenMode.baby) {
      if (!_isFetchingAiInsights) {
        _fetchAndSetAiInsights();
      }
    }
  }

  // Handle profile deletion with proper state management
  Future<void> _deleteProfileAndData(UserProfile profile) async {
    // Don't allow deleting the last profile
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot delete the only profile')),
      );
      return;
    }

    // Create a new list without the profile to delete
    final newProfiles = _profiles.where((p) => p.id != profile.id).toList();
    
    // If we're deleting the current profile, switch to another one
    bool needsProfileSwitch = profile.id == _currentProfileId;
    // Ensure we're using a non-null value for newCurrentId
    String newCurrentId = needsProfileSwitch 
        ? newProfiles.first.id 
        : (_currentProfileId ?? newProfiles.first.id);

    // Update profiles list and current ID if needed
    setState(() {
      _profiles = newProfiles;
      if (needsProfileSwitch) {
        _currentProfileId = newCurrentId;
        _isLoading = true; // Will load data for the new profile
      }
    });

    // Delete the profile's data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    // Remove profile-specific data
    await prefs.remove('diary_entries_${profile.id}');
    await prefs.remove('fetal_measurements_${profile.id}');
    
    // Save the updated profiles list
    await _saveData();
    
    // If we switched profiles, load the new profile's data
    if (needsProfileSwitch) {
      await _loadSavedData();
    }

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.name} profile deleted')),
      );
    }
  }

  // Show confirmation dialog before deleting
  void _showDeleteProfileConfirmationDialog(UserProfile profile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Profile',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${profile.name}"? This will remove all data associated with this profile and cannot be undone.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProfileAndData(profile);
              },
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // Load saved preferences and diary entries
  Future<void> _loadSavedData() async {
    setState(() { _isLoading = true; });
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load all profiles first
      final profilesJsonList = prefs.getStringList('profiles') ?? [];
      _profiles = profilesJsonList.map((jsonStr) => UserProfile.fromJson(json.decode(jsonStr))).toList();
      _currentProfileId = prefs.getString('current_profile_id');

      // Create default profile if none exists
      if (_profiles.isEmpty) {
        final defaultProfile = UserProfile(id: DateTime.now().millisecondsSinceEpoch.toString(), name: 'My First Profile');
        _profiles.add(defaultProfile);
        _currentProfileId = defaultProfile.id;
      } 
      // Set current profile to first if current ID doesn't exist
      else if (_currentProfileId == null || !_profiles.any((p) => p.id == _currentProfileId)) {
        _currentProfileId = _profiles.first.id;
      }
      
      // Load profile-specific data
      if (_currentProfileId != null) {
        // Load mode (pregnancy/baby)
        final profileSpecificModeIndex = prefs.getInt('selected_mode_$_currentProfileId') ?? GrowthScreenMode.pregnancy.index;
        _selectedMode = GrowthScreenMode.values[profileSpecificModeIndex];
        
        // Load calendar state
        _isCalendarExpanded = prefs.getBool('calendar_expanded_$_currentProfileId') ?? false;
        
        // Load diary entries
        _allDiaryEntries.clear(); // Clear any existing entries first
        final profileEntriesJsonList = prefs.getStringList('diary_entries_$_currentProfileId') ?? [];
        if (profileEntriesJsonList.isNotEmpty) {
          _allDiaryEntries.addAll(profileEntriesJsonList.map((jsonStr) => DiaryEntry.fromJson(json.decode(jsonStr))).toList());
        } else {
          // Add sample entries only for new profiles
          _addSampleEntries();
        }
      } else {
        // Fallback defaults
        _selectedMode = GrowthScreenMode.pregnancy;
        _isCalendarExpanded = false;
        _allDiaryEntries.clear();
      }
      
      // Load global user score
      _userScore = prefs.getInt('user_score') ?? 0;
      
      // Update UI
      if (mounted) {
        setState(() { _isLoading = false; });
      }
      
      // Fetch AI insights based on the loaded data
      _fetchAndSetAiInsights();
      
      developer.log('Loaded data for profile: $_currentProfileId with ${_allDiaryEntries.length} entries', name: 'GrowthDevelopmentScreen');
    } catch (e) {
      developer.log('Error loading saved data: $e', name: 'GrowthDevelopmentScreen');
      // Recovery handling
      if (_profiles.isEmpty) {
        final defaultProfile = UserProfile(id: DateTime.now().millisecondsSinceEpoch.toString(), name: 'My First Profile');
        _profiles.add(defaultProfile);
        _currentProfileId = defaultProfile.id;
      }
      _selectedMode = GrowthScreenMode.pregnancy;
      _isCalendarExpanded = false;
      _allDiaryEntries.clear();
      if (_allDiaryEntries.isEmpty) { _addSampleEntries(); } 
      
      if (mounted) {
        setState(() { _isLoading = false; });
      }
      _fetchAndSetAiInsights();
    }
  }

  // Save current preferences and diary entries
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save all profiles
      final profilesJsonList = _profiles.map((p) => json.encode(p.toJson())).toList();
      await prefs.setStringList('profiles', profilesJsonList);
      
      // Save current profile ID selection
      if (_currentProfileId != null) {
        await prefs.setString('current_profile_id', _currentProfileId!);

        // Save profile-specific data
        await prefs.setInt('selected_mode_$_currentProfileId', _selectedMode.index);
        await prefs.setBool('calendar_expanded_$_currentProfileId', _isCalendarExpanded);
        
        // Save diary entries for this profile
        final entriesJsonList = _allDiaryEntries.map((entry) => json.encode(entry.toJson())).toList();
        await prefs.setStringList('diary_entries_$_currentProfileId', entriesJsonList);
        
        developer.log('Saved ${_allDiaryEntries.length} entries for profile: $_currentProfileId', name: 'GrowthDevelopmentScreen');
      }
      
      // Save global user score
      await prefs.setInt('user_score', _userScore);
    } catch (e) {
      developer.log('Error saving data: $e', name: 'GrowthDevelopmentScreen');
    }
  }

  // Add sample entries for the current profile
  void _addSampleEntries() {
    // Clear entries first to ensure we're starting fresh
    _allDiaryEntries.clear();
    
    // Get the current profile name for personalized samples
    String profileName = "this profile";
    if (_currentProfileId != null) {
      UserProfile? profile = _profiles.firstWhere(
        (p) => p.id == _currentProfileId,
        orElse: () => UserProfile(id: "default", name: "this profile")
      );
      profileName = profile.name;
    }
    
    // Add sample entries with references to the profile name
    _allDiaryEntries.addAll([
      DiaryEntry(
        date: DateTime.now().subtract(const Duration(days: 30)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
        title: "First check-up for $profileName! Excited to start tracking.",
        description: "None yet",
        mood: "Excited",
        fetalSize: 2.5,
        fetalSizeUnit: FetalSizeUnit.cm,
        pregnancyStage: "Week 8",
      ),
      DiaryEntry(
        date: DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
        title: "Feeling good with $profileName today. Had my regular check-up.",
        description: "Apples",
        mood: "Happy",
        fetalSize: 10.0,
        fetalSizeUnit: FetalSizeUnit.cm,
        pregnancyStage: "Week 16",
      ),
    ]);
    
    developer.log("Added sample entries for profile: $_currentProfileId", name: "GrowthDevelopmentScreen");
  }

  Future<void> _fetchAndSetAiInsights() async {
    if (_geminiApiKey == "YOUR_API_KEY_HERE") {
      if (mounted) {
        setState(() {
          _aiInsightText =
              "Please configure your Gemini API Key in environment variables to get AI insights.";
          _isFetchingAiInsights = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isFetchingAiInsights = true;
        _aiInsightText = null; // Clear previous insight
      });
    }

    try {
      // 1. Gather data (common part)
      final sortedEntries = List<DiaryEntry>.from(_allDiaryEntries);
      if (sortedEntries.isEmpty) {
        if (mounted) {
          setState(() {
            _aiInsightText = "Add diary entries to receive personalized insights.";
            _isFetchingAiInsights = false;
          });
        }
        return;
      }
      sortedEntries.sort((a, b) => a.date.compareTo(b.date));

      String prompt;

      if (_selectedMode == GrowthScreenMode.pregnancy) {
        // --- Pregnancy Mode Prompt --- 
        final latestEntry = sortedEntries.isNotEmpty ? sortedEntries.last : null;
        final currentWeekStage = latestEntry?.pregnancyStage ?? "Week 12"; // Default
        final currentTrimester = _getTrimesterFromWeek(currentWeekStage);

        List<String> formattedGrowthData = sortedEntries
            .where((entry) => entry.fetalSize != null)
            .map((entry) {
          return "${DateFormat('yyyy-MM-dd').format(entry.date)}: ${entry.fetalSizeDisplay}, Mood: ${entry.mood ?? 'N/A'}, Cravings: ${entry.cravings ?? 'N/A'}, Journal: ${entry.description.substring(0, entry.description.length > 50 ? 50 : entry.description.length)}${entry.description.length > 50 ? "..." : ""}";
        }).toList();

        prompt = """
        You are an AI assistant for a pregnancy tracking app.
        The user is currently in: $currentWeekStage ($currentTrimester).

        Here is their recent fetal growth and diary data (date, fetal size, mood, cravings, journal snippet):
        ${formattedGrowthData.join('\n')}

        Based on this information, provide a short (1-2 sentences), encouraging, and relevant insight or piece of advice for the user related to their current stage or observed growth pattern.
        Focus on positive and general advice. Please alert if there is abnormal growth or development based on the data especially fetal size.
        Avoid making medical diagnoses or specific medical recommendations. Be empathetic and supportive.
        If there's not enough data or the data seems unusual for making a specific insight, provide a general encouraging message for their current pregnancy stage.
        Example Insight: "It's great that you're tracking your journey in $currentWeekStage! Remember to stay hydrated and listen to your body."
        Another Example: "Seeing your progress is wonderful! Many experience [common symptom for $currentWeekStage] around this time, so gentle walks can be beneficial if you're feeling up to it."
        """;
      } else { // GrowthScreenMode.baby
        // --- Baby Mode Prompt ---
        List<String> formattedBabyData = sortedEntries
            .where((entry) => entry.height != null || entry.weight != null)
            .map((entry) {
              String data = DateFormat('yyyy-MM-dd').format(entry.date);
              if (entry.height != null) data += ", Height: ${entry.heightDisplay}";
              if (entry.weight != null) data += ", Weight: ${entry.weightDisplay}";
              data += ", Notes: ${entry.description.substring(0, entry.description.length > 50 ? 50 : entry.description.length)}${entry.description.length > 50 ? "..." : ""}";
              return data;
        }).toList();

        // We need a way to get baby's age for better insights. For now, we'll omit it or use a generic reference.
        // String babyAgeReference = "your baby"; // Or derive from diary entries if possible

        prompt = """
        You are an AI assistant for a baby tracking app.
        Here is the baby's recent growth data (date, height, weight, notes):
        ${formattedBabyData.join('\n')}

        Based on this information, provide a short (1-2 sentences), encouraging, and relevant insight about the baby's growth and development.
        Consider patterns in height and weight. Offer general tips or positive affirmations. 
        For example, if growth is steady, you can praise the tracking. If there are fluctuations, suggest general factors like growth spurts or feeding changes, but always advise consulting a pediatrician for concerns.
        Avoid making medical diagnoses or specific medical recommendations. Be empathetic, supportive, and focus on general well-being. Tell some nutrition tips based on height, weight and date data.
        If data is sparse, provide a general encouraging message about tracking baby's development.
        Example Insight: "It's wonderful to see you tracking your baby's growth! Consistent tracking helps you observe their unique development journey."
        Another Example (if data shows growth): "Your baby is growing steadily! Remember that every baby develops at their own pace. Keep up the great work with feeding and care."
        """;
      }

      // 3. Call Gemini API (common part)
      final model = genai.GenerativeModel(
        model: 'gemini-1.5-flash-latest', // Using the latest flash model
        apiKey: _geminiApiKey,
      );

      final content = [genai.Content.text(prompt)];
      try {
        final response = await model.generateContent(content);

        if (mounted) {
          setState(() {
            _aiInsightText = response.text;
            _isFetchingAiInsights = false;
          });
        }
      } catch (apiError) {
        developer.log('Gemini API error: $apiError', name: 'GrowthDevelopmentScreen');
        if (mounted) {
          setState(() {
            _aiInsightText =
                "Unable to fetch personalized insights at this time. Please try again later.";
            _isFetchingAiInsights = false;
          });
        }
      }
    } catch (e) {
      developer.log('Error in _fetchAndSetAiInsights: $e', name: 'GrowthDevelopmentScreen');
      if (mounted) {
        setState(() {
          _aiInsightText =
              "Could not fetch AI insights at this time. Please try again later.";
          _isFetchingAiInsights = false;
        });
      }
    }
  }

  // Helper function to determine trimester from week
  String _getTrimesterFromWeek(String weekStage) {
    if (!weekStage.startsWith("Week ")) {
      return "Unknown Trimester"; // Should not happen with new dropdown
    }
    try {
      final weekNumber = int.parse(weekStage.replaceAll("Week ", ""));
      if (weekNumber >= 1 && weekNumber <= 12) {
        return "First Trimester";
      } else if (weekNumber >= 13 && weekNumber <= 26) {
        return "Second Trimester";
      } else if (weekNumber >= 27 && weekNumber <= 42) { // Adjusted to 42 weeks
        return "Third Trimester";
      } else {
        return "Unknown Trimester";
      }
    } catch (e) {
      return "Unknown Trimester";
    }
  }

  // New widget to display the score in a capsule
  Widget _buildScoreDisplay() {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0), // Add some padding
      child: Chip(
        avatar: Icon(Icons.star, color: Colors.amber, size: 18),
        label: Text(
          '$_userScore',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Color(0xFF78A0E5), // Theme color
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  // Dialog to add a new profile
  Future<void> _showAddProfileDialog() async {
    final TextEditingController nameController = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Add New Profile', style: GoogleFonts.poppins()),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'E.g., Baby Leo, Pregnancy 2',
              labelStyle: GoogleFonts.poppins(),
            ),
            autofocus: true,
            style: GoogleFonts.poppins(),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins()),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text('Add', style: GoogleFonts.poppins()),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final newProfile = UserProfile(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                  );
                  setState(() {
                    _profiles.add(newProfile);
                    _currentProfileId = newProfile.id; // Switch to the new profile
                    
                    // Initialize data for the new profile
                    _selectedMode = GrowthScreenMode.pregnancy; // Default mode
                    _isCalendarExpanded = false; // Default calendar state
                    _allDiaryEntries.clear(); // Clear any existing (global/previous profile) entries from state
                    _addSampleEntries(); // Add sample entries for the new profile
                    
                    // AI insights will be fetched by _loadSavedData or explicitly after this
                  });
                  _saveData(); // Save the new profile list, current ID, and its initial data
                  _fetchAndSetAiInsights(); // Fetch insights for the new profile immediately
                  Navigator.of(dialogContext).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Profile name cannot be empty.', style: GoogleFonts.poppins())),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Method to show the points gained dialog
  Future<void> _showPointsGainedDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // User can tap outside to dismiss
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          elevation: 5,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(child: child, scale: animation);
                  },
                  child: Text(
                    '🎉 +10 ⭐',
                    key: ValueKey<int>(DateTime.now().millisecondsSinceEpoch), // Unique key to trigger animation
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[700],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'Entry Saved!',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You've earned 10 points!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78A0E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text('Awesome!', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Dismiss dialog
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goToPreviousWeek() {
    setState(() {
      _selectedDiaryDate = _selectedDiaryDate.subtract(const Duration(days: 7));
      // Ensure the date is normalized to midnight to match entries
      _selectedDiaryDate = DateTime(_selectedDiaryDate.year, _selectedDiaryDate.month, _selectedDiaryDate.day);
    });
  }

  void _goToNextWeek() {
    setState(() {
      _selectedDiaryDate = _selectedDiaryDate.add(const Duration(days: 7));
      _selectedDiaryDate = DateTime(_selectedDiaryDate.year, _selectedDiaryDate.month, _selectedDiaryDate.day);
    });
  }

  void _goToPreviousMonth() {
    setState(() {
      final newDate = DateTime(_selectedDiaryDate.year, _selectedDiaryDate.month - 1, _selectedDiaryDate.day);
      final daysInNewMonth = DateTime(newDate.year, newDate.month + 1, 0).day;
      _selectedDiaryDate = DateTime(newDate.year, newDate.month, newDate.day > daysInNewMonth ? daysInNewMonth : newDate.day);
    });
  }

  void _goToNextMonth() {
    setState(() {
      final newDate = DateTime(_selectedDiaryDate.year, _selectedDiaryDate.month + 1, _selectedDiaryDate.day);
      final daysInNewMonth = DateTime(newDate.year, newDate.month + 1, 0).day;
      _selectedDiaryDate = DateTime(newDate.year, newDate.month, newDate.day > daysInNewMonth ? daysInNewMonth : newDate.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    developer.log("Building GrowthScreen. Profiles: ${_profiles.length}, CurrentID: $_currentProfileId, IsLoading: $_isLoading", name: "GrowthScreenBuild");
    // Safely get the current profile, providing a fallback if needed.
    UserProfile currentProfile = _profiles.firstWhere(
      (p) => p.id == _currentProfileId,
      orElse: () => _profiles.isNotEmpty 
                   ? _profiles.first 
                   : UserProfile(id: "default_fallback", name: "Profile"), // Fallback
    );

    // If current profile ID doesn't exist in the profiles list, correct it
    if (_currentProfileId == null || 
        (_profiles.isNotEmpty && !_profiles.any((p) => p.id == _currentProfileId))) {
      // Safely update to a valid profile
      _currentProfileId = _profiles.isNotEmpty ? _profiles.first.id : "default";
      _saveData(); // Persist this correction
    }

    List<DropdownMenuItem<String>> profileDropdownItems = _profiles.map((profile) {
      return DropdownMenuItem<String>(
        value: profile.id,
        child: Row(
          children: [
            Icon(Icons.child_care_outlined, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                profile.name,
                style: GoogleFonts.poppins(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();

    // Separate menu item for adding new profile
    profileDropdownItems.add(
      DropdownMenuItem<String>(
        value: '__add_new__',
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 18, color: Theme.of(context).primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Add New Profile...',
                style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).primaryColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Growth & Development',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFFAFC9F8),
        actions: [
          // Profile Dropdown - Enhanced UI
          if (_profiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2.0), // Minimal vertical padding
              child: Container(
                constraints: const BoxConstraints(maxWidth: 150, maxHeight: 40), // Increased height
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0), // Minimal horizontal padding
                decoration: BoxDecoration(
                  color: Color(0xFF78A0E5).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center, // Center the content
                  children: [
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isDense: true, // This makes the dropdown more compact
                          isExpanded: true,
                          value: _currentProfileId,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                          selectedItemBuilder: (BuildContext context) {
                            return _profiles.map<Widget>((UserProfile profile) {
                              if (profile.id == _currentProfileId) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(4.0), // Added padding around the icon
                                      child: Icon(Icons.child_care, color: Colors.white, size: 14),
                                    ),
                                    Flexible(
                                      child: Text(
                                        profile.name, 
                                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            }).toList();
                          },
                          items: profileDropdownItems,
                          onChanged: (String? selectedValue) {
                            // Important: First check if we need to add new profile
                            if (selectedValue == '__add_new__') {
                              _showAddProfileDialog();
                              return; // Exit early after showing dialog
                            } 
                            
                            // Handle profile switching
                            if (selectedValue != null && selectedValue != _currentProfileId) {
                              final String newProfileIdToLoad = selectedValue;
                              // _currentProfileId currently holds the ID of the profile whose data is loaded.

                              setState(() { 
                                _isLoading = true; // Show loading indicator immediately
                              });

                              // 1. Save the data for the currently active profile (_currentProfileId).
                              //    _saveData() saves _allDiaryEntries and settings using the current _currentProfileId.
                              //    It ALSO saves this _currentProfileId as 'current_profile_id' in prefs for now.
                              _saveData().then((_) {
                                // Data for the *old* profile is now saved.
                                // 'current_profile_id' in prefs temporarily points to the *old* profile.

                                if (mounted) {
                                  // 2. Update the application's current profile ID state.
                                  setState(() {
                                    _currentProfileId = newProfileIdToLoad;
                                    // At this point, _allDiaryEntries and other settings in memory might still be for the old profile,
                                    // but _currentProfileId is now for the new one.
                                  });

                                  // 3. Persist the NEW profile ID as the "current" one in SharedPreferences.
                                  //    This OVERWRITES the 'current_profile_id' set by the previous _saveData() call.
                                  SharedPreferences.getInstance().then((prefs) {
                                    prefs.setString('current_profile_id', newProfileIdToLoad).then((_) {
                                      if (mounted) {
                                        // 4. Load the data for the new profile.
                                        //    _loadSavedData will read the 'current_profile_id' we just set (newProfileIdToLoad),
                                        //    and then load the corresponding diary entries and settings.
                                        _loadSavedData(); // This will eventually set _isLoading = false and refresh UI.
                                      }
                                    });
                                  });
                                }
                              });
                            }
                          },
                          dropdownColor: Colors.white,
                        ),
                      ),
                    ),
                    if (_profiles.length > 1) // Only show delete if more than one profile
                      Container(
                        width: 28, // Fixed width for the delete button area
                        child: IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: Colors.white.withOpacity(0.8)),
                          padding: EdgeInsets.symmetric(horizontal: 0), // No horizontal padding
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24), // Minimal size
                          tooltip: 'Delete profile',
                          onPressed: () {
                            _showDeleteProfileConfirmationDialog(currentProfile);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 4),
          _buildScoreDisplay(),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Top Toggle
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ToggleButtons(
              isSelected: [
                _selectedMode == GrowthScreenMode.pregnancy,
                _selectedMode == GrowthScreenMode.baby,
              ],
              onPressed: (int index) {
                setState(() {
                  _selectedMode = index == 0 ? GrowthScreenMode.pregnancy : GrowthScreenMode.baby;
                  // Save user preference
                  _saveData();
                });
              },
              borderRadius: BorderRadius.circular(8.0),
              selectedBorderColor: Color(0xFF78A0E5),
              selectedColor: Colors.white,
              fillColor: Color(0xFF78A0E5),
              color: Color(0xFF78A0E5),
              constraints: BoxConstraints(
                minHeight: 40.0,
                minWidth: (MediaQuery.of(context).size.width - 48) / 2, // Adjust width based on screen
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('🤰 Pregnancy', style: GoogleFonts.poppins()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('👶 Baby Tracker', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ),
          // Dynamically updated content based on selection
          Expanded(
            child: _selectedMode == GrowthScreenMode.pregnancy
                ? _buildPregnancyModeContent()
                : _buildBabyTrackerModeContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPregnancyModeContent() {
    // return DefaultTabController( // Replaced with explicit controller
    //   length: 2, 
    //   child: Column(
    return Column(
      children: [
        TabBar(
          controller: _pregnancyTabController, // Use the explicit controller
          labelColor: const Color(0xFF78A0E5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF78A0E5),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          indicator: BoxDecoration(
            color: Colors.transparent, 
            border: Border(
              bottom: BorderSide(color: const Color(0xFF78A0E5), width: 2), 
            ),
          ),
          tabs: const [
            Tab(text: 'Fetal Growth'),
            Tab(text: 'Bump Diary'), 
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _pregnancyTabController, // Use the explicit controller
            children: [
              _buildFetalGrowthSection(),
              _buildBumpDiarySection(),
            ],
          ),
        ),
      ],
    );
    //   ),
    // );
  }

  Widget _buildBabyTrackerModeContent() {
    // return DefaultTabController( // Replaced with explicit controller
    //   length: 2, 
    //   child: Column(
    return Column(
      children: [
        TabBar(
          controller: _babyTrackerTabController, // Use the explicit controller
          labelColor: const Color(0xFF78A0E5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF78A0E5),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          indicator: BoxDecoration(
            color: Colors.transparent, 
            border: Border(
              bottom: BorderSide(color: const Color(0xFF78A0E5), width: 2), 
            ),
          ),
          tabs: const [
            Tab(text: 'Baby Growth'), 
            Tab(text: 'Growth Diary'), 
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _babyTrackerTabController, // Use the explicit controller
            children: [
              _buildBabyGrowthChartsSection(),
              _buildBumpDiarySection(),   
            ],
          ),
        ),
      ],
    );
    //   ),
    // );
  }

  Widget _buildFetalGrowthSection() {
    // Sort entries by date for the chart
    final sortedEntries = List<DiaryEntry>.from(_allDiaryEntries);
    sortedEntries.sort((a, b) => a.date.compareTo(b.date));
    
    // Get latest entry for pregnancy stage info
    final latestEntry = sortedEntries.isNotEmpty ? sortedEntries.last : null;
    final currentWeekStage = latestEntry?.pregnancyStage ?? "Week 12"; // Default to a week
    final currentTrimester = _getTrimesterFromWeek(currentWeekStage);
    
    String weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester)";
    String weeklyDevelopmentContent = "Detailed information for this week is being updated. Check back soon!"; // Default content
    int? weekNumber;

    try {
      final match = RegExp(r'Week (\d+)').firstMatch(currentWeekStage);
      if (match != null) {
        weekNumber = int.parse(match.group(1)!);
      }
    } catch (e) {
      weekNumber = null; // Should not happen if currentWeekStage is always "Week X"
    }
      
    if (weekNumber != null) {
      // Update title with fruit/veg comparison and set content based on week
      switch (weekNumber) {
          case 1:
          case 2:
          case 3:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Microscopic 🔬";
            weeklyDevelopmentContent = "Fertilization is happening. The fertilized egg is dividing and growing as it travels to the uterus for implantation.";
            break;
          case 4:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Poppy Seed 🌱";
            weeklyDevelopmentContent = "The embryo is forming the amniotic sac and yolk sac, which will provide nutrients.";
            break;
          case 5:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Sesame Seed 🌱";
            weeklyDevelopmentContent = "The embryo's heart and circulatory system are forming.";
            break;
          case 6:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Lentil 🌰";
            weeklyDevelopmentContent = "Facial features begin to form including eyes, nose, jaw, and cheeks.";
            break;
          case 7:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Blueberry 🫐";
            weeklyDevelopmentContent = "The embryo's brain is developing rapidly, and limbs are growing longer.";
            break;
          case 8:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Kidney Bean 🫘";
            weeklyDevelopmentContent = "All essential organs have begun to develop. The baby's tail is disappearing.";
            break;
          case 9:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Grape 🍇";
            weeklyDevelopmentContent = "The baby is now officially a fetus. Tiny toes and fingers are forming.";
            break;
          case 10:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Kumquat 🍊";
            weeklyDevelopmentContent = "The baby's vital organs are now functioning, and tooth buds are developing.";
            break;
          case 11:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Fig 🍒";
            weeklyDevelopmentContent = "The baby is moving around, though you can't feel it yet.";
            break;
          case 12:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Lime 🍋";
            weeklyDevelopmentContent = "The baby's reflexes are developing, and they can now open and close their fingers.";
            break;
          // Second Trimester starts here for content grouping
          case 13:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Pea Pod 🫛";
            weeklyDevelopmentContent = "The baby's intestines are moving from the umbilical cord into the abdomen.";
            break;
          case 14:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Lemon 🍋";
            weeklyDevelopmentContent = "The baby can now squint, frown, and may be sucking their thumb.";
            break;
          case 15:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Apple 🍎";
            weeklyDevelopmentContent = "The baby's skeleton is developing, and hair patterns are forming.";
            break;
          case 16:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Avocado 🥑";
            weeklyDevelopmentContent = "The baby's facial muscles are developing, allowing for expressions. The eyes are moving beneath eyelids.";
            break;
          case 17:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Turnip 🥬";
            weeklyDevelopmentContent = "The baby is forming adipose (fat) tissue for warmth and energy.";
            break;
          case 18:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Bell Pepper 🫑";
            weeklyDevelopmentContent = "The baby's sense of hearing is developing, and they may hear your voice.";
            break;
          case 19:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Mango 🥭";
            weeklyDevelopmentContent = "The baby's senses are developing, including taste, smell, and touch.";
            break;
          case 20:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Banana 🍌";
            weeklyDevelopmentContent = "The baby's movements are becoming more coordinated. You may feel them move!";
            break;
          case 21:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Carrot 🥕";
            weeklyDevelopmentContent = "The baby's taste buds are developing, and eyebrows and eyelids are now present.";
            break;
          case 22:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Papaya 🥭";
            weeklyDevelopmentContent = "The baby's lips and eyes are more distinct, and they look more like a newborn.";
            break;
          case 23:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Grapefruit 🍊";
            weeklyDevelopmentContent = "The baby's skin is still wrinkled but will soon be filled out with fat.";
            break;
          case 24:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Ear of Corn 🌽";
            weeklyDevelopmentContent = "The baby's inner ear is developed, helping with balance.";
            break;
          case 25:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Rutabaga 🥬";
            weeklyDevelopmentContent = "The baby is starting to put on more weight, filling out their wrinkly skin.";
            break;
          case 26:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Scallion 🧅";
            weeklyDevelopmentContent = "The baby's eyes have formed, though eye color is not yet determined.";
            break;
          // Third Trimester starts here for content grouping
          case 27:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Cauliflower 🥦";
            weeklyDevelopmentContent = "The baby's brain is very active now. They hiccup regularly, which you might feel.";
            break;
          case 28:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Eggplant 🍆";
            weeklyDevelopmentContent = "The baby is starting to develop more regular sleep patterns.";
            break;
          case 29:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Butternut Squash 🎃";
            weeklyDevelopmentContent = "The baby is gaining more weight rapidly and can now regulate their own body temperature.";
            break;
          case 30:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Cabbage 🥬";
            weeklyDevelopmentContent = "The baby's brain is developing rapidly, with billions of neurons forming.";
            break;
          case 31:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Coconut 🥥";
            weeklyDevelopmentContent = "The baby is getting cramped in your womb as they grow larger.";
            break;
          case 32:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Squash 🎃";
            weeklyDevelopmentContent = "The baby is practicing breathing motions to prepare for life outside the womb.";
            break;
          case 33:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Pineapple 🍍";
            weeklyDevelopmentContent = "The baby's bones are hardening, except for the skull which remains flexible for birth.";
            break;
          case 34:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Cantaloupe 🍈";
            weeklyDevelopmentContent = "The baby's central nervous system and lungs are maturing rapidly.";
            break;
          case 35:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Honeydew Melon 🍈";
            weeklyDevelopmentContent = "The baby's kidneys are fully developed, and the liver can process some waste.";
            break;
          case 36:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Head of Romaine Lettuce 🥬";
            weeklyDevelopmentContent = "The baby is likely in a head-down position, preparing for birth.";
            break;
          case 37:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Bunch of Swiss Chard 🥬";
            weeklyDevelopmentContent = "Your baby is considered 'early term' and is preparing for birth.";
            break;
          case 38:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Leek 🧅";
            weeklyDevelopmentContent = "The baby has a firm grasp and is ready to meet you soon!";
            break;
          case 39:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Mini Watermelon 🍉";
            weeklyDevelopmentContent = "The baby's reflexes are coordinated, with a strong grasp and ability to blink.";
            break;
          case 40:
          case 41:
          case 42:
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Small Pumpkin 🎃";
            weeklyDevelopmentContent = "Your baby is fully developed and ready to meet you any day now!";
            break;
          default:
            // This case should ideally not be reached if weekNumber is always 1-42
            weeklyDevelopmentTitle = "$currentWeekStage ($currentTrimester) - Growing Daily";
            weeklyDevelopmentContent = "Each week brings amazing developments to your baby's growth.";
        }
      } else {
        // Fallback if weekNumber couldn't be parsed (should be rare)
        weeklyDevelopmentTitle = "Weekly Development ($currentTrimester)";
        weeklyDevelopmentContent = "Select your current week in a diary entry to see specific details for your stage.";
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Fetal Growth Chart',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        sortedEntries.isEmpty 
            ? Container(
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No growth data available yet.\nAdd entries in your Bump Diary to track fetal growth.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              )
            : Container(
                height: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: _buildSimpleGrowthChart(sortedEntries),
              ),
        const SizedBox(height: 20),
        Text(
          'Weekly Development',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              weeklyDevelopmentTitle, // Use the updated title
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                weeklyDevelopmentContent, // Use the updated content
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Insights',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh AI insights',
              onPressed: _isFetchingAiInsights ? null : _fetchAndSetAiInsights,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFAFC9F8), // Set the background color to match the title bar
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16.0),
            child: _isFetchingAiInsights
                ? const Center(child: CircularProgressIndicator())
                : Text(
                    _aiInsightText ??
                        "AI insights will appear here. Add diary entries to get personalized tips.",
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontStyle: FontStyle.italic),
                  ),
          ),
        ),
      ],
    );
  }

  // Simple custom growth chart that doesn't rely on external packages
  Widget _buildSimpleGrowthChart(List<DiaryEntry> allEntries) {
    List<FlSpot> spots = [];
    List<DiaryEntry> chartableEntries = []; // To keep track of entries used for x-axis labels

    for (var entry in allEntries) {
      if (entry.fetalSize != null && entry.fetalSizeUnit != null) {
        double size = entry.fetalSize!; // Safe due to check
        if (entry.fetalSizeUnit == FetalSizeUnit.inch) { // entry.fetalSizeUnit is also non-null here
          size = size * 2.54; // Convert to cm for consistency
        }
        spots.add(FlSpot(chartableEntries.length.toDouble(), size));
        chartableEntries.add(entry);
      }
    }

    if (spots.isEmpty) {
      return Container(
          height: 250, // Match chart height
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'No fetal growth data to display.\nAdd pregnancy diary entries with fetal size.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[700]),
          ),
        );
    }

    double maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 250, // Adjust height as needed
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) {
                return Text('${value.toInt()} cm', style: GoogleFonts.poppins(fontSize: 10));
              }),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 1, 
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < chartableEntries.length) {
                    DateTime date = chartableEntries[index].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('dd/MM').format(date),
                        style: GoogleFonts.poppins(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox(); 
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xFF78A0E5), width: 1)),
          minX: -0.1, 
          maxX: chartableEntries.isNotEmpty ? chartableEntries.length.toDouble() - (chartableEntries.length > 1 ? 0.9 : 0.1) : 0, // Handle empty chartableEntries
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF78A0E5),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 6, 
                  color: const Color(0xFF78A0E5),
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          maxY: maxY + 2, 
        ),
      ),
    );
  }

  Widget _buildBumpDiarySection() {
    // Filter entries for the selected day
    final entriesForSelectedDate = _allDiaryEntries
        .where((entry) =>
            entry.date.year == _selectedDiaryDate.year &&
            entry.date.month == _selectedDiaryDate.month &&
            entry.date.day == _selectedDiaryDate.day)
        .toList();

    return Column(
      children: [
        // Calendar Header (Title and Toggle Button)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isCalendarExpanded 
                    ? DateFormat('MMMM yyyy').format(_selectedDiaryDate) 
                    : "Week of ${DateFormat('MMM d').format(_selectedDiaryDate.subtract(Duration(days: _selectedDiaryDate.weekday - 1)))}",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(_isCalendarExpanded ? Icons.view_week_outlined : Icons.calendar_month_outlined),
                tooltip: _isCalendarExpanded ? "Switch to Week View" : "Switch to Month View",
                onPressed: () {
                  setState(() {
                    _isCalendarExpanded = !_isCalendarExpanded;
                    // Save this preference
                    _saveData();
                  });
                },
              ),
            ],
          ),
        ),
        
        // Conditional Calendar View
        if (_isCalendarExpanded)
          _buildMonthCalendarView()
        else
          _buildWeekCalendarView(),

        const Divider(),

        // Diary Entries for selected day
        Expanded(
          child: entriesForSelectedDate.isEmpty
              ? Center(
                  child: Text(
                  "No entries for ${DateFormat('MMM d, yyyy').format(_selectedDiaryDate)}.\nTap 'Add New Entry' to log your day!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                ))
              : ListView.builder(
                  itemCount: entriesForSelectedDate.length,
                  itemBuilder: (context, index) {
                    final entry = entriesForSelectedDate[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row( // Use Row for alignment
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded( // Main content takes available space
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Pregnancy Stage Badge (Only for Pregnancy Mode)
                                  if (_selectedMode == GrowthScreenMode.pregnancy && entry.pregnancyStage != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8.0),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFAFC9F8).withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Color(0xFF78A0E5), width: 1),
                                      ),
                                      child: Text(
                                        "${entry.pregnancyStage} (${_getTrimesterFromWeek(entry.pregnancyStage!)})", // pregnancyStage is checked for null above
                                        style: GoogleFonts.poppins(
                                          fontSize: 12, 
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF78A0E5),
                                        ),
                                      ),
                                    ),
                                  
                                  if (entry.imagePath != null && entry.imagePath!.isNotEmpty)
                                    Container(
                                      height: 150,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: Builder(
                                          builder: (context) {
                                            try {
                                              final file = File(entry.imagePath!);
                                              if (!file.existsSync()) {
                                                return const Center(child: Text("Image not found"));
                                              }
                                              return Image.file(
                                                file,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Center(child: Text("Could not load image"));
                                                },
                                              );
                                            } catch (e) {
                                              return Center(child: Text("Error: $e"));
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  if (entry.imagePath != null && entry.imagePath!.isNotEmpty) const SizedBox(height: 8),
                                  // Display Title (bold) and Description
                                  Text(entry.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 4),
                                  Text(entry.description, style: GoogleFonts.poppins(fontSize: 14)),
                                  const SizedBox(height: 8),
                                  
                                  // Conditional display of other details based on mode
                                  if (_selectedMode == GrowthScreenMode.pregnancy)
                                    Text(
                                      "Mood: ${entry.mood ?? 'N/A'}\nCravings: ${entry.cravings ?? 'N/A'}\nFetal Size: ${entry.fetalSizeDisplay ?? 'N/A'}",
                                      style: GoogleFonts.poppins(),
                                    )
                                  else if (_selectedMode == GrowthScreenMode.baby) 
                                    Text(
                                      "Height: ${entry.heightDisplay ?? 'N/A'}\nWeight: ${entry.weightDisplay ?? 'N/A'}",
                                      style: GoogleFonts.poppins(),
                                    ),
                                ],
                              ),
                            ),
                            // Delete Button
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.7)),
                              tooltip: "Delete Entry",
                              onPressed: () {
                                _confirmDeleteEntry(context, entry);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Add Diary Entry Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_comment_outlined),
            label: Text('Add New Entry', style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor, // Use theme's primary color
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50), // Make button wide
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // TODO: Implement Add Diary Entry Dialog/Screen
              _showAddEntryDialog(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekCalendarView() {
    DateTime now = _selectedDiaryDate;
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: _goToPreviousWeek,
            tooltip: "Previous Week",
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final day = startOfWeek.add(Duration(days: index));
                final isSelected = day.year == _selectedDiaryDate.year &&
                                   day.month == _selectedDiaryDate.month &&
                                   day.day == _selectedDiaryDate.day;
                final hasEntries = _allDiaryEntries.any((entry) => isSameDay(entry.date, day));

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDiaryDate = DateTime(day.year, day.month, day.day); // Normalize
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('E').format(day), // Short day name (e.g., Mon)
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d').format(day), // Day number
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                          ),
                        ),
                        if (hasEntries)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            height: 5,
                            width: 5,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 9), // Keep spacing consistent
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: _goToNextWeek,
            tooltip: "Next Week",
          ),
        ],
      ),
    );
  }

  List<DiaryEntry> _getEntriesForDay(DateTime day) {
    return _allDiaryEntries.where((entry) {
      return entry.date.year == day.year && entry.date.month == day.month && entry.date.day == day.day;
    }).toList();
  }

  Widget _buildMonthCalendarView() {
    return TableCalendar<DiaryEntry>(
      locale: 'en_US', // Optional: for localization
      firstDay: DateTime.utc(2020, 1, 1), // Example: reasonably early date
      lastDay: DateTime.utc(2030, 12, 31), // Example: reasonably late date
      focusedDay: _selectedDiaryDate,
      calendarFormat: CalendarFormat.month,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDiaryDate, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedDiaryDate, selectedDay)) {
          setState(() {
            _selectedDiaryDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day); // Normalize to midnight
            // _isCalendarExpanded = false; // Removed: Do not switch back to week view
          });
        }
      },
      onPageChanged: (focusedDay) {
         setState(() {
          // Keep the selected day if it exists in the new month, otherwise try to keep the day number or clamp to last day.
          int dayToKeep = _selectedDiaryDate.day;
          int newMonthMaxDays = DateTime(focusedDay.year, focusedDay.month + 1, 0).day;
          if (dayToKeep > newMonthMaxDays) {
            dayToKeep = newMonthMaxDays;
          }
          _selectedDiaryDate = DateTime(focusedDay.year, focusedDay.month, dayToKeep);
        });
      },
      eventLoader: _getEntriesForDay,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isNotEmpty) {
            return Positioned(
              right: 0, // Centered horizontally
              left: 0,  // Centered horizontally
              bottom: 4, // Positioned towards the bottom
              child: Container(
                height: 10, // Increased size of the dot
                width: 10,  // Increased size of the dot
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withOpacity(0.8), // Consistent color
                ),
              ),
            );
          }
          return null;
        },
      ),
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false, // We have our own toggle
        titleTextStyle: GoogleFonts.poppins(fontSize: 16.0, fontWeight: FontWeight.bold),
        leftChevronIcon: const Icon(Icons.chevron_left, color: Color(0xFF78A0E5)),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Color(0xFF78A0E5)),
      ),
      calendarStyle: CalendarStyle(
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: GoogleFonts.poppins(color: Colors.white),
        todayDecoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        todayTextStyle: GoogleFonts.poppins(color: Colors.white),
        weekendTextStyle: GoogleFonts.poppins(color: Colors.redAccent),
        defaultTextStyle: GoogleFonts.poppins(),
        outsideDaysVisible: false,
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Color(0xFF78A0E5)),
        weekendStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.redAccent),
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context) {
    // Initialize controllers and default values for the dialog
    final titleController = TextEditingController(); // New
    final descriptionController = TextEditingController(); // New

    final cravingsController = TextEditingController(); // Only for pregnancy
    final moodController = TextEditingController(); // Only for pregnancy
    final fetalSizeController = TextEditingController(); // Only for pregnancy
    final heightController = TextEditingController(); // Only for baby
    final weightController = TextEditingController(); // Only for baby

    FetalSizeUnit selectedFetalSizeUnit = FetalSizeUnit.cm; // Default for pregnancy
    LengthUnit selectedHeightUnit = LengthUnit.cm; // Default for baby height
    WeightUnit selectedWeightUnit = WeightUnit.kg; // Default for baby weight
    String? selectedPregnancyStage = _selectedMode == GrowthScreenMode.pregnancy ? "Week 12" : null; // Default for pregnancy
    String? selectedImagePath;
    final ImagePicker picker = ImagePicker();
    final List<String> pregnancyStages = List.generate(42, (index) => "Week ${index + 1}");

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Add Diary Entry for ${DateFormat('MMM d, yyyy').format(_selectedDiaryDate)}", style: GoogleFonts.poppins()),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Common: Image Picker
                    if (selectedImagePath != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          // ... (image display code)
                        ),
                      ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_camera),
                      label: Text(selectedImagePath == null ? "Add Photo" : "Change Photo", style: GoogleFonts.poppins()),
                      onPressed: () async {
                        try {
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
                          if (image != null) {
                            setDialogState(() { selectedImagePath = image.path; });
                          }
                        } catch (e) {
                          if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not pick image: $e"))); }
                        }
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                    ),
                    const SizedBox(height: 15),

                    // Common: Title
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: "Title", hintText: "Enter a title for your entry", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 10),
                    
                    // Common: Description
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(labelText: "Description", hintText: "How was the day? Any details...", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                      maxLines: 3,
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 10),

                    // Pregnancy Mode Specific Fields
                    if (_selectedMode == GrowthScreenMode.pregnancy) ...[
                      // Pregnancy Stage Dropdown
                      Container(
                        margin: const EdgeInsets.only(bottom: 15.0),
                        // ... (pregnancy stage dropdown code)
                        child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedPregnancyStage,
                            hint: Text('Select Pregnancy Stage', style: GoogleFonts.poppins()),
                            items: pregnancyStages.map((String stage) {
                              return DropdownMenuItem<String>(value: stage, child: Text(stage, style: GoogleFonts.poppins()));
                            }).toList(),
                            onChanged: (String? value) {
                              if (value != null) { setDialogState(() { selectedPregnancyStage = value; }); }
                            },
                          ),
                      ),
                      TextField(
                        controller: moodController,
                        decoration: InputDecoration(labelText: "Mood", hintText: "e.g., Happy, Tired", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: cravingsController,
                        decoration: InputDecoration(labelText: "Cravings", hintText: "e.g., Pickles, Chocolate", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 10),
                      // Fetal Size
                      Row(
                        // ... (fetal size input and unit dropdown code)
                        children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: fetalSizeController,
                            decoration: InputDecoration(labelText: "Fetal Size", hintText: "Enter size", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 59, // Match TextField height
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                            child: Center(
                              child: DropdownButton<FetalSizeUnit>(
                                value: selectedFetalSizeUnit,
                                underline: Container(),
                                items: FetalSizeUnit.values.map((FetalSizeUnit unit) {
                                  return DropdownMenuItem<FetalSizeUnit>(value: unit, child: Text(unit.name, style: GoogleFonts.poppins()));
                                }).toList(),
                                onChanged: (FetalSizeUnit? value) {
                                  if (value != null) { setDialogState(() { selectedFetalSizeUnit = value; }); }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                      ),
                    ],

                    // Baby Tracker Mode Specific Fields
                    if (_selectedMode == GrowthScreenMode.baby) ...[
                      // Height
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: heightController,
                              decoration: InputDecoration(labelText: "Height", hintText: "Enter height", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 59, // Match TextField height
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                              child: Center(
                                child: DropdownButton<LengthUnit>(
                                  value: selectedHeightUnit,
                                  underline: Container(),
                                  items: LengthUnit.values.map((LengthUnit unit) {
                                    return DropdownMenuItem<LengthUnit>(value: unit, child: Text(unit.name, style: GoogleFonts.poppins()));
                                  }).toList(),
                                  onChanged: (LengthUnit? value) {
                                    if (value != null) { setDialogState(() { selectedHeightUnit = value; }); }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Weight
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: weightController,
                              decoration: InputDecoration(labelText: "Weight", hintText: "Enter weight", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 59, // Match TextField height
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                              child: Center(
                                child: DropdownButton<WeightUnit>(
                                  value: selectedWeightUnit,
                                  underline: Container(),
                                  items: WeightUnit.values.map((WeightUnit unit) {
                                    return DropdownMenuItem<WeightUnit>(value: unit, child: Text(unit.name, style: GoogleFonts.poppins()));
                                  }).toList(),
                                  onChanged: (WeightUnit? value) {
                                    if (value != null) { setDialogState(() { selectedWeightUnit = value; }); }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("Cancel", style: GoogleFonts.poppins()),
                  onPressed: () { Navigator.of(context).pop(); },
                ),
                ElevatedButton(
                  child: Text("Save Entry", style: GoogleFonts.poppins()),
                  onPressed: () {
                    if (titleController.text.isEmpty) { // Check title instead
                       if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Title cannot be empty!", style: GoogleFonts.poppins()))); }
                       return;
                    }
                    if (descriptionController.text.isEmpty) { // Also check description
                       if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Description cannot be empty!", style: GoogleFonts.poppins()))); }
                       return;
                    }

                    final DateTime entryDate = DateTime(_selectedDiaryDate.year, _selectedDiaryDate.month, _selectedDiaryDate.day);
                    DiaryEntry newEntry;

                    if (_selectedMode == GrowthScreenMode.pregnancy) {
                      double fetalSize = 0.0;
                      if (fetalSizeController.text.isNotEmpty) {
                        try { fetalSize = double.parse(fetalSizeController.text); } catch (e) { /* Handle error or default */ }
                      }
                      newEntry = DiaryEntry(
                        date: entryDate,
                        imagePath: selectedImagePath,
                        title: titleController.text,
                        description: descriptionController.text,
                        mood: moodController.text.isNotEmpty ? moodController.text : "Not specified",
                        cravings: cravingsController.text.isNotEmpty ? cravingsController.text : "None",
                        fetalSize: fetalSize,
                        fetalSizeUnit: selectedFetalSizeUnit,
                        pregnancyStage: selectedPregnancyStage,
                      );
                    } else { // Baby Mode
                      double height = 0.0;
                      if (heightController.text.isNotEmpty) {
                        try { height = double.parse(heightController.text); } catch (e) { /* Handle error or default */ }
                      }
                      double weight = 0.0;
                      if (weightController.text.isNotEmpty) {
                        try { weight = double.parse(weightController.text); } catch (e) { /* Handle error or default */ }
                      }
                      newEntry = DiaryEntry(
                        date: entryDate,
                        imagePath: selectedImagePath,
                        title: titleController.text,
                        description: descriptionController.text,
                        height: height,
                        heightUnit: selectedHeightUnit,
                        weight: weight,
                        weightUnit: selectedWeightUnit,
                      );
                    }

                    setState(() {
                      _allDiaryEntries.add(newEntry);
                      _userScore += 10;
                      _saveData();
                      _fetchAndSetAiInsights();
                    });
                    if (context.mounted) { Navigator.of(context).pop(); _showPointsGainedDialog(); }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBabyGrowthChartsSection() {
    // Filter entries that have height or weight data (typically from Baby mode)
    final babyEntries = _allDiaryEntries.where((entry) => entry.height != null || entry.weight != null).toList();
    babyEntries.sort((a, b) => a.date.compareTo(b.date));

    List<FlSpot> heightSpots = [];
    List<FlSpot> weightSpots = [];

    for (var i = 0; i < babyEntries.length; i++) {
      var entry = babyEntries[i];
      if (entry.height != null) {
        double heightValue = entry.height!;
        if (entry.heightUnit == LengthUnit.inch) {
          heightValue *= 2.54; // Convert to cm for consistency if needed, or decide on a display unit
        }
        heightSpots.add(FlSpot(i.toDouble(), heightValue));
      }
      if (entry.weight != null) {
        double weightValue = entry.weight!;
        if (entry.weightUnit == WeightUnit.lb) {
          weightValue *= 0.453592; // Convert to kg for consistency if needed
        }
        weightSpots.add(FlSpot(i.toDouble(), weightValue));
      }
    }
    
    // Determine max Y values for charts
    double maxHeightY = heightSpots.isNotEmpty ? heightSpots.map((spot) => spot.y).reduce((a,b) => a > b ? a : b) + 5 : 50;
    double maxWeightY = weightSpots.isNotEmpty ? weightSpots.map((spot) => spot.y).reduce((a,b) => a > b ? a : b) + 2 : 10;

    Widget buildChart(String title, List<FlSpot> spots, String yAxisLabel, double maxY, List<DiaryEntry> entriesForAxis) {
      if (spots.isEmpty) {
        return Container(
          height: 200,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
          child: Text('No $title data available.\nAdd entries in the Growth Diary.', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[600])),
        );
      }
      return Container(
        height: 280, // Adjusted height for individual charts
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
        ),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) {
                  return Text('${value.toStringAsFixed(1)} $yAxisLabel', style: GoogleFonts.poppins(fontSize: 10));
                }),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true, reservedSize: 40, interval: 1,
                  getTitlesWidget: (value, meta) {
                    if (value >= 0 && value < entriesForAxis.length && value.toInt() == value) {
                      DateTime date = entriesForAxis[value.toInt()].date;
                      return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat('dd/MM').format(date), style: GoogleFonts.poppins(fontSize: 10)));
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xFF78A0E5), width: 1)),
            minX: -0.1, maxX: spots.length.toDouble() - (spots.length > 1 ? 0.9 : 0.1),
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF78A0E5),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 5, color: const Color(0xFF78A0E5), strokeWidth: 1, strokeColor: Colors.white),
                ),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('Height Growth Chart', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        buildChart('Height', heightSpots, 'cm', maxHeightY, babyEntries.where((e) => e.height != null).toList()), // Assuming cm display
        const SizedBox(height: 24),
        Text('Weight Growth Chart', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        buildChart('Weight', weightSpots, 'kg', maxWeightY, babyEntries.where((e) => e.weight != null).toList()), // Assuming kg display
        const SizedBox(height: 24),

        // Nutrition Suggestion Section
        _buildNutritionSuggestionSection(),
        const SizedBox(height: 20),

        // AI Insights for Baby Growth
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Growth Insights',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh AI insights',
              onPressed: _isFetchingAiInsights ? null : _fetchAndSetAiInsights, // Reuses existing fetch and state
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFAFC9F8), // Matching app theme
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16.0),
            child: _isFetchingAiInsights
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : Text(
                    _aiInsightText ?? // Reuses existing AI insight text state
                        "AI insights for your baby's growth will appear here. Add diary entries with height and weight to get personalized tips.",
                    style: GoogleFonts.poppins(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black), // Changed color to black
                  ),
          ),
        ),
      ],
    );
  }

  // New method for Nutrition Suggestion Section (Baby Tracker)
  Widget _buildNutritionSuggestionSection() {
    // TODO: Enhance with age-specific advice if baby's birth date becomes available.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          'Baby Nutrition Tips 🍼',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'General advice (customize as your baby grows):',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
              Text('• 0-6 Months: Exclusive breastfeeding is recommended. If formula feeding, use an appropriate infant formula.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 5),
              Text('• 6+ Months: Introduce solid foods one at a time to check for allergies. Start with iron-fortified cereals, pureed fruits, and vegetables.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 5),
              Text('• 9-12 Months: Offer a variety of textures and finger foods. Baby can start eating many of the same foods as the family (ensure they are soft and safely prepared).',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 5),
              Text('• Always consult your pediatrician for personalized nutrition advice.',
                style: GoogleFonts.poppins(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.deepPurpleAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteEntry(BuildContext context, DiaryEntry entry) {
    // Implement the confirmation dialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Confirm Deletion", style: GoogleFonts.poppins()),
          content: Text("Are you sure you want to delete this entry?", style: GoogleFonts.poppins()),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel", style: GoogleFonts.poppins()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Delete", style: GoogleFonts.poppins()),
              onPressed: () {
                setState(() {
                  _allDiaryEntries.remove(entry);
                  // Save changes
                  _saveData();
                  // Refresh AI insights
                  _fetchAndSetAiInsights();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
} 