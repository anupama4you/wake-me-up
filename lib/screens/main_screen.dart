import 'package:flutter/material.dart';
import '../models/alarm.dart';
import 'home_screen.dart';
import 'map_view_screen.dart';
import 'settings_screen.dart';
import 'map_screen.dart';
import 'active_alarm_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Alarm> _alarms = [];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _addAlarm(Alarm alarm) => setState(() => _alarms.add(alarm));

  void _toggleAlarm(String id, bool active) {
    setState(() {
      for (var alarm in _alarms) {
        if (alarm.id == id) {
          alarm.isActive = active;
        } else if (active) {
          alarm.isActive = false;
        }
      }
    });
  }

  void _deleteAlarm(String id) =>
      setState(() => _alarms.removeWhere((a) => a.id == id));

  Future<void> _handleAddAlarm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );

    if (result != null && result is Map) {
      final alarm = result['alarm'] as Alarm;
      final startNow = result['startNow'] as bool;

      // Add alarm to list immediately
      _addAlarm(alarm);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    startNow
                        ? 'Starting alarm for "${alarm.name}"'
                        : 'Alarm "${alarm.name}" saved',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(milliseconds: 1500),
          ),
        );

        // If start now, navigate to active alarm screen
        if (startNow) {
          // Brief delay so user sees the alarm was added
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ActiveAlarmScreen(alarm: alarm),
              ),
            );

            // Deactivate alarm when returning
            setState(() {
              final index = _alarms.indexWhere((a) => a.id == alarm.id);
              if (index != -1) {
                _alarms[index].isActive = false;
              }
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        alarms: _alarms,
        onToggleAlarm: _toggleAlarm,
        onDeleteAlarm: _deleteAlarm,
        onAddAlarm: _handleAddAlarm,
      ),
      MapViewScreen(alarms: _alarms),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alarms',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}