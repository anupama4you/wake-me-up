import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../services/alarm_storage_service.dart';
import 'home_screen.dart';
import 'map_view_screen.dart';
import 'settings_screen.dart';
import 'map_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<Alarm> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadAlarms();
  }

  // Initialize Hive and load alarms
  Future<void> _initializeAndLoadAlarms() async {
    setState(() => _isLoading = true);

    // Small delay to ensure platform channels are ready
    await Future.delayed(const Duration(milliseconds: 100));

    // First, initialize Hive storage
    try {
      debugPrint('🔧 Initializing AlarmStorageService...');
      await AlarmStorageService.init();
      debugPrint('✅ AlarmStorageService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize AlarmStorageService: $e');
      setState(() {
        _alarms = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage init failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _initializeAndLoadAlarms(),
            ),
          ),
        );
      }
      return;
    }

    // Then load alarms
    await _loadAlarms();
  }

  // Load alarms from local storage
  Future<void> _loadAlarms() async {
    setState(() => _isLoading = true);
    try {
      // Check if storage is initialized
      if (!AlarmStorageService.isInitialized) {
        setState(() {
          _alarms = [];
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage not initialized. Alarms will not be saved.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final alarms = AlarmStorageService.getAllAlarms();
      setState(() {
        _alarms = alarms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _alarms = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading alarms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _toggleAlarm(String id, bool active) async {
    setState(() {
      for (var alarm in _alarms) {
        if (alarm.id == id) {
          alarm.isActive = active;
        } else if (active) {
          alarm.isActive = false;
        }
      }
    });

    // Save changes to storage
    try {
      for (var alarm in _alarms) {
        await AlarmStorageService.updateAlarm(alarm);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating alarm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAlarm(String id) async {
    setState(() => _alarms.removeWhere((a) => a.id == id));

    // Delete from storage
    try {
      await AlarmStorageService.deleteAlarm(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting alarm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAddAlarm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );

    // Reload alarms from storage (they're saved in AlarmSettingsScreen)
    if (result != null && result is Alarm) {
      await _loadAlarms();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Alarm "${result.name}" added successfully'),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while loading alarms
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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