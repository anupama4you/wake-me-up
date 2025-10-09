import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../widgets/alarm_card.dart';
import 'active_alarm_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Alarm> alarms;
  final Function(String, bool) onToggleAlarm;
  final Function(String) onDeleteAlarm;
  final VoidCallback onAddAlarm;

  const HomeScreen({
    Key? key,
    required this.alarms,
    required this.onToggleAlarm,
    required this.onDeleteAlarm,
    required this.onAddAlarm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Alarms', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[600],
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey[50],
        child: alarms.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.alarm_off, size: 100, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No Alarms Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to create your first alarm',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...alarms.map((alarm) => AlarmCard(
              alarm: alarm,
              onToggle: (active) {
                if (active && !alarm.isActive) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ActiveAlarmScreen(alarm: alarm),
                    ),
                  ).then((_) => onToggleAlarm(alarm.id, false));
                } else {
                  onToggleAlarm(alarm.id, active);
                }
              },
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MapScreen(existingAlarm: alarm),
                  ),
                );

                if (result != null && result is Map) {
                  // Handle update - you'll need to add onUpdateAlarm callback
                  // For now, we'll just show a message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alarm updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              onDelete: () {
                // Show confirmation dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Alarm?'),
                    content: Text(
                        'Are you sure you want to delete "${alarm.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onDeleteAlarm(alarm.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Tip',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900])),
                        const SizedBox(height: 4),
                        Text(
                            'Toggle alarms to track your location in real-time',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue[700])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onAddAlarm,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add),
      ),
    );
  }
}