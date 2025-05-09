import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GrowthDevelopmentScreen extends StatelessWidget {
  const GrowthDevelopmentScreen({Key? key}) : super(key: key);

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
        backgroundColor: Color(0xFFAFC9F8),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.child_care,
              size: 100,
              color: Color(0xFFAFC9F8),
            ),
            SizedBox(height: 20),
            Text(
              'Growth & Development Tracker',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Coming soon!',
              style: GoogleFonts.poppins(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 