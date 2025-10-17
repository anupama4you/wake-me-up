import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../services/alarm_storage_service.dart';
import '../services/geofence_service.dart';
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

      debugPrint('🔄 MainScreen: Loading alarms from storage...');
      final alarms = AlarmStorageService.getAllAlarms();
      debugPrint('🔄 MainScreen: Loaded ${alarms.length} alarms from storage');

      setState(() {
        _alarms = alarms;
        _isLoading = false;
      });
      debugPrint('✅ MainScreen: State updated with ${_alarms.length} alarms');

      // Sync geofences with active alarms (restore geofencing after app restart)
      try {
        final geofenceService = GeofenceAlarmService();
        await geofenceService.initialize();
        await geofenceService.syncGeofencesWithAlarms();
        debugPrint('✅ Geofences synced with active alarms');
      } catch (e) {
        debugPrint('⚠️ Error syncing geofences: $e');
      }
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

    // Handle geofencing based on alarm state
    try {
      final geofenceService = GeofenceAlarmService();
      await geofenceService.initialize();

      if (active) {
        // Start geofencing for the activated alarm
        final alarm = _alarms.firstWhere((a) => a.id == id);
        await geofenceService.startGeofencing(alarm);
        debugPrint('✅ Geofencing started for: ${alarm.name}');
      } else {
        // Stop geofencing for the deactivated alarm
        await geofenceService.stopGeofencing(id);
        debugPrint('🛑 Geofencing stopped for alarm: $id');
      }
    } catch (e) {
      debugPrint('⚠️ Geofencing toggle error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geofencing error: $e'),
            backgroundColor: Colors.orange,
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

    // Stop geofencing for deleted alarm
    try {
      final geofenceService = GeofenceAlarmService();
      await geofenceService.stopGeofencing(id);
      debugPrint('🛑 Geofencing stopped for deleted alarm: $id');
    } catch (e) {
      debugPrint('⚠️ Error stopping geofencing: $e');
    }
  }

  Future<void> _handleAddAlarm() async {
    debugPrint('🔄 MainScreen: Navigating to add alarm...');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );

    debugPrint('🔄 MainScreen: Returned from add alarm with result: $result');

    // Always reload alarms from storage when returning
    // (alarm may have been added, or an active alarm may have been stopped)
    await _loadAlarms();

    // Show success message if an alarm was added
    if (result != null && result is Alarm && mounted) {
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