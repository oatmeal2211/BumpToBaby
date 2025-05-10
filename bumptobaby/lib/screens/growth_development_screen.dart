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

// Data class for Diary Entry
class DiaryEntry {
  final DateTime date;
  final String? imagePath;
  final String journalEntry;
  final String cravings;
  final String mood;
  final double fetalSize; // Changed to double for numerical value
  final FetalSizeUnit fetalSizeUnit; // Added unit
  final String pregnancyStage; // Added pregnancy stage field (stores "Week X")

  DiaryEntry({
    required this.date,
    this.imagePath,
    required this.journalEntry,
    required this.cravings,
    required this.mood,
    required this.fetalSize,
    required this.fetalSizeUnit,
    required this.pregnancyStage,
  });

  // Helper method to get fetal size with unit as string
  String get fetalSizeDisplay {
    String unitStr = fetalSizeUnit == FetalSizeUnit.cm ? 'cm' : 'inch';
    return '$fetalSize $unitStr';
  }
  
  // Convert DiaryEntry to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'date': date.millisecondsSinceEpoch,
      'imagePath': imagePath,
      'journalEntry': journalEntry,
      'cravings': cravings,
      'mood': mood,
      'fetalSize': fetalSize,
      'fetalSizeUnit': fetalSizeUnit.index, // Store enum as int
      'pregnancyStage': pregnancyStage,
    };
  }

  // Create DiaryEntry from JSON data
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      imagePath: json['imagePath'],
      journalEntry: json['journalEntry'],
      cravings: json['cravings'],
      mood: json['mood'],
      fetalSize: json['fetalSize'],
      fetalSizeUnit: FetalSizeUnit.values[json['fetalSizeUnit']],
      pregnancyStage: json['pregnancyStage'],
    );
  }
}

class GrowthDevelopmentScreen extends StatefulWidget {
  const GrowthDevelopmentScreen({Key? key}) : super(key: key);

  @override
  State<GrowthDevelopmentScreen> createState() => _GrowthDevelopmentScreenState();
}

class _GrowthDevelopmentScreenState extends State<GrowthDevelopmentScreen> {
  GrowthScreenMode _selectedMode = GrowthScreenMode.pregnancy; // Default to Pregnancy
  DateTime _selectedDiaryDate = DateTime.now();
  final List<DiaryEntry> _allDiaryEntries = []; // Stores all diary entries
  bool _isCalendarExpanded = false; // State for calendar view

  // State for AI Insights
  String? _aiInsightText;
  bool _isFetchingAiInsights = false;

  // For data persistence
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDiaryDate = DateTime(_selectedDiaryDate.year, _selectedDiaryDate.month, _selectedDiaryDate.day); // Normalize to midnight
    // Load saved data
    _loadSavedData();
  }

  // Load saved preferences and diary entries
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load selected mode
      final savedModeIndex = prefs.getInt('selected_mode') ?? 0;
      
      // Load calendar view state
      final savedCalendarExpanded = prefs.getBool('calendar_expanded') ?? false;
      
      // Load diary entries
      final entriesJsonList = prefs.getStringList('diary_entries') ?? [];
      final loadedEntries = entriesJsonList
          .map((jsonStr) => DiaryEntry.fromJson(json.decode(jsonStr)))
          .toList();

      if (mounted) {
        setState(() {
          _selectedMode = GrowthScreenMode.values[savedModeIndex];
          _isCalendarExpanded = savedCalendarExpanded;
          _allDiaryEntries.clear();
          _allDiaryEntries.addAll(loadedEntries);
          _isLoading = false;
        });
      }
      
      // Only fetch AI insights if there are diary entries
      if (_allDiaryEntries.isNotEmpty) {
        _fetchAndSetAiInsights();
      }
    } catch (e) {
      developer.log('Error loading saved data: $e', name: 'GrowthDevelopmentScreen');
      // If there's an error, just continue with the default state and add sample data if needed
      if (_allDiaryEntries.isEmpty) {
        _addSampleEntries();
      }
      setState(() {
        _isLoading = false;
      });
      _fetchAndSetAiInsights();
    }
  }

  // Save current preferences and diary entries
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save selected mode
      await prefs.setInt('selected_mode', _selectedMode.index);
      
      // Save calendar view state
      await prefs.setBool('calendar_expanded', _isCalendarExpanded);
      
      // Save diary entries
      final entriesJsonList = _allDiaryEntries
          .map((entry) => json.encode(entry.toJson()))
          .toList();
      await prefs.setStringList('diary_entries', entriesJsonList);
      
      developer.log('Data saved successfully', name: 'GrowthDevelopmentScreen');
    } catch (e) {
      developer.log('Error saving data: $e', name: 'GrowthDevelopmentScreen');
    }
  }

  // Add sample entries for first-time users
  void _addSampleEntries() {
    _allDiaryEntries.addAll([
      DiaryEntry(
        date: DateTime.now().subtract(const Duration(days: 30)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
        journalEntry: "First check-up!",
        cravings: "None yet",
        mood: "Excited",
        fetalSize: 2.5,
        fetalSizeUnit: FetalSizeUnit.cm,
        pregnancyStage: "Week 8",
      ),
      DiaryEntry(
        date: DateTime.now().subtract(const Duration(days: 20)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
        journalEntry: "Feeling good today",
        cravings: "Chocolate",
        mood: "Happy",
        fetalSize: 4.2,
        fetalSizeUnit: FetalSizeUnit.cm,
        pregnancyStage: "Week 10",
      ),
      DiaryEntry(
        date: DateTime.now().subtract(const Duration(days: 10)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
        journalEntry: "Felt a kick!",
        cravings: "Ice cream",
        mood: "Happy",
        fetalSize: 8.5,
        fetalSizeUnit: FetalSizeUnit.cm,
        pregnancyStage: "Week 18",
      ),
      DiaryEntry(
        date: DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
        journalEntry: "Regular check-up",
        cravings: "Pickles",
        mood: "Energetic",
        fetalSize: 12.3,
        fetalSizeUnit: FetalSizeUnit.cm,
        pregnancyStage: "Week 20",
      ),
    ]);
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
      // 1. Gather data
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

      final latestEntry = sortedEntries.isNotEmpty ? sortedEntries.last : null;
      final currentWeekStage = latestEntry?.pregnancyStage ?? "Week 12"; // Default
      final currentTrimester = _getTrimesterFromWeek(currentWeekStage);

      List<String> formattedGrowthData = sortedEntries.map((entry) {
        return "${DateFormat('yyyy-MM-dd').format(entry.date)}: ${entry.fetalSizeDisplay}, Mood: ${entry.mood}, Cravings: ${entry.cravings}, Journal: ${entry.journalEntry.substring(0, entry.journalEntry.length > 50 ? 50 : entry.journalEntry.length)}${entry.journalEntry.length > 50 ? "..." : ""}";
      }).toList();

      // 2. Construct Prompt
      final prompt = """
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
""" ;

      // 3. Call Gemini API
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Growth & Development',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFAFC9F8),
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
    return DefaultTabController(
      length: 2, // Updated to 2 tabs
      child: Column(
        children: [
          TabBar(
            labelColor: const Color(0xFF78A0E5),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF78A0E5),
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(),
            isScrollable: true,
            indicator: BoxDecoration(
              color: Colors.transparent, // Make the indicator transparent
              border: Border(
                bottom: BorderSide(color: const Color(0xFF78A0E5), width: 2), // Custom indicator
              ),
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 40), // Adjust padding for centering
            tabs: const [
              Tab(text: 'Fetal Growth'),
              Tab(text: 'Bump Diary'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFetalGrowthSection(),
                _buildBumpDiarySection(),
              ],
            ),
          ),
        ],
      ),
    );
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
          child: Padding(
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
  Widget _buildSimpleGrowthChart(List<DiaryEntry> entries) {
    if (entries.isEmpty) return const SizedBox();

    // Prepare data for the line chart
    List<FlSpot> spots = [];
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i];
      double size = entry.fetalSize;
      if (entry.fetalSizeUnit == FetalSizeUnit.inch) {
        size = size * 2.54; // Convert to cm for consistency
      }
      // Using index position instead of timestamp for x-axis for simpler display
      spots.add(FlSpot(i.toDouble(), size));
    }

    // Determine the maximum y value for the chart
    double maxY = spots.isNotEmpty ? spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) : 0;

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
                interval: 1, // Show each integer value
                getTitlesWidget: (value, meta) {
                  // Check if the value is an integer and in range of our entries array
                  if (value >= 0 && value < entries.length && value.toInt() == value) {
                    DateTime date = entries[value.toInt()].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('dd/MM').format(date),
                        style: GoogleFonts.poppins(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox(); // Empty widget for non-data points
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide top titles
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide right titles
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xFF78A0E5), width: 1)),
          minX: -0.1, // Give a little space on the left
          maxX: entries.length - 0.9, // Give space on the right
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF78A0E5),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 6, // Larger dots
                  color: const Color(0xFF78A0E5),
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          maxY: maxY + 2, // Set maxY to control the upper limit of the y-axis
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
                                  // Pregnancy Stage Badge
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8.0),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFAFC9F8).withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Color(0xFF78A0E5), width: 1),
                                    ),
                                    child: Text(
                                      "${entry.pregnancyStage} (${_getTrimesterFromWeek(entry.pregnancyStage)})", // Display week and trimester
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
                                  Text(entry.journalEntry, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Mood: ${entry.mood}\nCravings: ${entry.cravings}\nFetal Size: ${entry.fetalSizeDisplay}",
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
    final journalController = TextEditingController();
    final cravingsController = TextEditingController();
    final moodController = TextEditingController();
    final fetalSizeController = TextEditingController();
    FetalSizeUnit selectedUnit = FetalSizeUnit.cm; // Default unit
    String selectedPregnancyStage = "Week 12"; // Default stage to a week
    String? selectedImagePath;
    final ImagePicker picker = ImagePicker();

    // List of pregnancy stages for dropdown (Weeks only)
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
                    // Pregnancy Stage Dropdown
                    Container(
                      margin: const EdgeInsets.only(bottom: 15.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedPregnancyStage,
                            hint: Text('Select Pregnancy Stage', style: GoogleFonts.poppins()),
                            items: pregnancyStages.map((String stage) {
                              return DropdownMenuItem<String>(
                                value: stage,
                                child: Text(stage, style: GoogleFonts.poppins()),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedPregnancyStage = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    if (selectedImagePath != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Container(
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
                                  final file = File(selectedImagePath!);
                                  if (!file.existsSync()) {
                                    return const Center(child: Text("Image file not found"));
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
                      ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_camera),
                      label: Text(selectedImagePath == null ? "Add Photo" : "Change Photo", style: GoogleFonts.poppins()),
                      onPressed: () async {
                        try {
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            maxHeight: 1200,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setDialogState(() {
                              selectedImagePath = image.path;
                            });
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Could not pick image: $e")),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: journalController,
                      decoration: InputDecoration(labelText: "Journal Entry", hintText: "How are you feeling?", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                      maxLines: 3,
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: moodController,
                      decoration: InputDecoration(labelText: "Mood", hintText: "e.g., Happy, Tired, Excited", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cravingsController,
                      decoration: InputDecoration(labelText: "Cravings", hintText: "e.g., Pickles, Chocolate", border: OutlineInputBorder(), labelStyle: GoogleFonts.poppins()),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: fetalSizeController,
                            decoration: InputDecoration(
                              labelText: "Fetal Size",
                              hintText: "Enter size",
                              border: OutlineInputBorder(),
                              labelStyle: GoogleFonts.poppins(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), // Allow numbers with up to 2 decimal places
                            ],
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 59, // Match TextField height
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: DropdownButton<FetalSizeUnit>(
                                value: selectedUnit,
                                underline: Container(), // Remove default underline
                                items: [
                                  DropdownMenuItem(
                                    value: FetalSizeUnit.cm,
                                    child: Text('cm', style: GoogleFonts.poppins()),
                                  ),
                                  DropdownMenuItem(
                                    value: FetalSizeUnit.inch,
                                    child: Text('inch', style: GoogleFonts.poppins()),
                                  ),
                                ],
                                onChanged: (FetalSizeUnit? value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      selectedUnit = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("Cancel", style: GoogleFonts.poppins()),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text("Save Entry", style: GoogleFonts.poppins()),
                  onPressed: () {
                    if (journalController.text.isNotEmpty) {
                      // Parse fetal size value, default to 0.0 if empty or invalid
                      double fetalSize = 0.0; // Ensure initialized as double
                      if (fetalSizeController.text.isNotEmpty) {
                        try {
                          fetalSize = double.parse(fetalSizeController.text);
                        } catch (e) {
                          // Handle parsing error if the text is not a valid double
                          if (context.mounted) { // Check if the widget is still in the tree
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Invalid number format for fetal size. Please enter a valid number.")),
                            );
                          }
                          return; // Don't close dialog or proceed on error
                        }
                      }

                      // Ensure _selectedDiaryDate is normalized to remove time components
                      final DateTime entryDate = DateTime(
                        _selectedDiaryDate.year,
                        _selectedDiaryDate.month,
                        _selectedDiaryDate.day,
                      );

                      setState(() {
                        _allDiaryEntries.add(DiaryEntry(
                          date: entryDate,
                          imagePath: selectedImagePath,
                          journalEntry: journalController.text,
                          mood: moodController.text.isNotEmpty ? moodController.text : "Not specified",
                          cravings: cravingsController.text.isNotEmpty ? cravingsController.text : "None",
                          fetalSize: fetalSize, // fetalSize is now definitely a double
                          fetalSizeUnit: selectedUnit,
                          pregnancyStage: selectedPregnancyStage, // Add the selected pregnancy stage
                        ));
                        // Save to persist data
                        _saveData();
                        // Refresh AI insights
                        _fetchAndSetAiInsights();
                      });
                      if (context.mounted) { // Check if the widget is still in the tree
                        Navigator.of(context).pop();
                      }
                    } else {
                      if (context.mounted) { // Check if the widget is still in the tree
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Journal entry cannot be empty!", style: GoogleFonts.poppins()))
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBabyTrackerModeContent() {
    // Placeholder for Baby Tracker Mode content
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          const Icon(
              Icons.child_care,
              size: 100,
              color: Color(0xFFAFC9F8),
            ),
          const SizedBox(height: 20),
            Text(
            'Baby Tracker Mode Content',
              style: GoogleFonts.poppins(
              fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 10),
            Text(
            '(Growth Charts, Milestones, Daily Diary, etc.)',
            textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
              ),
            ),
          ],
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