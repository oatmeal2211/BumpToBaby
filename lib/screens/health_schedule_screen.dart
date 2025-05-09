// ... existing code ...
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

  // Filter items by category
  List<HealthScheduleItem> _getItemsByCategory(String category) {
    final now = DateTime.now();
    return widget.schedule.items
        .where((item) => 
            item.category == category && 
            (item.scheduledDate.isAfter(now) || 
             (item.scheduledDate.year == now.year && 
              item.scheduledDate.month == now.month && 
              item.scheduledDate.day == now.day)))
        .toList();
  }

  // Toggle completion status of an item
// ... existing code ...