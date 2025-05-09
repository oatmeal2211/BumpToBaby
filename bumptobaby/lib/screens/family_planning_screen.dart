import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FamilyPlanningScreen extends StatelessWidget {
  const FamilyPlanningScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Family Planning',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFFF8AFAF),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom,
              size: 100,
              color: Color(0xFFF8AFAF),
            ),
            SizedBox(height: 20),
            Text(
              'Family Planning Resources',
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