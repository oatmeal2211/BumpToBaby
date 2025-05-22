import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bumptobaby/services/health_schedule_service.dart';
import 'package:bumptobaby/models/health_schedule.dart';
import 'package:bumptobaby/screens/health_schedule_screen.dart';
import 'package:bumptobaby/screens/health_survey_screen.dart';

class SmartHealthTrackerScreen extends StatefulWidget {
  const SmartHealthTrackerScreen({Key? key}) : super(key: key);

  @override
  State<SmartHealthTrackerScreen> createState() => _SmartHealthTrackerScreenState();
}

class _SmartHealthTrackerScreenState extends State<SmartHealthTrackerScreen> {
  final HealthScheduleService _healthScheduleService = HealthScheduleService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  HealthSchedule? _schedule;

  @override
  void initState() {
    super.initState();
    _loadHealthSchedule();
  }

  Future<void> _loadHealthSchedule() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final schedule = await _healthScheduleService.getLatestHealthSchedule(user.uid);
        setState(() {
          _schedule = schedule;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading health schedule: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Smart Health Tracker',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFFF8AFAF),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_schedule != null) {
      // If we have a schedule, navigate to the schedule screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HealthScheduleScreen(schedule: _schedule!),
          ),
        );
      });
      return Container(); // This will be replaced by the navigation
    }

    // If no schedule exists, show the create schedule option
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 100,
            color: Color(0xFFF8AFAF),
          ),
          SizedBox(height: 20),
          Text(
            'No Health Schedule Found',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Create a personalized health schedule for you and your baby',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HealthSurveyScreen(),
                ),
              ).then((value) {
                // Refresh after returning from survey
                _loadHealthSchedule();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF8AFAF),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Create Health Schedule',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 