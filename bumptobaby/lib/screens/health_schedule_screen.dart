import 'package:bumptobaby/models/health_schedule.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HealthScheduleScreen extends StatefulWidget {
  final HealthSchedule schedule;

  const HealthScheduleScreen({Key? key, required this.schedule}) : super(key: key);

  @override
  State<HealthScheduleScreen> createState() => _HealthScheduleScreenState();
}

class _HealthScheduleScreenState extends State<HealthScheduleScreen> {
  late List<HealthScheduleItem> _items;
  
  @override
  void initState() {
    super.initState();
    _items = List.from(widget.schedule.items);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Schedule'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // You can add category sections here
        ],
      ),
    );
  }

  Widget _buildScheduleItem(HealthScheduleItem item) {
    final bool isPast = item.scheduledDate.isBefore(DateTime.now());
    final bool isToday = item.scheduledDate.day == DateTime.now().day &&
        item.scheduledDate.month == DateTime.now().month &&
        item.scheduledDate.year == DateTime.now().year;

    Color statusColor;
    if (item.isCompleted) {
      statusColor = Colors.green;
    } else if (isToday) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.blue;
    }

    String statusText;
    if (item.isCompleted) {
      statusText = 'Completed';
    } else if (isToday) {
      statusText = 'Today';
    } else {
      statusText = 'Upcoming';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8.0),
            Text(item.description),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16.0, color: statusColor),
                const SizedBox(width: 4.0),
                Text(
                  _formatDate(item.scheduledDate),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 12.0),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Checkbox(
          value: item.isCompleted,
          activeColor: Colors.green,
          onChanged: (_) => _toggleItemCompletion(item),
        ),
      ),
    );
  }

  // Format date as a string
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  // Toggle completion status of an item
  void _toggleItemCompletion(HealthScheduleItem item) {
    final int index = _items.indexWhere(
      (i) => i.title == item.title && i.scheduledDate == item.scheduledDate
    );
    
    if (index != -1) {
      setState(() {
        _items[index] = item.copyWith(isCompleted: !item.isCompleted);
      });
    }
  }

  // Filter items by category
  List<HealthScheduleItem> _getItemsByCategory(String category) {
    final now = DateTime.now();
    return _items
        .where((item) => 
            item.category == category && 
            (item.scheduledDate.isAfter(now) || 
             (item.scheduledDate.year == now.year && 
              item.scheduledDate.month == now.month && 
              item.scheduledDate.day == now.day)))
        .toList();
  }
}