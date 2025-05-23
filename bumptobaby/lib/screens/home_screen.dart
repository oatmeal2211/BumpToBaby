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
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        // Greeting section constants
        final greetingContentHeight = 80.0; 
        final greetingVerticalMarginValue = 8.0;
        final greetingHorizontalMarginValue = 16.0;
        final greetingVerticalMargins = greetingVerticalMarginValue * 2; 
        final greetingTotalFootprint = greetingContentHeight + greetingVerticalMargins;

        // Grid Container constants
        final gridContainerBottomPadding = 16.0; 
        final gridMainAxisSpacing = 12.0;
        final gridCrossAxisSpacing = 12.0;
        final gridColumnCount = 2;
        final gridRowCount = 3;

        // Calculate height for the Grid Container
        final gridContainerHeight = availableHeight - greetingTotalFootprint;

        // Calculate dimensions for GridView items for childAspectRatio
        final totalHorizontalPaddingInGridContainer = greetingHorizontalMarginValue * 2; 
        final totalHorizontalSpacingBetweenItems = gridCrossAxisSpacing * (gridColumnCount - 1);
        final itemWidth = (constraints.maxWidth - totalHorizontalPaddingInGridContainer - totalHorizontalSpacingBetweenItems) / gridColumnCount;

        final heightAvailableForGridItemsArea = gridContainerHeight - gridContainerBottomPadding;
        final totalVerticalSpacingBetweenItems = gridMainAxisSpacing * (gridRowCount - 1);
        final itemHeight = (heightAvailableForGridItemsArea - totalVerticalSpacingBetweenItems) / gridRowCount;
        
        final calculatedChildAspectRatio = (itemHeight > 0 && itemWidth > 0) ? (itemWidth / itemHeight) : 1.0;

        return Column(
          children: [
            // Enhanced greeting section with container
            Container(
              height: greetingContentHeight, 
              margin: EdgeInsets.fromLTRB(
                greetingHorizontalMarginValue, 
                greetingVerticalMarginValue, 
                greetingHorizontalMarginValue, 
                greetingVerticalMarginValue
              ), 
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome back,',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          height: 1.2,
                          color: Color(0xFF1E6091).withOpacity(0.8),
                        ),
                      ),
                      Text(
                        _username,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          height: 1.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E6091),
                        ),
                      ),
                    ],
                  ),
                  Hero(
                    tag: 'profileAvatar',
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => ProfileScreen())
                        ).then((_) => _fetchUserData());
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF1E6091).withOpacity(0.1),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage: _profileImageUrl.isNotEmpty
                              ? NetworkImage(_profileImageUrl)
                              : AssetImage('lib/assets/images/BumpToBaby Logo.png') as ImageProvider,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Grid of features
            Container(
              height: gridContainerHeight, 
              padding: EdgeInsets.fromLTRB(16, 0, 16, gridContainerBottomPadding),
              child: GridView.count(
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: gridColumnCount,
                childAspectRatio: calculatedChildAspectRatio, 
                crossAxisSpacing: gridCrossAxisSpacing,
                mainAxisSpacing: gridMainAxisSpacing,
                children: [
                  FeatureCard(
                    title: 'Medical Services\nNearby',
                    icon: Icons.local_hospital,
                    color: Color(0xFFAFDCF8),
                    imagePath: 'lib/assets/images/vaccination.png',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NearestClinicMapScreen())),
                  ),
                  FeatureCard(
                    title: 'Smart Health\nTracker',
                    icon: Icons.favorite,
                    color: Color(0xFFF8AFAF),
                    imagePath: 'lib/assets/images/smart_health_tracker.png',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SmartHealthTrackerScreen())),
                  ),
                  FeatureCard(
                    title: 'Growth &\nDevelopment',
                    icon: Icons.child_care,
                    color: Color(0xFFAFDCF8),
                    imagePath: 'lib/assets/images/growth_development.png',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GrowthDevelopmentScreen())),
                  ),
                  FeatureCard(
                    title: 'Nutrition &\nMeals',
                    icon: Icons.restaurant,
                    color: Color(0xFFF8AFAF),
                    imagePath: 'lib/assets/images/nutrition_meals.png',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NutritionMealsScreen())),
                  ),
                  FeatureCard(
                    title: 'Audio/Visual\nLearning',
                    icon: Icons.videocam,
                    color: Color(0xFFAFDCF8),
                    imagePath: 'lib/assets/images/audio_visual.png',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AudioVisualLearningScreen())),
                  ),
                  FeatureCard(
                    title: 'Family\nPlanning',
                    icon: Icons.family_restroom,
                    color: Color(0xFFF8AFAF),
                    imagePath: 'lib/assets/images/family_planning.png',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyPlanningScreen())),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Color(0xFF1E6091),
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "My Schedule"),
            BottomNavigationBarItem(icon: Icon(Icons.monitor_heart), label: "Baby Tracker"),
            BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: "Health Help"),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: "Community"),
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
                    height: 60,
                    width: 60,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    icon,
                    size: 48,
                    color: Color(0xFF1E6091),
                  ),
            SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
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