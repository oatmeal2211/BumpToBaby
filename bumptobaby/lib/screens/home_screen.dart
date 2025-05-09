import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bumptobaby/screens/nearest_clinic_screen.dart';
import 'package:bumptobaby/screens/health_survey_screen.dart';
import 'package:bumptobaby/screens/health_schedule_screen.dart';
import 'package:bumptobaby/screens/health_help_page.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  
  const HomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of screens for bottom navigation
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _buildHomeContent(),
      const HealthSurveyScreen(),
      Center(child: Text('Baby Tracker Page')), // Placeholder for Baby Tracker
      const HealthHelpPage(),
      Center(child: Text('Community Page')), // Placeholder for Community
    ];
  }

  Widget _buildHomeContent() {
    return Column(
          children: [
            // Top part with greeting and profile
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                'Hi ${widget.username}!',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E6091),
                    ),
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: AssetImage('lib/assets/images/BumpToBaby Logo.png'),
                  ),
                ],
              ),
            ),
            
            // Grid of features
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    // Vaccination Clinic Nearby
                    FeatureCard(
                      title: 'Vaccination\nClinic Nearby',
                      icon: Icons.local_hospital,
                      color: Color(0xFFAFDCF8),
                      onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NearestClinicMapScreen()),
                    );
                      },
                    ),
                    
                    // Smart Health Tracker
                    FeatureCard(
                      title: 'Smart Health\nTracker',
                      icon: Icons.favorite,
                      color: Color(0xFFF8AFAF),
                      onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HealthSurveyScreen()),
                    );
                      },
                    ),
                    
                    // Growth & Development
                    FeatureCard(
                      title: 'Growth &\nDevelopment',
                      icon: Icons.child_care,
                      color: Color(0xFFAFC9F8),
                      onTap: () {
                        // Navigate to growth tracker
                      },
                    ),
                    
                    // Nutrition & Meals
                    FeatureCard(
                      title: 'Nutrition &\nMeals',
                      icon: Icons.restaurant,
                      color: Color(0xFFF8AFAF),
                      onTap: () {
                        // Navigate to nutrition guide
                      },
                    ),
                    
                    // Audio/Visual Learning
                    FeatureCard(
                      title: 'Audio/Visual\nLearning',
                      icon: Icons.videocam,
                      color: Color(0xFFAFDCF8),
                      onTap: () {
                        // Navigate to learning materials
                      },
                    ),
                    
                    // Family Planning
                    FeatureCard(
                      title: 'Family\nPlanning',
                      icon: Icons.family_restroom,
                      color: Color(0xFFF8AFAF),
                      onTap: () {
                        // Navigate to family planning guides
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
        child: _screens[_selectedIndex],
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
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 0),
              child: NavBarItem(
                icon: Icons.home, 
                label: "Home", 
                isSelected: _selectedIndex == 0,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 1),
              child: NavBarItem(
                icon: Icons.calendar_today, 
                label: "My Schedule", 
                isSelected: _selectedIndex == 1,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 2),
              child: NavBarItem(
                icon: Icons.monitor_heart, 
                label: "Baby Tracker", 
                isSelected: _selectedIndex == 2,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 3),
              child: NavBarItem(
                icon: Icons.medical_services, 
                label: "Doctor Help", 
                isSelected: _selectedIndex == 3,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 4),
              child: NavBarItem(
                icon: Icons.people, 
                label: "Community", 
                isSelected: _selectedIndex == 4,
              ),
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

  const FeatureCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
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
            Icon(
              icon,
              size: 48,
              color: Color(0xFF1E6091),
            ),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
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

  const NavBarItem({
    Key? key,
    required this.icon,
    required this.label,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
} 