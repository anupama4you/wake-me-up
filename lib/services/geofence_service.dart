import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_foreground_service/exports.dart';
import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:geofence_foreground_service/models/zone.dart' as geofence;
import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import 'package:geolocator/geolocator.dart';
import '../models/alarm.dart';
import 'alarm_storage_service.dart';
import 'alarm_sound_service.dart';
import 'location_service.dart';

/// Top-level callback dispatcher for geofence events (must be top-level)
@pragma('vm:entry-point')
void geofenceCallbackDispatcher() {
  debugPrint('🔥🔥🔥 CALLBACK DISPATCHER CALLED! 🔥🔥🔥');
  debugPrint('Timestamp: ${DateTime.now()}');

  GeofenceForegroundService().handleTrigger(
    backgroundTriggerHandler: (zoneID, triggerType) async {
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('🎯🎯🎯 GEOFENCE EVENT TRIGGERED! 🎯🎯🎯');
      debugPrint('Timestamp: ${DateTime.now()}');
      debugPrint('Zone ID: $zoneID');
      debugPrint('Trigger Type: $triggerType');
      debugPrint('═══════════════════════════════════════════════');

      if (triggerType == GeofenceEventType.enter) {
        debugPrint('✅ ENTER event detected - processing alarm...');

        try {
          // CRITICAL: Initialize Hive in the background isolate
          debugPrint('📦 Initializing Hive in background isolate...');
          await AlarmStorageService.init();
          debugPrint('✅ Hive initialized in background isolate');

          // Get alarm from storage
          debugPrint('🔍 Looking for alarm with ID: $zoneID');
          final alarm = AlarmStorageService.getAlarm(zoneID);

          if (alarm != null) {
            debugPrint('📱 Found alarm: ${alarm.name}');
            debugPrint('   - Address: ${alarm.address}');
            debugPrint('   - Sound Level: ${alarm.soundLevel}');
            debugPrint('   - Active: ${alarm.isActive}');

            // Show notification
            debugPrint('📢 Sending notification...');
            await _showBackgroundNotification(alarm);
            debugPrint('✅ Notification sent');

            // Start alarm sound
            debugPrint('🔊 Starting alarm sound...');
            await AlarmSoundService().startAlarm(
              alarmId: alarm.id,
              soundLevel: alarm.soundLevel,
            );
            debugPrint('✅ Alarm sound started successfully');
          } else {
            debugPrint('❌❌❌ ALARM NOT FOUND FOR ZONE: $zoneID ❌❌❌');
            debugPrint('Available alarm IDs in storage:');
            final allAlarms = AlarmStorageService.getAllAlarms();
            for (var a in allAlarms) {
              debugPrint('   - ${a.id} (${a.name}, Active: ${a.isActive})');
            }
          }
        } catch (e, stackTrace) {
          debugPrint('❌❌❌ ERROR IN GEOFENCE CALLBACK ❌❌❌');
          debugPrint('Error: $e');
          debugPrint('Stack trace: $stackTrace');
        }
      } else if (triggerType == GeofenceEventType.exit) {
        debugPrint('🚪 EXIT event detected');
      } else if (triggerType == GeofenceEventType.dwell) {
        debugPrint('⏱️ DWELL event detected');
      }

      debugPrint('═══════════════════════════════════════════════');
      return Future.value(true);
    },
  );
}

/// Show notification from background isolate
Future<void> _showBackgroundNotification(Alarm alarm) async {
  debugPrint('📢 Creating notification plugin...');
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Initialize notifications in background isolate
  debugPrint('📢 Initializing notifications in background isolate...');
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  try {
    await notificationsPlugin.initialize(initSettings);
    debugPrint('✅ Notifications initialized in background');
  } catch (e) {
    debugPrint('⚠️ Error initializing notifications (may already be initialized): $e');
  }

  const androidDetails = AndroidNotificationDetails(
    'alarm_geofence_channel',
    'Location Alarms',
    channelDescription: 'Notifications for location-based alarms',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    presentBanner: true,
    presentList: true,
    interruptionLevel: InterruptionLevel.critical,
  );

  const details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  debugPrint('📢 Showing notification...');
  debugPrint('   - ID: ${alarm.id.hashCode}');
  debugPrint('   - Title: ⏰ ${alarm.name}');
  debugPrint('   - Body: You have arrived at ${alarm.address}');

  try {
    await notificationsPlugin.show(
      alarm.id.hashCode,
      '⏰ ${alarm.name}',
      'You have arrived at ${alarm.address}',
      details,
    );
    debugPrint('✅ Notification shown successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ Error showing notification: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}

/// Service to manage background geofencing for location-based alarms using native APIs
/// Works on both iOS and Android even when app is killed/locked
class GeofenceAlarmService {
  static final GeofenceAlarmService _instance = GeofenceAlarmService._internal();
  factory GeofenceAlarmService() => _instance;
  GeofenceAlarmService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final _alarmSoundService = AlarmSoundService();

  bool _isInitialized = false;
  bool _isServiceRunning = false;

  /// Initialize the geofence service
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔔 Initializing Native GeofenceAlarmService...');

    await _initializeNotifications();

    _isInitialized = true;
    debugPrint('✅ Native GeofenceAlarmService initialized');
  }

  /// Check if location permissions are granted
  Future<bool> _checkLocationPermissions() async {
    debugPrint('🔍 Checking location permissions...');

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location services are disabled');
      return false;
    }

    // Check permission status
    final permission = await Geolocator.checkPermission();
    debugPrint('📍 Current permission: $permission');

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permission not granted');
      return false;
    }

    // For geofencing, background permission is highly recommended
    final hasBackground = await LocationService.hasBackgroundPermission();
    if (!hasBackground) {
      debugPrint('⚠️ Background location permission not granted - geofencing may not work when app is closed');
      debugPrint('⚠️ User should grant "Always" permission in settings');
    } else {
      debugPrint('✅ Background location permission granted');
    }

    return true;
  }

  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    debugPrint('🔔 Starting notification initialization...');

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Request permissions
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();

      // Create notification channels
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'alarm_geofence_channel',
          'Location Alarms',
          description: 'Notifications for location-based alarms',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'alarm_monitoring_channel',
          'Background Monitoring',
          description: 'Background location monitoring',
          importance: Importance.low,
          playSound: false,
        ),
      );
    }

    if (Platform.isIOS) {
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Start geofencing service if not already running
  Future<void> _ensureServiceStarted() async {
    if (_isServiceRunning) {
      debugPrint('✅ Geofence service already running');
      return;
    }

    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🚀 STARTING GEOFENCE FOREGROUND SERVICE');
    debugPrint('   - Service ID: 525600');
    debugPrint('   - Channel ID: alarm_monitoring_channel');
    debugPrint('   - Callback: geofenceCallbackDispatcher');
    debugPrint('═══════════════════════════════════════════════');

    try {
      final started = await GeofenceForegroundService().startGeofencingService(
        contentTitle: 'WakeMeUp Active',
        contentText: 'Monitoring location alarms',
        notificationChannelId: 'alarm_monitoring_channel',
        serviceId: 525600,
        callbackDispatcher: geofenceCallbackDispatcher,
      );

      _isServiceRunning = started;

      if (started) {
        debugPrint('═══════════════════════════════════════════════');
        debugPrint('✅✅✅ GEOFENCE SERVICE STARTED SUCCESSFULLY ✅✅✅');
        debugPrint('   - The service is now monitoring for geofence events');
        debugPrint('   - You should see a persistent notification (Android)');
        debugPrint('═══════════════════════════════════════════════');
      } else {
        debugPrint('═══════════════════════════════════════════════');
        debugPrint('❌❌❌ FAILED TO START GEOFENCE SERVICE ❌❌❌');
        debugPrint('   - Check location permissions');
        debugPrint('   - Check if foreground service is configured in manifest');
        debugPrint('═══════════════════════════════════════════════');
      }
    } catch (e, stackTrace) {
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('❌❌❌ EXCEPTION STARTING GEOFENCE SERVICE ❌❌❌');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('═══════════════════════════════════════════════');
      _isServiceRunning = false;
    }
  }

  /// Start geofencing for an alarm
  Future<bool> startGeofencing(Alarm alarm) async {
    if (!_isInitialized) {
      await initialize();
    }

    debugPrint('📍 Starting native geofencing for alarm: ${alarm.name}');

    try {
      // Check location permissions first
      final hasPermission = await _checkLocationPermissions();
      if (!hasPermission) {
        debugPrint('❌ Location permissions not granted - cannot start geofence');
        return false;
      }

      // Ensure service is started
      await _ensureServiceStarted();

      if (!_isServiceRunning) {
        debugPrint('❌ Service failed to start - cannot add geofence');
        return false;
      }

      // Enforce minimum radius for iOS (200m) and Android (100m)
      double effectiveRadius = alarm.radius;
      if (Platform.isIOS && effectiveRadius < 200) {
        debugPrint('⚠️ iOS requires minimum 200m radius, adjusting from ${effectiveRadius}m');
        effectiveRadius = 200;
      } else if (Platform.isAndroid && effectiveRadius < 100) {
        debugPrint('⚠️ Android requires minimum 100m radius, adjusting from ${effectiveRadius}m');
        effectiveRadius = 100;
      }

      debugPrint('═══════════════════════════════════════════════');
      debugPrint('📍 CREATING GEOFENCE ZONE');
      debugPrint('   - Alarm ID: ${alarm.id}');
      debugPrint('   - Alarm Name: ${alarm.name}');
      debugPrint('   - Location: ${alarm.latitude}, ${alarm.longitude}');
      debugPrint('   - Radius: ${effectiveRadius}m');
      debugPrint('   - Platform: ${Platform.operatingSystem}');
      debugPrint('═══════════════════════════════════════════════');

      // Create zone with explicit triggers
      final zone = geofence.Zone(
        id: alarm.id,
        radius: effectiveRadius,
        coordinates: [
          LatLng(
            Angle.degree(alarm.latitude),
            Angle.degree(alarm.longitude),
          ),
        ],
        triggers: [
          GeofenceEventType.enter,  // Trigger when entering zone
        ],
      );

      debugPrint('📍 Adding geofence zone to service...');
      await GeofenceForegroundService().addGeofenceZone(zone: zone);

      debugPrint('═══════════════════════════════════════════════');
      debugPrint('✅ GEOFENCE ZONE ADDED SUCCESSFULLY');
      debugPrint('   - Alarm: ${alarm.name}');
      debugPrint('   - Zone ID: ${alarm.id}');
      debugPrint('═══════════════════════════════════════════════');

      // CRITICAL: Check if user is already inside the geofence
      debugPrint('🔍 Checking if you are already inside the geofence...');
      try {
        final currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );

        // Calculate distance from current location to alarm location
        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          alarm.latitude,
          alarm.longitude,
        );

        debugPrint('📏 Your location: ${currentPosition.latitude}, ${currentPosition.longitude}');
        debugPrint('📏 Alarm location: ${alarm.latitude}, ${alarm.longitude}');
        debugPrint('📏 Distance to geofence center: ${distance.toStringAsFixed(0)}m');
        debugPrint('📏 Geofence radius: ${effectiveRadius}m');

        if (distance <= effectiveRadius) {
          debugPrint('═══════════════════════════════════════════════');
          debugPrint('⚠️⚠️⚠️ YOU ARE ALREADY INSIDE THE GEOFENCE! ⚠️⚠️⚠️');
          debugPrint('🚨 TRIGGERING ALARM IMMEDIATELY!');
          debugPrint('═══════════════════════════════════════════════');

          // Trigger the alarm immediately
          await _triggerAlarmNow(alarm);
        } else {
          debugPrint('✅ You are OUTSIDE the geofence (${distance.toStringAsFixed(0)}m away)');
          debugPrint('   The alarm will trigger when you move within ${effectiveRadius}m');
        }
      } catch (e) {
        debugPrint('⚠️ Could not check current position: $e');
        debugPrint('   Alarm will trigger when you enter the geofence');
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error starting native geofencing: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Trigger alarm immediately (when already inside geofence or for testing)
  Future<void> _triggerAlarmNow(Alarm alarm) async {
    debugPrint('🚨 Triggering alarm NOW: ${alarm.name}');

    try {
      // Show notification
      await _showBackgroundNotification(alarm);
      debugPrint('✅ Notification shown');

      // Start alarm sound
      await _alarmSoundService.startAlarm(
        alarmId: alarm.id,
        soundLevel: alarm.soundLevel,
      );
      debugPrint('✅ Alarm sound started');
    } catch (e, stackTrace) {
      debugPrint('❌ Error triggering alarm: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Stop geofencing for an alarm
  Future<void> stopGeofencing(String alarmId) async {
    debugPrint('🛑 Stopping geofencing for alarm: $alarmId');

    try {
      // Stop alarm sound if playing
      if (_alarmSoundService.currentAlarmId == alarmId) {
        await _alarmSoundService.stopAlarm();
      }

      // Remove zone
      await GeofenceForegroundService().removeGeofenceZone(zoneId: alarmId);

      debugPrint('✅ Geofence removed for: $alarmId');

      // Check if we should stop the service
      final activeAlarms = AlarmStorageService.getActiveAlarms();
      if (activeAlarms.isEmpty) {
        await GeofenceForegroundService().stopGeofencingService();
        _isServiceRunning = false;
        debugPrint('🛑 Geofence service stopped (no active alarms)');
      }
    } catch (e) {
      debugPrint('❌ Error stopping geofencing: $e');
    }
  }

  /// Stop all geofencing
  Future<void> stopAllGeofencing() async {
    debugPrint('🛑 Stopping all geofencing...');

    try {
      await _alarmSoundService.stopAlarm();
      await GeofenceForegroundService().stopGeofencingService();
      _isServiceRunning = false;
      debugPrint('✅ All geofencing stopped');
    } catch (e) {
      debugPrint('❌ Error stopping all geofencing: $e');
    }
  }

  /// Sync geofences with stored alarms
  Future<void> syncGeofencesWithAlarms() async {
    debugPrint('🔄 Syncing geofences with stored alarms...');

    try {
      // Stop current service
      await GeofenceForegroundService().stopGeofencingService();
      _isServiceRunning = false;

      // Get all active alarms
      final activeAlarms = AlarmStorageService.getActiveAlarms();

      if (activeAlarms.isEmpty) {
        debugPrint('✅ No active alarms to sync');
        return;
      }

      // Start service
      await _ensureServiceStarted();

      // Add all zones
      for (final alarm in activeAlarms) {
        final zone = geofence.Zone(
          id: alarm.id,
          radius: alarm.radius,
          coordinates: [
            LatLng(
              Angle.degree(alarm.latitude),
              Angle.degree(alarm.longitude),
            ),
          ],
        );

        await GeofenceForegroundService().addGeofenceZone(zone: zone);
      }

      debugPrint('✅ Synced ${activeAlarms.length} active alarms');
    } catch (e) {
      debugPrint('❌ Error syncing geofences: $e');
    }
  }

  /// Reload settings (kept for compatibility)
  Future<void> reloadSettings() async {
    debugPrint('🔄 Reloading settings...');
    // Resync geofences
    await syncGeofencesWithAlarms();
  }

  /// Check if service is running
  bool get isRunning => _isServiceRunning;

  /// Get active regions (stub for compatibility)
  Set<geofence.Zone> get activeRegions => {};

  /// Test the alarm trigger manually (for debugging)
  Future<void> testAlarmTrigger(String alarmId) async {
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🧪 MANUALLY TESTING ALARM TRIGGER');
    debugPrint('   - Alarm ID: $alarmId');
    debugPrint('═══════════════════════════════════════════════');

    try {
      // Initialize Hive
      if (!AlarmStorageService.isInitialized) {
        await AlarmStorageService.init();
      }

      // Get alarm
      final alarm = AlarmStorageService.getAlarm(alarmId);
      if (alarm == null) {
        debugPrint('❌ Alarm not found: $alarmId');
        return;
      }

      debugPrint('✅ Found alarm: ${alarm.name}');

      // Trigger the alarm
      await _triggerAlarmNow(alarm);

      debugPrint('✅ Test alarm triggered successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error testing alarm: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    debugPrint('═══════════════════════════════════════════════');
  }

  /// Print diagnostic information about geofencing status
  Future<void> printDiagnostics() async {
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('📊 GEOFENCE SERVICE DIAGNOSTICS');
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('Service running: $_isServiceRunning');
    debugPrint('Service initialized: $_isInitialized');

    // Check permissions
    final hasPermission = await _checkLocationPermissions();
    debugPrint('Location permissions: $hasPermission');

    // Get all active alarms
    final activeAlarms = AlarmStorageService.getActiveAlarms();
    debugPrint('Active alarms: ${activeAlarms.length}');

    for (var alarm in activeAlarms) {
      debugPrint('  - ${alarm.name} (ID: ${alarm.id})');
      debugPrint('    Location: ${alarm.latitude}, ${alarm.longitude}');
      debugPrint('    Radius: ${alarm.radius}m');
    }

    debugPrint('═══════════════════════════════════════════════');
    debugPrint('IMPORTANT: For geofencing to work:');
    debugPrint('1. Location services must be ON');
    debugPrint('2. App needs "Always" location permission');
    debugPrint('3. You must physically MOVE INTO the geofence zone');
    debugPrint('4. Wait 1-2 minutes after entering for system to detect');
    debugPrint('5. Make sure "WakeMeUp Active" notification is showing (Android)');
    debugPrint('═══════════════════════════════════════════════');
  }
}
