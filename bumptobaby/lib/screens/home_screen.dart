import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bumptobaby/screens/health_schedule_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bumptobaby/services/health_schedule_service.dart';
import 'package:bumptobaby/models/health_schedule.dart';
import 'package:bumptobaby/services/seed_pubmed_data.dart';

// Import all the screens we need
import 'package:bumptobaby/screens/nearest_clinic_screen.dart';
import 'package:bumptobaby/screens/smart_health_tracker_screen.dart';
import 'package:bumptobaby/screens/growth_development_screen.dart';
import 'package:bumptobaby/screens/nutrition_meals_screen.dart';
import 'package:bumptobaby/screens/audio_visual_learning_screen.dart';
import 'package:bumptobaby/screens/family_planning_screen.dart';
import 'package:bumptobaby/screens/profile_screen.dart';
import 'package:bumptobaby/screens/health_help_page.dart';
import 'package:bumptobaby/screens/health_survey_screen.dart';
import 'package:bumptobaby/screens/community_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  
  const HomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HealthScheduleService _healthScheduleService = HealthScheduleService();
  late SeedPubMedData _seedPubMedData;
  
  String _username = '';
  String _profileImageUrl = '';
  int _currentIndex = 0;
  bool _isLoadingSchedule = false;
  HealthSchedule? _healthSchedule;
  
  @override
  void initState() {
    super.initState();
    _username = widget.username;
    _fetchUserData();
    
    // Initialize and check if database needs seeding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedPubMedData = SeedPubMedData(context);
      _seedPubMedData.checkAndSeedDatabaseIfNeeded();
    });
  }
  
  Future<void> _fetchUserData() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
            
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _username = userData['name'] ?? widget.username;
            _profileImageUrl = userData['profileImageUrl'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }
  
  // Method to fetch health schedule from Firebase
  Future<void> _fetchHealthSchedule() async {
    setState(() {
      _isLoadingSchedule = true;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final schedule = await _healthScheduleService.getLatestHealthSchedule(currentUser.uid);
        setState(() {
          _healthSchedule = schedule;
          _isLoadingSchedule = false;
        });
      } else {
        setState(() {
          _isLoadingSchedule = false;
        });
      }
    } catch (e) {
      print('Error fetching health schedule: $e');
      setState(() {
        _isLoadingSchedule = false;
      });
    }
  }
  
  // Method to build the current page based on bottom nav selection
  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        // My Schedule page - fetch schedule if needed
        if (_isLoadingSchedule) {
          return Center(child: CircularProgressIndicator());
        } else if (_healthSchedule != null) {
          return HealthScheduleScreen(schedule: _healthSchedule!);
        } else {
          // Fetch schedule when this tab is selected
          _fetchHealthSchedule();
          return HealthSurveyScreen();
        }
      case 2:
        return GrowthDevelopmentScreen(); // Show Growth & Development Screen for Baby Tracker
      case 3:
        return HealthHelpPage(); // Health Help
      case 4:
        return CommunityScreen(); // Community page
      default:
        return _buildHomePage();
    }
  }
  
  // Method to build the main home page content
  Widget _buildHomePage() {
    return Column(
      children: [
        // Top part with greeting and profile
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hi $_username!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E6091),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => ProfileScreen())
                  ).then((_) => _fetchUserData());
                },
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: _profileImageUrl.isNotEmpty
                      ? NetworkImage(_profileImageUrl)
                      : AssetImage('lib/assets/images/BumpToBaby Logo.png') as ImageProvider,
                ),
              ),
            ],
          ),
        ),
        
        // Grid of features - expanded to fill more space
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 0.8, // Further reduced from 0.9 to accommodate larger content
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                // Vaccination Clinic Nearby
                FeatureCard(
                  title: 'Vaccination\nClinic Nearby',
                  icon: Icons.local_hospital,
                  color: Color(0xFFAFDCF8),
                  imagePath: 'lib/assets/images/vaccination.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NearestClinicMapScreen()),
                    );
                  },
                ),
                
                // Smart Health Tracker
                FeatureCard(
                  title: 'Smart Health\nTracker',
                  icon: Icons.favorite,
                  color: Color(0xFFF8AFAF),
                  imagePath: 'lib/assets/images/smart_health_tracker.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SmartHealthTrackerScreen()),
                    );
                  },
                ),
                
                // Growth & Development
                FeatureCard(
                  title: 'Growth &\nDevelopment',
                  icon: Icons.child_care,
                  color: Color(0xFFAFC9F8),
                  imagePath: 'lib/assets/images/growth_development.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GrowthDevelopmentScreen()),
                    );
                  },
                ),
                
                // Nutrition & Meals
                FeatureCard(
                  title: 'Nutrition &\nMeals',
                  icon: Icons.restaurant,
                  color: Color(0xFFF8AFAF),
                  imagePath: 'lib/assets/images/nutrition_meals.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NutritionMealsScreen()),
                    );
                  },
                ),
                
                // Audio/Visual Learning
                FeatureCard(
                  title: 'Audio/Visual\nLearning',
                  icon: Icons.videocam,
                  color: Color(0xFFAFDCF8),
                  imagePath: 'lib/assets/images/audio_visual.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AudioVisualLearningScreen()),
                    );
                  },
                ),
                
                // Family Planning
                FeatureCard(
                  title: 'Family\nPlanning',
                  icon: Icons.family_restroom,
                  color: Color(0xFFF8AFAF),
                  imagePath: 'lib/assets/images/family_planning.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FamilyPlanningScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9F2F2),
      body: SafeArea(
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            NavBarItem(
              icon: Icons.home, 
              label: "Home", 
              isSelected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            NavBarItem(
              icon: Icons.calendar_today, 
              label: "My Schedule",
              isSelected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            NavBarItem(
              icon: Icons.monitor_heart, 
              label: "Baby Tracker",
              isSelected: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            NavBarItem(
              icon: Icons.medical_services, 
              label: "Health Help",
              isSelected: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
            NavBarItem(
              icon: Icons.people, 
              label: "Community",
              isSelected: _currentIndex == 4,
              onTap: () => setState(() => _currentIndex = 4),
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? imagePath;

  const FeatureCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.imagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            imagePath != null 
                ? Image.asset(
                    imagePath!,
                    height: 80,
                    width: 80,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    icon,
                    size: 64,
                    color: Color(0xFF1E6091),
                  ),
            SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E6091),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const NavBarItem({
    Key? key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Color(0xFF1E6091) : Colors.grey,
            size: 24,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: isSelected ? Color(0xFF1E6091) : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
} 