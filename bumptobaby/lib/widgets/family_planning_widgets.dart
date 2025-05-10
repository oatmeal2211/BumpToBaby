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
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Icon(icon, color: color),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (gender.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 4),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: gender == 'Female' ? Colors.pink.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              gender,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: gender == 'Female' ? Colors.pink : Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      effectiveness,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        _buildGoalOption(
          context,
          'want_more_children',
          'I want to have more children',
          'We\'ll help you track your fertile days and provide conception tips',
          Icons.child_friendly,
          Colors.green,
        ),
        SizedBox(height: 12),
        _buildGoalOption(
          context,
          'no_more_children',
          'I don\'t want any more children',
          'We\'ll show you contraceptive options and help you track your cycle',
          Icons.do_not_disturb,
          Colors.red,
        ),
        SizedBox(height: 12),
        _buildGoalOption(
          context,
          'undecided',
          'I\'m undecided / Not sure yet',
          'We\'ll provide balanced information to help you decide',
          Icons.help_outline,
          Colors.amber,
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
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: color,
                  ),
              ],
            ),
            if (isSelected) ...[
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.only(left: 44),
                child: Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
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
  final DateTime? lastInjection;

  const TrackingSummary({
    Key? key,
    this.lastPeriod,
    required this.fertileDays,
    this.nextPeriod,
    this.pillsTaken = 0,
    this.lastInjection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Tracking Summary',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            if (lastPeriod != null) ...[
              _buildInfoRow(
                'Last Period',
                dateFormat.format(lastPeriod!),
                Icons.calendar_today,
                Colors.red,
              ),
              SizedBox(height: 12),
            ],
            if (nextPeriod != null) ...[
              _buildInfoRow(
                'Next Period',
                dateFormat.format(nextPeriod!),
                Icons.event,
                Colors.pink,
              ),
              SizedBox(height: 12),
            ],
            if (fertileDays.isNotEmpty) ...[
              _buildInfoRow(
                'Fertile Window',
                '${dateFormat.format(fertileDays.first)} - ${dateFormat.format(fertileDays.last)}',
                Icons.favorite,
                Colors.green,
              ),
              SizedBox(height: 12),
            ],
            _buildInfoRow(
              'Pills Taken This Month',
              pillsTaken.toString(),
              Icons.medication,
              Colors.orange,
            ),
            SizedBox(height: 12),
            if (lastInjection != null) ...[
              _buildInfoRow(
                'Last Injection',
                dateFormat.format(lastInjection!),
                Icons.vaccines,
                Colors.purple,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
} 