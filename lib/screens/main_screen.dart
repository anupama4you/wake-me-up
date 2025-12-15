import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alarm.dart';
import '../models/tier.dart';
import '../services/alarm_storage_service.dart';
import '../services/geofence_service.dart';
import '../services/location_service.dart';
import '../services/tier_service.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';
import '../utils/trip_distance_calculator.dart';
import 'home_screen.dart';
import 'map_view_screen.dart';
import 'settings_screen.dart';
import 'map_screen.dart';
import 'paywall_screen.dart';

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

  // Auth state
  final _authService = AuthService();
  StreamSubscription<User?>? _authStateSubscription;
  User? _currentUser;

  // Controller for SettingsScreen to check unsaved changes
  SettingsScreenController? _settingsController;

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect when app resumes
    WidgetsBinding.instance.addObserver(this);
    _initializeAndLoadAlarms();
    // Setup auth state listener
    _setupAuthStateListener();
    // Permissions are now requested during onboarding only
  }

  /// Setup authentication state listener
  void _setupAuthStateListener() {
    _currentUser = _authService.currentUser;
    User? previousUser = _currentUser;

    _authStateSubscription = _authService.authStateChanges.listen((user) {
      if (!mounted) return;

      // Only show messages if there was an actual state change (not initial load)
      final bool isActualChange = previousUser != user;

      setState(() {
        _currentUser = user;
      });

      if (isActualChange && mounted) {
        if (user == null && previousUser != null) {
          // User signed out (was signed in, now not) - show message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        } else if (user != null && previousUser == null) {
          // User signed in (was not signed in, now is) - show welcome
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.email ?? "User"}!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      previousUser = user;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Lifecycle state changes are monitored but no automatic permission checks
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed');
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Clear callback when screen is disposed
    _geofenceService?.onAlarmCompleted = null;
    // Cancel auth state subscription
    _authStateSubscription?.cancel();
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

  Future<void> _onItemTapped(int index) async {
    // If trying to leave settings screen (index 2), check for unsaved changes
    if (_selectedIndex == 2 && index != 2 && _settingsController != null) {
      if (_settingsController!.hasUnsavedChanges()) {
        // Show dialog and check if user wants to proceed
        final canLeave = await _settingsController!.handleWillPop();
        if (!canLeave) {
          return; // User cancelled, stay on settings
        }
      }
    }

    // Navigation allowed, switch tab
    setState(() => _selectedIndex = index);
  }

  Future<void> _toggleAlarm(String id, bool active) async {
    final alarm = _alarms.firstWhere((a) => a.id == id);
    final previousState = alarm.isActive;

    // If activating, enforce tier limits BEFORE making any changes
    if (active) {
      // CRITICAL: Check active alarm count limit FIRST
      final currentActiveCount = _alarms.where((a) => a.isActive && a.id != id).length;
      final alarmCountError = await TierService.canActivateAlarm(currentActiveCount);
      if (alarmCountError != null) {
        // Show upgrade dialog for alarm count limit
        if (!mounted) return;
        await _showAlarmLimitDialog(alarmCountError);
        return;
      }

      // Then check trip distance limit
      try {
        final currentPosition = await Geolocator.getCurrentPosition();
        final distanceKm = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          alarm.latitude,
          alarm.longitude,
        ) / 1000;

        final distanceError = await TierService.canCreateAlarmAtDistance(distanceKm);
        if (distanceError != null) {
          // Show upgrade dialog for distance limit
          if (!mounted) return;
          await _showDistanceLimitDialog(distanceError, distanceKm);
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Could not validate trip distance: $e');
        // Continue anyway - don't block alarm activation if location check fails
      }
    }

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

    // Permission granted - now check tier limits
    // debugPrint('🔄 MainScreen: Checking tier limits before creating alarm...');

    // CRITICAL: Check if user can create another active alarm
    final currentActiveCount = _alarms.where((a) => a.isActive).length;
    final alarmCountError = await TierService.canActivateAlarm(currentActiveCount);
    if (alarmCountError != null) {
      if (!mounted) return;
      await _showAlarmLimitDialog(alarmCountError);
      return; // Block alarm creation
    }

    // Tier limits passed - proceed to create alarm
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

  /// Show alarm count limit dialog
  Future<void> _showAlarmLimitDialog(String message) async {
    final currentTier = await TierService.getCurrentTier();
    final limits = await TierService.getTierLimits();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Theme.of(context).primaryColor, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Active Alarm Limit')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.alarm, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Current Plan: ${currentTier.displayName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Active Alarms: ${limits.formattedAlarmLimit}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaywallScreen(),
                ),
              );
            },
            child: const Text('Upgrade Plan'),
          ),
        ],
      ),
    );
  }

  /// Show trip distance limit dialog
  Future<void> _showDistanceLimitDialog(String message, double distanceKm) async {
    final currentTier = await TierService.getCurrentTier();
    final requiredTier = TripDistanceCalculator.getRequiredTier(distanceKm);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Theme.of(context).primaryColor, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Trip Distance Limit')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Trip Distance: ${TripDistanceCalculator.formatDistance(distanceKm)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Required Plan: ${requiredTier.displayName}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaywallScreen(),
                ),
              );
            },
            child: Text('Upgrade to ${requiredTier.displayName}'),
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

    // Create a unique key based on alarm states to force widget updates
    final activeAlarmIds = _alarms.where((a) => a.isActive).map((a) => a.id).join(',');
    final alarmKey = '${_alarms.length}-$activeAlarmIds';

    final screens = [
      HomeScreen(
        key: ValueKey(alarmKey), // Force rebuild when alarms or active states change
        alarms: _alarms,
        onToggleAlarm: _toggleAlarm,
        onDeleteAlarm: _deleteAlarm,
        onAddAlarm: _handleAddAlarm,
        onRefreshNeeded: _loadAlarms, // Reload alarms when edit completes
      ),
      MapViewScreen(alarms: _alarms),
      SettingsScreen(
        onSettingsApplied: _loadAlarms,
        onControllerCreated: (controller) {
          _settingsController = controller;
        },
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
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
}
