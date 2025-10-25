import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofencing_api/geofencing_api.dart';
import '../models/alarm.dart';
import 'alarm_storage_service.dart';
import 'alarm_sound_service.dart';

/// Service to manage background geofencing for location-based alarms
/// This service runs even when the app is closed or terminated
class GeofenceAlarmService {
  static final GeofenceAlarmService _instance = GeofenceAlarmService._internal();
  factory GeofenceAlarmService() => _instance;
  GeofenceAlarmService._internal();

  // Geofencing instance
  final _geofencing = Geofencing.instance;

  // Local notifications instance
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Alarm sound service instance
  final _alarmSoundService = AlarmSoundService();

  // Stream controller for geofence events
  final StreamController<GeofenceRegion> _geofenceStreamController =
      StreamController<GeofenceRegion>.broadcast();

  bool _isInitialized = false;
  bool _isRunning = false;

  /// Initialize the geofence service
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔔 Initializing GeofenceAlarmService...');

    // Initialize local notifications
    await _initializeNotifications();

    // Set up geofencing options
    _geofencing.setup(
      interval: 10000, // Check location every 10 seconds (optimized for battery)
      accuracy: 100, // Accuracy in meters
      statusChangeDelay: 10000, // 10 second delay for status changes
      allowsMockLocation: false, // Don't allow mock locations
      printsDebugLog: true, // Print debug logs
    );

    // Set up geofence callbacks
    _geofencing.addGeofenceStatusChangedListener(_onGeofenceStatusChanged);
    _geofencing.addLocationChangedListener(_onLocationChanged);
    _geofencing.addLocationServicesStatusChangedListener(
        _onLocationServicesStatusChanged);
    _geofencing.addGeofenceErrorCallbackListener(_onError);

    _isInitialized = true;
    debugPrint('✅ GeofenceAlarmService initialized');
  }

  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+ and iOS
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    // Create notification channels for Android
    if (Platform.isAndroid) {
      // Channel for alarm triggers (high priority)
      const alarmChannel = AndroidNotificationChannel(
        'alarm_geofence_channel',
        'Location Alarms',
        description: 'Notifications for location-based alarms',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      // Channel for ongoing monitoring (minimum priority, persistent, silent)
      const monitoringChannel = AndroidNotificationChannel(
        'alarm_monitoring_channel',
        'Active Alarm Monitoring',
        description: 'Shows when location alarms are actively monitoring',
        importance: Importance.min, // Minimum - stays in tray, no alerts
        playSound: false,
        enableVibration: false,
        showBadge: false,
        enableLights: false,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(alarmChannel);
      await androidPlugin?.createNotificationChannel(monitoringChannel);
    }
  }

  /// Start geofencing for an alarm
  Future<bool> startGeofencing(Alarm alarm) async {
    if (!_isInitialized) {
      await initialize();
    }

    debugPrint('📍 Starting geofencing for alarm: ${alarm.name}');

    try {
      // Check and request location permission
      final permission = await _geofencing.getLocationPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final requestedPermission = await _geofencing.requestLocationPermission();
        if (requestedPermission == LocationPermission.denied ||
            requestedPermission == LocationPermission.deniedForever) {
          debugPrint('❌ Location permission denied');
          return false;
        }
      }

      // Create circular geofence region from alarm
      final region = GeofenceRegion.circular(
        id: alarm.id,
        data: {'name': alarm.name, 'address': alarm.address},
        center: LatLng(alarm.latitude, alarm.longitude),
        radius: alarm.radius,
        loiteringDelay: 60000, // 1 minute
      );

      // Add region
      _geofencing.addRegion(region);

      // Start the service if not already running
      if (!_isRunning) {
        await _geofencing.start();
        _isRunning = true;
      }

      // Show persistent notification
      await _showPersistentNotification();

      debugPrint('✅ Geofencing started for: ${alarm.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting geofencing: $e');
      return false;
    }
  }

  /// Stop geofencing for an alarm
  Future<void> stopGeofencing(String alarmId) async {
    debugPrint('🛑 Stopping geofencing for alarm: $alarmId');

    try {
      // Stop alarm sound if this alarm is currently playing
      if (_alarmSoundService.currentAlarmId == alarmId) {
        await _alarmSoundService.stopAlarm();
        debugPrint('🔇 Alarm sound stopped for: $alarmId');
      }

      _geofencing.removeRegionById(alarmId);
      debugPrint('✅ Geofence removed for: $alarmId');

      // Update or remove persistent notification
      if (_geofencing.regions.isEmpty && _isRunning) {
        await _geofencing.stop();
        _isRunning = false;
        await _cancelPersistentNotification();
        debugPrint('🛑 Geofence service stopped (no active geofences)');
      } else {
        // Update notification to reflect remaining alarms
        await _showPersistentNotification();
      }
    } catch (e) {
      debugPrint('❌ Error stopping geofencing: $e');
    }
  }

  /// Stop all geofencing
  Future<void> stopAllGeofencing() async {
    debugPrint('🛑 Stopping all geofencing...');

    try {
      // Stop any playing alarm sound
      await _alarmSoundService.stopAlarm();

      if (_isRunning) {
        await _geofencing.stop(keepsRegions: false);
        _isRunning = false;
      }

      // Cancel persistent notification
      await _cancelPersistentNotification();

      debugPrint('✅ All geofencing stopped');
    } catch (e) {
      debugPrint('❌ Error stopping all geofencing: $e');
    }
  }

  /// Sync geofences with stored alarms
  Future<void> syncGeofencesWithAlarms() async {
    debugPrint('🔄 Syncing geofences with stored alarms...');

    try {
      // Get all active alarms from storage
      final activeAlarms = AlarmStorageService.getActiveAlarms();

      // Stop service to clear existing geofences
      if (_isRunning) {
        await _geofencing.stop(keepsRegions: false);
        _isRunning = false;
      }

      // Add geofences for all active alarms
      for (final alarm in activeAlarms) {
        await startGeofencing(alarm);
      }

      // Show or update persistent notification
      if (activeAlarms.isNotEmpty) {
        await _showPersistentNotification();
      } else {
        await _cancelPersistentNotification();
      }

      debugPrint('✅ Synced ${activeAlarms.length} active alarms');
    } catch (e) {
      debugPrint('❌ Error syncing geofences: $e');
    }
  }

  /// Callback when geofence status changes
  Future<void> _onGeofenceStatusChanged(
    GeofenceRegion region,
    GeofenceStatus status,
    Location location,
  ) async {
    debugPrint('🎯 Geofence status changed:');
    debugPrint('  - Region ID: ${region.id}');
    debugPrint('  - Status: ${status.name}');
    debugPrint('  - Location: ${location.latitude}, ${location.longitude}');

    // Handle entering geofence (alarm triggered)
    if (status == GeofenceStatus.enter) {
      await _handleAlarmTriggered(region.id);
    }

    // Broadcast event
    _geofenceStreamController.add(region);
  }

  /// Callback when location changes
  void _onLocationChanged(Location location) {
    debugPrint('📍 Location changed: ${location.latitude}, ${location.longitude}');

    // Update persistent notification with live distance info
    _updatePersistentNotificationWithDistance(location);
  }

  /// Callback when location services status changes
  void _onLocationServicesStatusChanged(LocationServicesStatus status) {
    debugPrint('🌍 Location services status: ${status.name}');

    if (status == LocationServicesStatus.disabled) {
      _showNotification(
        'Location Services Disabled',
        'Please enable location services to use location alarms',
        importance: Importance.high,
      );
    }
  }

  /// Callback when error occurs
  void _onError(Object error, StackTrace stackTrace) {
    debugPrint('❌ Geofence error: $error');
    debugPrint('Stack trace: $stackTrace');
  }

  /// Handle alarm triggered (user entered geofence)
  Future<void> _handleAlarmTriggered(String alarmId) async {
    debugPrint('⏰ Alarm triggered: $alarmId');

    try {
      // Get alarm details from storage
      final alarm = AlarmStorageService.getAlarm(alarmId);
      if (alarm == null) {
        debugPrint('⚠️ Alarm not found in storage: $alarmId');
        return;
      }

      // Show notification
      await _showAlarmNotification(alarm);

      // Start playing alarm sound with vibration
      await _alarmSoundService.startAlarm(
        alarmId: alarm.id,
        soundLevel: alarm.soundLevel,
      );

      debugPrint('🔊 Alarm sound and vibration started');

    } catch (e) {
      debugPrint('❌ Error handling alarm trigger: $e');
    }
  }

  /// Show alarm notification
  Future<void> _showAlarmNotification(Alarm alarm) async {
    // Determine sound level
    final soundLevel = alarm.soundLevel.toLowerCase();
    final importance = soundLevel == 'loud'
        ? Importance.max
        : soundLevel == 'medium'
            ? Importance.high
            : Importance.defaultImportance;

    final priority = soundLevel == 'loud'
        ? Priority.max
        : soundLevel == 'medium'
            ? Priority.high
            : Priority.defaultPriority;

    // Android notification details
    final androidDetails = AndroidNotificationDetails(
      'alarm_geofence_channel',
      'Location Alarms',
      channelDescription: 'Notifications for location-based alarms',
      importance: importance,
      priority: priority,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // Show as full screen
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show notification
    await _notificationsPlugin.show(
      alarm.id.hashCode,
      '⏰ ${alarm.name}',
      'You have arrived at ${alarm.address}',
      details,
      payload: alarm.id,
    );

    debugPrint('✅ Notification shown for alarm: ${alarm.name}');
  }

  /// Show persistent notification for active alarms
  Future<void> _showPersistentNotification() async {
    final activeAlarms = AlarmStorageService.getActiveAlarms();

    if (activeAlarms.isEmpty) {
      await _cancelPersistentNotification();
      return;
    }

    final alarmCount = activeAlarms.length;
    final title = alarmCount == 1
        ? 'Location Alarm Active'
        : '$alarmCount Location Alarms Active';

    final body = alarmCount == 1
        ? 'Monitoring: ${activeAlarms.first.name}'
        : 'Tap to view active alarms';

    // Android notification details - ongoing/persistent
    const androidDetails = AndroidNotificationDetails(
      'alarm_monitoring_channel',
      'Active Alarm Monitoring',
      channelDescription: 'Shows when location alarms are actively monitoring',
      importance: Importance.min, // Minimum importance - no heads-up
      priority: Priority.min, // Minimum priority - stays in tray only
      playSound: false,
      enableVibration: false,
      ongoing: true, // Makes it persistent
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      onlyAlertOnce: true, // Don't alert on updates
      silent: true, // Completely silent
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
      threadIdentifier: 'alarm_monitoring', // Group notifications
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      999999, // Fixed ID for persistent notification
      title,
      body,
      details,
    );

    debugPrint('✅ Persistent notification shown: $alarmCount active alarm(s)');
  }

  /// Update persistent notification with live distance information
  void _updatePersistentNotificationWithDistance(Location currentLocation) {
    final activeAlarms = AlarmStorageService.getActiveAlarms();

    if (activeAlarms.isEmpty) return;

    // For single alarm, calculate and show distance
    if (activeAlarms.length == 1) {
      final alarm = activeAlarms.first;
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        alarm.latitude,
        alarm.longitude,
      );

      final distanceText = _formatDistance(distance);
      final title = 'Location Alarm Active';
      final body = '${alarm.name} • $distanceText away';

      // Calculate progress (0-100) based on distance vs radius
      final progress = _calculateProgress(distance, alarm.radius);

      // Android notification with progress bar
      final androidDetails = AndroidNotificationDetails(
        'alarm_monitoring_channel',
        'Active Alarm Monitoring',
        channelDescription: 'Shows when location alarms are actively monitoring',
        importance: Importance.min, // Minimum importance - no heads-up
        priority: Priority.min, // Minimum priority - stays in tray only
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.service,
        visibility: NotificationVisibility.public,
        showProgress: true,
        maxProgress: 100,
        progress: progress,
        onlyAlertOnce: true, // Don't alert on updates
        silent: true, // Completely silent updates
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: false,
        threadIdentifier: 'alarm_monitoring', // Group notifications
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Update notification silently - same ID ensures it updates in place
      _notificationsPlugin.show(
        999999,
        title,
        body,
        details,
      );
    } else {
      // For multiple alarms, show count and closest distance
      double? closestDistance;
      String? closestAlarmName;

      for (final alarm in activeAlarms) {
        final distance = _calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          alarm.latitude,
          alarm.longitude,
        );

        if (closestDistance == null || distance < closestDistance) {
          closestDistance = distance;
          closestAlarmName = alarm.name;
        }
      }

      final title = '${activeAlarms.length} Location Alarms Active';
      final body = closestDistance != null
          ? 'Closest: $closestAlarmName • ${_formatDistance(closestDistance)} away'
          : 'Monitoring ${activeAlarms.length} locations';

      const androidDetails = AndroidNotificationDetails(
        'alarm_monitoring_channel',
        'Active Alarm Monitoring',
        channelDescription: 'Shows when location alarms are actively monitoring',
        importance: Importance.min, // Minimum importance - no heads-up
        priority: Priority.min, // Minimum priority - stays in tray only
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.service,
        visibility: NotificationVisibility.public,
        onlyAlertOnce: true, // Don't alert on updates
        silent: true, // Completely silent updates
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: false,
        threadIdentifier: 'alarm_monitoring', // Group notifications
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Update notification silently - same ID ensures it updates in place
      _notificationsPlugin.show(
        999999,
        title,
        body,
        details,
      );
    }
  }

  /// Calculate distance between two coordinates in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Format distance for display
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  /// Calculate progress percentage (0-100) based on distance vs radius
  /// Returns higher percentage as you get closer
  int _calculateProgress(double currentDistance, double targetRadius) {
    // Use 5x the radius as the "max distance" for progress calculation
    final maxDistance = targetRadius * 5;

    if (currentDistance >= maxDistance) {
      return 0; // Very far away
    } else if (currentDistance <= targetRadius) {
      return 100; // Inside the geofence
    } else {
      // Linear progress from max distance to radius
      final progress = ((maxDistance - currentDistance) / (maxDistance - targetRadius) * 100);
      return progress.clamp(0, 100).round();
    }
  }

  /// Cancel persistent notification
  Future<void> _cancelPersistentNotification() async {
    await _notificationsPlugin.cancel(999999);
    debugPrint('✅ Persistent notification cancelled');
  }

  /// Show generic notification
  Future<void> _showNotification(
    String title,
    String body, {
    Importance importance = Importance.defaultImportance,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'alarm_geofence_channel',
      'Location Alarms',
      importance: importance,
      priority: importance == Importance.max ? Priority.max : Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Callback when notification is tapped
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // You can navigate to a specific screen here if needed
  }

  /// Get stream of geofence events
  Stream<GeofenceRegion> get geofenceStream => _geofenceStreamController.stream;

  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Get list of active geofence regions
  Set<GeofenceRegion> get activeRegions => _geofencing.regions;

  /// Dispose resources
  void dispose() {
    _geofenceStreamController.close();
  }
}
