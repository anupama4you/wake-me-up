import 'package:flutter/material.dart';
import '../models/alarm.dart';

class AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AlarmCard({
    Key? key,
    required this.alarm,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: alarm.isActive ? Colors.green : Colors.grey[300]!,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alarm.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(alarm.address,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                    alarm.isActive ? Colors.green[100] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    alarm.isActive ? 'ACTIVE' : 'SAVED',
                    style: TextStyle(
                      color: alarm.isActive
                          ? Colors.green[700]
                          : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.radio_button_checked,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${alarm.radius.toInt()}m radius',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                if (alarm.isActive) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.volume_up, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(alarm.soundLevel,
                      style:
                      TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ],
            ),
            if (alarm.isActive) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onToggle(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[600],
                        elevation: 0,
                      ),
                      child: const Text('Stop'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[600],
                        elevation: 0,
                      ),
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
            if (!alarm.isActive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: onEdit, child: const Text('Edit')),
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[600],
                      ),
                      child: const Text('Delete')),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
