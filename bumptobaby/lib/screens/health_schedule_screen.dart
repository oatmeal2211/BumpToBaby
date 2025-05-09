import 'package:flutter/material.dart';
import 'package:bumptobaby/models/health_schedule.dart';
import 'package:bumptobaby/services/health_schedule_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HealthScheduleScreen extends StatefulWidget {
  final HealthSchedule schedule;

  const HealthScheduleScreen({Key? key, required this.schedule}) : super(key: key);

  @override
  _HealthScheduleScreenState createState() => _HealthScheduleScreenState();
}

class _HealthScheduleScreenState extends State<HealthScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HealthScheduleService _healthScheduleService = HealthScheduleService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Filter items by category
  List<HealthScheduleItem> _getItemsByCategory(String category) {
    return widget.schedule.items
        .where((item) => item.category == category)
        .toList();
  }

  // Toggle completion status of an item
  Future<void> _toggleItemCompletion(HealthScheduleItem item) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to update items')),
        );
        return;
      }

      final updatedItem = item.copyWith(isCompleted: !item.isCompleted);
      await _healthScheduleService.updateScheduleItem(user.uid, updatedItem);

      // Update the local state
      setState(() {
        final index = widget.schedule.items.indexWhere((i) =>
            i.title == item.title &&
            i.scheduledDate.isAtSameMomentAs(item.scheduledDate) &&
            i.category == item.category);
        if (index != -1) {
          widget.schedule.items[index] = updatedItem;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Format date for display
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  // Build a list item for a schedule item
  Widget _buildScheduleItem(HealthScheduleItem item) {
    final bool isPast = item.scheduledDate.isBefore(DateTime.now());
    final bool isToday = item.scheduledDate.day == DateTime.now().day &&
        item.scheduledDate.month == DateTime.now().month &&
        item.scheduledDate.year == DateTime.now().year;

    Color statusColor;
    if (item.isCompleted) {
      statusColor = Colors.green;
    } else if (isPast) {
      statusColor = Colors.red;
    } else if (isToday) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.blue;
    }

    String statusText;
    if (item.isCompleted) {
      statusText = 'Completed';
    } else if (isPast) {
      statusText = 'Missed';
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

  // Build a tab for a category
  Widget _buildCategoryTab(String category) {
    final items = _getItemsByCategory(category);
    
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items in this category',
          style: TextStyle(fontSize: 16.0, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildScheduleItem(items[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Schedule', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005792))),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.pink[400],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.pink[400],
          tabs: const [
            Tab(text: 'Check-ups'),
            Tab(text: 'Vaccines'),
            Tab(text: 'Milestones'),
            Tab(text: 'Supplements'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Generated on ${_formatDate(widget.schedule.generatedAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14.0),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoryTab('checkup'),
                      _buildCategoryTab('vaccine'),
                      _buildCategoryTab('milestone'),
                      _buildCategoryTab('supplement'),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate back to the survey screen
          Navigator.pop(context);
          // The survey screen will be pushed from the main navigation
        },
        backgroundColor: Colors.pink[400],
        child: const Icon(Icons.refresh),
        tooltip: 'Take survey again',
      ),
    );
  }
} 