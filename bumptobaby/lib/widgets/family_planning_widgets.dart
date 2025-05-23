import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Widget for contraceptive option card
class ContraceptiveOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final String effectiveness;
  final IconData icon;
  final Color color;
  final String gender;
  final VoidCallback onTap;

  const ContraceptiveOptionCard({
    Key? key,
    required this.title,
    required this.description,
    required this.effectiveness,
    required this.icon,
    required this.color,
    this.gender = '',
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        if (gender.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 6),
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: gender == 'Female' ? Color(0xFFFF8AAE).withOpacity(0.15) : Color(0xFF6C9FFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              gender,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: gender == 'Female' ? Color(0xFFFF5C8A) : Color(0xFF6C9FFF),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      effectiveness,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Color(0xFF555555),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget for calendar day cell
class CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isPeriod;
  final bool isFertile;
  final bool isPillTaken;
  final bool isInjection;
  final VoidCallback onTap;

  const CalendarDayCell({
    Key? key,
    required this.date,
    this.isSelected = false,
    this.isPeriod = false,
    this.isFertile = false,
    this.isPillTaken = false,
    this.isInjection = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.transparent;
    Color textColor = Colors.black;
    
    if (isSelected) {
      backgroundColor = Colors.blue;
      textColor = Colors.white;
    } else if (isPeriod) {
      backgroundColor = Colors.red.withOpacity(0.2);
    } else if (isFertile) {
      backgroundColor = Colors.green.withOpacity(0.2);
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              date.day.toString(),
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isPillTaken)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (isInjection)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Widget for planning goal selection
class PlanningGoalSelector extends StatelessWidget {
  final String selectedGoal;
  final Function(String) onGoalSelected;

  const PlanningGoalSelector({
    Key? key,
    required this.selectedGoal,
    required this.onGoalSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What is your family planning goal?',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        SizedBox(height: 20),
        _buildGoalOption(
          context,
          'want_more_children',
          'I want to have more children',
          'We\'ll help you track your fertile days and provide conception tips',
          Icons.child_friendly,
          Color(0xFF7ED957), // Green
        ),
        SizedBox(height: 16),
        _buildGoalOption(
          context,
          'no_more_children',
          'I don\'t want any more children',
          'We\'ll show you contraceptive options and help you track your cycle',
          Icons.do_not_disturb,
          Color(0xFFFF5C8A), // Pink
        ),
        SizedBox(height: 16),
        _buildGoalOption(
          context,
          'undecided',
          'I\'m undecided / Not sure yet',
          'We\'ll provide balanced information to help you decide',
          Icons.help_outline,
          Color(0xFF6C9FFF), // Blue
        ),
      ],
    );
  }

  Widget _buildGoalOption(
    BuildContext context,
    String value,
    String label,
    String description,
    IconData icon,
    Color color,
  ) {
    final isSelected = selectedGoal == value;
    
    return InkWell(
      onTap: () => onGoalSelected(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: color,
                      size: 20,
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.only(left: 50),
                child: Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Widget for tracking summary
class TrackingSummary extends StatelessWidget {
  final DateTime? lastPeriod;
  final List<DateTime> fertileDays;
  final DateTime? nextPeriod;
  final int pillsTaken;
  final double? predictionConfidence;

  const TrackingSummary({
    Key? key,
    this.lastPeriod,
    required this.fertileDays,
    this.nextPeriod,
    this.pillsTaken = 0,
    this.predictionConfidence,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Card(
      elevation: 4,
      shadowColor: Color(0xFFFF8AAE).withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Tracking Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                if (predictionConfidence != null)
                  _buildConfidenceBadge(predictionConfidence!),
              ],
            ),
            SizedBox(height: 20),
            if (lastPeriod != null) ...[
              _buildInfoRow(
                'Last Period',
                dateFormat.format(lastPeriod!),
                Icons.calendar_today,
                Color(0xFFFF5C8A),
              ),
              SizedBox(height: 16),
            ],
            if (nextPeriod != null) ...[
              _buildInfoRow(
                'Next Period',
                dateFormat.format(nextPeriod!),
                Icons.event,
                Color(0xFFFF8AAE),
              ),
              SizedBox(height: 16),
            ],
            if (fertileDays.isNotEmpty) ...[
              _buildInfoRow(
                'Fertile Window',
                '${dateFormat.format(fertileDays.first)} - ${dateFormat.format(fertileDays.last)}',
                Icons.favorite,
                Color(0xFF7ED957),
              ),
              SizedBox(height: 16),
            ],
            _buildInfoRow(
              'Pills Taken This Month',
              pillsTaken.toString(),
              Icons.medication,
              Color(0xFFFF9D6C),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    String confidenceText;
    Color confidenceColor;
    
    if (confidence >= 0.8) {
      confidenceText = 'High';
      confidenceColor = Color(0xFF7ED957);
    } else if (confidence >= 0.6) {
      confidenceText = 'Medium';
      confidenceColor = Color(0xFFFF9D6C);
    } else {
      confidenceText = 'Low';
      confidenceColor = Color(0xFFFF5C8A);
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: confidenceColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: confidenceColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics,
            size: 16,
            color: confidenceColor,
          ),
          SizedBox(width: 6),
          Text(
            '$confidenceText Accuracy',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: confidenceColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 