import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_foreground_service/exports.dart';
import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:geofence_foreground_service/models/zone.dart' as geofence;
import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import '../models/alarm.dart';
import 'alarm_storage_service.dart';
import 'alarm_sound_service.dart';

/// Top-level callback dispatcher for geofence events (must be top-level)
@pragma('vm:entry-point')
void geofenceCallbackDispatcher() {
  GeofenceForegroundService().handleTrigger(
    backgroundTriggerHandler: (zoneID, triggerType) async {
      debugPrint('🎯 Background geofence triggered: $zoneID - $triggerType');

      if (triggerType == GeofenceEventType.enter) {
        // Get alarm from storage
        final alarm = AlarmStorageService.getAlarm(zoneID);
        if (alarm != null) {
          // Show notification
          await _showBackgroundNotification(alarm);

          // Start alarm sound
          await AlarmSoundService().startAlarm(
            alarmId: alarm.id,
            soundLevel: alarm.soundLevel,
          );
        }
      }

      return Future.value(true);
    },
  );
}

/// Show notification from background isolate
Future<void> _showBackgroundNotification(Alarm alarm) async {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

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

  await notificationsPlugin.show(
    alarm.id.hashCode,
    '⏰ ${alarm.name}',
    'You have arrived at ${alarm.address}',
    details,
  );
}

/// Service to manage background geofencing for location-based alarms using native APIs
class GeofenceAlarmServiceNative {
  static final GeofenceAlarmServiceNative _instance = GeofenceAlarmServiceNative._internal();
  factory GeofenceAlarmServiceNative() => _instance;
  GeofenceAlarmServiceNative._internal();

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
    if (_isServiceRunning) return;

    debugPrint('🚀 Starting geofence foreground service...');

    final started = await GeofenceForegroundService().startGeofencingService(
      contentTitle: 'WakeMeUp Active',
      contentText: 'Monitoring your location alarms',
      notificationChannelId: 'alarm_monitoring_channel',
      serviceId: 1,
      callbackDispatcher: geofenceCallbackDispatcher,
    );

    _isServiceRunning = started;
    debugPrint('✅ Geofence service started: $started');
  }

  /// Start geofencing for an alarm
  Future<bool> startGeofencing(Alarm alarm) async {
    if (!_isInitialized) {
      await initialize();
    }

    debugPrint('📍 Starting native geofencing for alarm: ${alarm.name}');

    try {
      // Ensure service is started
      await _ensureServiceStarted();

      // Create zone with proper LatLng from geofence package
      final zone = geofence.Zone(
        id: alarm.id,
        radius: alarm.radius, // Already a double
        coordinates: [
          LatLng(
            Angle.degree(alarm.latitude),
            Angle.degree(alarm.longitude),
          ),
        ],
      );

      // Add geofence zone
      await GeofenceForegroundService().addGeofenceZone(zone: zone);

      debugPrint('✅ Geofence zone added for: ${alarm.name}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error starting native geofencing: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
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
}
