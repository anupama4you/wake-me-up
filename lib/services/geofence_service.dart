import 'dart:async';
import 'dart:io';
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

    // Request permissions for iOS
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

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'alarm_geofence_channel',
        'Location Alarms',
        description: 'Notifications for location-based alarms',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
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

      // If no more regions, stop the service
      if (_geofencing.regions.isEmpty && _isRunning) {
        await _geofencing.stop();
        _isRunning = false;
        debugPrint('🛑 Geofence service stopped (no active geofences)');
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
