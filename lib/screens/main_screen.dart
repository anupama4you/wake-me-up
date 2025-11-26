import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/alarm.dart';
import '../services/alarm_storage_service.dart';
import '../services/geofence_service.dart';
import '../services/location_service.dart';
import '../utils/error_handler.dart';
import 'home_screen.dart';
import 'map_view_screen.dart';
import 'settings_screen.dart';
import 'map_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Alarm> _alarms = [];
  bool _isLoading = true;
  GeofenceAlarmService? _geofenceService;
  bool _hasAlwaysPermission = true; // Assume true initially
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect when app resumes
    WidgetsBinding.instance.addObserver(this);
    _initializeAndLoadAlarms();
    _checkLocationPermission();
    // Request location permission on first launch
    _requestInitialPermissionIfNeeded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes from background (e.g., returning from Settings)
    // recheck location permission to update banner
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - rechecking location permission...');
      _checkLocationPermission();
    }
  }

  /// Request location permission on first app launch
  Future<void> _requestInitialPermissionIfNeeded() async {
    // Wait a bit for UI to load
    await Future.delayed(const Duration(milliseconds: 500));

    final permission = await Geolocator.checkPermission();
    debugPrint('📍 Initial permission check: $permission');

    // If permission is not determined (first launch), request it immediately
    if (permission == LocationPermission.denied) {
      if (!mounted) return;

      // Show welcome dialog explaining the permission
      final shouldRequest = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.waving_hand, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Flexible(child: Text('Welcome to WakeMeUp!')),
            ],
          ),
          content: const Text(
            'WakeMeUp helps you wake up when you arrive at your destination.\n\n'
            'To work properly, we need:\n\n'
            '✓ Location access (Always)\n'
            '✓ Background location tracking\n\n'
            'Tap "Get Started" to grant location permission.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Get Started'),
            ),
          ],
        ),
      );

      if (shouldRequest == true) {
        // Request permissions
        await LocationService.requestPermissionDetailed();
        // Update permission status
        await _checkLocationPermission();
      }
    }
  }

  /// Check if we have "Always" location permission (required for background geofencing)
  Future<void> _checkLocationPermission() async {
    if (!Platform.isIOS) {
      // On Android, check for background permission differently
      final hasBackground = await LocationService.hasBackgroundPermission();
      if (mounted) {
        setState(() {
          _hasAlwaysPermission = hasBackground;
          _permissionChecked = true;
        });
      }
      return;
    }

    // On iOS, check for "Always" permission
    final permission = await Geolocator.checkPermission();
    debugPrint('📍 Current location permission: $permission');

    if (mounted) {
      setState(() {
        _hasAlwaysPermission = permission == LocationPermission.always;
        _permissionChecked = true;
      });
    }
  }

  /// Request "Always" location permission
  Future<void> _requestAlwaysPermission() async {
    final result = await LocationService.requestPermissionDetailed();
    debugPrint('📍 Permission request result: $result');

    // Re-check permission status
    await _checkLocationPermission();

    if (!_hasAlwaysPermission && mounted) {
      // Still don't have permission - offer to open settings
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Background Location Required'),
          content: const Text(
            'For alarms to work when the app is closed or phone is locked, please:\n\n'
            '1. Open Settings\n'
            '2. Go to Privacy & Security > Location Services\n'
            '3. Find WakeMeUp\n'
            '4. Select "Always"\n\n'
            'Without this, alarms will only work while the app is open.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                LocationService.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Clear callback when screen is disposed
    _geofenceService?.onAlarmCompleted = null;
    super.dispose();
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

      // Then load alarms and sync geofences on initial load
      await _loadAlarms(syncGeofences: true);
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize AlarmStorageService: $e');
      debugPrint('Stack trace: $stackTrace');

      // Try to continue anyway - maybe storage will work later
      setState(() {
        _alarms = [];
        _isLoading = false;
      });

      // Show error to user but don't crash
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage initialization failed. Some features may not work.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Load alarms from local storage (without re-syncing geofences)
  Future<void> _loadAlarms({bool syncGeofences = false}) async {
    setState(() => _isLoading = true);
    try {
      // Check if storage is initialized
      if (!AlarmStorageService.isInitialized) {
        setState(() {
          _alarms = [];
          _isLoading = false;
        });
        // Storage not initialized - logged in console
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

      // Only sync geofences on initial load or when explicitly requested
      if (syncGeofences) {
        try {
          _geofenceService = GeofenceAlarmService();
          await _geofenceService!.initialize();

          // Set up callback to refresh UI when an alarm is triggered
          // Note: This callback only refreshes UI, doesn't re-sync geofences
          _geofenceService!.onAlarmCompleted = (alarmId) {
            debugPrint('🔔 MainScreen: Alarm $alarmId completed, refreshing UI...');
            if (mounted) {
              _loadAlarms(syncGeofences: false); // Don't sync, just refresh UI
            }
          };

          await _geofenceService!.syncGeofencesWithAlarms();
          debugPrint('✅ Geofences synced with active alarms');
        } catch (e) {
          debugPrint('⚠️ Error syncing geofences: $e');
        }
      }
    } catch (e) {
      setState(() {
        _alarms = [];
        _isLoading = false;
      });
      // Error loading alarms - logged in console
      debugPrint('❌ Error loading alarms: $e');
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _toggleAlarm(String id, bool active) async {
    final alarm = _alarms.firstWhere((a) => a.id == id);
    final previousState = alarm.isActive;

    // Optimistically update UI
    setState(() {
      alarm.isActive = active;
    });

    try {
      // Save changes to storage
      await AlarmStorageService.updateAlarm(alarm);

      // Handle geofencing based on alarm state
      // Reuse the existing service instance to maintain the callback
      if (_geofenceService == null) {
        _geofenceService = GeofenceAlarmService();
        await _geofenceService!.initialize();
        // Set up callback to refresh UI when an alarm is triggered
        _geofenceService!.onAlarmCompleted = (alarmId) {
          debugPrint('🔔 MainScreen: Alarm $alarmId completed, refreshing UI...');
          if (mounted) {
            _loadAlarms();
          }
        };
      }

      if (active) {
        // Start geofencing for the activated alarm
        final success = await _geofenceService!.startGeofencing(alarm);

        if (!success) {
          // Revert state on failure
          if (mounted) {
            setState(() {
              alarm.isActive = previousState;
            });
            await AlarmStorageService.updateAlarm(alarm);

            ErrorHandler.showErrorDialog(
              context,
              title: 'Failed to Activate Alarm',
              message: 'Could not activate geofencing. Please check:\n\n'
                  '• Location services are enabled\n'
                  '• Background location permission is granted ("Always Allow")\n'
                  '• The app has permission to run in background',
            );
          }
          return;
        }

        debugPrint('✅ Geofencing started for: ${alarm.name}');

        // Removed success notification - user can see alarm state in UI
      } else {
        // Stop geofencing for the deactivated alarm
        await _geofenceService!.stopGeofencing(id);
        debugPrint('🛑 Geofencing stopped for alarm: $id');

        // Get the latest alarm state from storage (it may have isCompleted=true from trigger)
        final latestAlarm = AlarmStorageService.getAlarm(id);
        if (latestAlarm != null) {
          // Reset completed status and set to inactive
          latestAlarm.isActive = false;
          latestAlarm.isCompleted = false;
          latestAlarm.completedAt = null;
          await AlarmStorageService.updateAlarm(latestAlarm);
          debugPrint('✅ Alarm deactivated and completed status reset');
        }

        if (!mounted) return;

        // Reload alarms to refresh UI with reset status
        await _loadAlarms();

        // Removed success notification - user can see alarm state in UI
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error toggling alarm: $e');
      debugPrint('Stack trace: $stackTrace');

      // Revert state on error
      if (mounted) {
        setState(() {
          alarm.isActive = previousState;
        });

        ErrorHandler.showErrorSnackBar(
          context,
          'Failed to ${active ? "activate" : "deactivate"} alarm. Please try again.',
        );
      }
    }
  }

  Future<void> _deleteAlarm(String id) async {
    final alarm = _alarms.firstWhere((a) => a.id == id);
    final alarmName = alarm.name;

    // Optimistically remove from UI
    setState(() => _alarms.removeWhere((a) => a.id == id));

    try {
      // Delete from storage
      await AlarmStorageService.deleteAlarm(id);

      // Stop geofencing for deleted alarm
      if (_geofenceService != null) {
        await _geofenceService!.stopGeofencing(id);
      }
      debugPrint('🛑 Geofencing stopped for deleted alarm: $id');

      if (mounted) {
        ErrorHandler.showSuccessSnackBar(
          context,
          'Alarm "$alarmName" deleted',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error deleting alarm: $e');
      debugPrint('Stack trace: $stackTrace');

      // Reload alarms to restore state on error
      await _loadAlarms();

      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Failed to delete alarm. Please try again.',
        );
      }
    }
  }

  Future<void> _handleAddAlarm() async {
    // CRITICAL: Check location permission before allowing alarm creation
    final permission = await Geolocator.checkPermission();
    final hasBackground = await LocationService.hasBackgroundPermission();

    debugPrint('📍 Permission check: $permission, hasBackground: $hasBackground');

    // Require "Always" permission (or background permission on Android)
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        !hasBackground) {

      // Show mandatory permission dialog
      final shouldRequest = await _showPermissionRequiredDialog();

      if (shouldRequest == true) {
        // Request permission
        final result = await LocationService.requestPermissionDetailed();
        debugPrint('📍 Permission request result: $result');

        // Check again after request
        final newPermission = await Geolocator.checkPermission();
        final newHasBackground = await LocationService.hasBackgroundPermission();

        if (newPermission == LocationPermission.denied ||
            newPermission == LocationPermission.deniedForever ||
            !newHasBackground) {
          // Still denied - show settings dialog
          await _showOpenSettingsDialog();
          return; // Don't allow alarm creation
        }
      } else {
        return; // User cancelled
      }
    }

    // Permission granted - proceed to create alarm
    debugPrint('🔄 MainScreen: Navigating to add alarm...');

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );

    debugPrint('🔄 MainScreen: Returned from add alarm with result: $result');

    // Always reload alarms from storage when returning
    // (alarm may have been added, or an active alarm may have been stopped)
    await _loadAlarms();

    // No app notification - phone notification will show if alarm is active
  }

  /// Show dialog explaining why location permission is required
  Future<bool?> _showPermissionRequiredDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Flexible(child: Text('Location Permission Required')),
          ],
        ),
        content: const Text(
          'WakeMeUp needs location permission to:\n\n'
          '✓ Detect when you arrive at your destination\n'
          '✓ Trigger alarms in the background\n'
          '✓ Work when the app is closed\n\n'
          'Please grant "Always Allow" permission to create alarms.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to open settings when permission is denied
  Future<void> _showOpenSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Flexible(child: Text('Permission Denied')),
          ],
        ),
        content: const Text(
          'Location permission is required to create alarms.\n\n'
          'Please:\n'
          '1. Open Settings\n'
          '2. Go to Location\n'
          '3. Select "Always Allow"\n\n'
          'Alarms cannot be created without this permission.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              LocationService.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while loading alarms
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      HomeScreen(
        alarms: _alarms,
        onToggleAlarm: _toggleAlarm,
        onDeleteAlarm: _deleteAlarm,
        onAddAlarm: _handleAddAlarm,
        onRefreshNeeded: _loadAlarms, // Reload alarms when edit completes
      ),
      MapViewScreen(alarms: _alarms),
      SettingsScreen(onSettingsApplied: _loadAlarms),
    ];

    return Scaffold(
      body: Column(
        children: [
          // Show permission warning banner if needed
          if (_permissionChecked && !_hasAlwaysPermission)
            _buildPermissionWarningBanner(),
          // Main content
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alarms',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
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

  /// Build a warning banner for missing "Always" location permission
  Widget _buildPermissionWarningBanner() {
    return Material(
      color: Colors.orange.shade700,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: _requestAlwaysPermission,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Platform.isIOS
                            ? 'Background Location Required'
                            : 'Background Permission Required',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Platform.isIOS
                            ? 'Tap to enable "Always" for alarms to work when locked'
                            : 'Tap to enable for alarms to work in background',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
