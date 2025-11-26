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
import 'native_ios_geofence_service.dart';

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

        // On iOS, native geofencing handles notifications - skip Flutter notifications
        if (Platform.isIOS) {
          debugPrint('📱 iOS: Native geofence handles notifications, skipping Flutter notification');
          return Future.value(true);
        }

        try {
          // CRITICAL: Parse alarm data from zone ID
          // Format: alarmId|||alarmName|||address|||soundLevel
          debugPrint('📦 Parsing alarm data from zone ID: $zoneID');
          final parts = zoneID.split('|||');

          if (parts.length >= 4) {
            final alarmId = parts[0];
            final alarmName = parts[1];
            final address = parts[2];
            final soundLevel = parts[3];

            debugPrint('✅ Parsed alarm data');
            debugPrint('📱 Alarm: $alarmName');
            debugPrint('   - Address: $address');
            debugPrint('   - Sound Level: $soundLevel');

            // Show notification with sound (this works in background) - Android only
            debugPrint('📢 Sending notification with alarm sound...');
            await _showBackgroundNotificationSimple(
              alarmId: alarmId,
              alarmName: alarmName,
              address: address,
            );
            debugPrint('✅ Notification sent - alarm sound will play');
          } else {
            debugPrint('❌❌❌ INVALID ZONE ID FORMAT ❌❌❌');
            debugPrint('Expected: alarmId|||name|||address|||soundLevel');
            debugPrint('Got: $zoneID');
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

/// Show notification from background isolate (simple version without Alarm object)
Future<void> _showBackgroundNotificationSimple({
  required String alarmId,
  required String alarmName,
  required String address,
}) async {
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
    debugPrint('⚠️ Error initializing notifications: $e');
  }

  // Android notification with custom alarm sound
  const androidDetails = AndroidNotificationDetails(
    'alarm_geofence_channel',
    'Location Alarms',
    channelDescription: 'Notifications for location-based alarms',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm'),
    enableVibration: true,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    ongoing: true,
    autoCancel: false,
    onlyAlertOnce: false,
    channelShowBadge: true,
    styleInformation: BigTextStyleInformation(
      'You have arrived at your destination. Tap to open app.',
      contentTitle: '⏰ Location Alarm',
    ),
  );

  // iOS notification with critical interruption level
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    sound: 'alarm.mp3',
    presentBanner: true,
    presentList: true,
    interruptionLevel: InterruptionLevel.critical,
    categoryIdentifier: 'alarm_category',
  );

  const details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  debugPrint('📢 Showing notification...');
  debugPrint('   - ID: ${alarmId.hashCode}');
  debugPrint('   - Title: ⏰ $alarmName');
  debugPrint('   - Body: You have arrived at $address');

  try {
    await notificationsPlugin.show(
      alarmId.hashCode,
      '⏰ $alarmName',
      'You have arrived at $address',
      details,
    );
    debugPrint('✅ Notification shown successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ Error showing notification: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}

/// Show notification from background isolate (original version with Alarm object)
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

  // Android notification with custom alarm sound
  const androidDetails = AndroidNotificationDetails(
    'alarm_geofence_channel',
    'Location Alarms',
    channelDescription: 'Notifications for location-based alarms',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm'), // Custom alarm sound
    enableVibration: true,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    ongoing: true, // Makes notification persistent (can't be dismissed by swiping)
    autoCancel: false, // Notification stays until explicitly dismissed
    onlyAlertOnce: false, // Allow sound to play multiple times
    channelShowBadge: true,
    styleInformation: BigTextStyleInformation(
      'You have arrived at your destination. Tap to open app.',
      contentTitle: '⏰ Location Alarm',
    ),
  );

  // iOS notification with critical interruption level
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    sound: 'alarm.mp3', // Custom sound from assets
    presentBanner: true,
    presentList: true,
    interruptionLevel: InterruptionLevel.critical, // Bypasses Focus modes
    categoryIdentifier: 'alarm_category',
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
  final _nativeIOSGeofenceService = NativeIOSGeofenceService();

  bool _isInitialized = false;
  bool _isServiceRunning = false;

  /// Callback when an alarm is triggered and marked as completed
  /// UI can listen to this to refresh the alarm list
  Function(String alarmId)? onAlarmCompleted;

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

      // Create notification channels with custom alarm sound
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'alarm_geofence_channel',
          'Location Alarms',
          description: 'Notifications for location-based alarms',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alarm'), // Custom alarm sound
          enableVibration: true,
          enableLights: true,
          showBadge: true,
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

      // USE NATIVE iOS GEOFENCING for iOS platform
      if (Platform.isIOS) {
        debugPrint('📱 Using NATIVE iOS Core Location geofencing');

        // Set up callback to handle geofence enter events from native iOS
        _nativeIOSGeofenceService.onGeofenceEntered = (id, name) async {
          debugPrint('🎯🎯🎯 NATIVE iOS GEOFENCE TRIGGERED IN FLUTTER! 🎯🎯🎯');
          debugPrint('   - ID: $id');
          debugPrint('   - Name: $name');

          // Get the alarm and trigger it
          final triggeredAlarm = AlarmStorageService.getAlarm(id);
          if (triggeredAlarm != null) {
            await _triggerAlarmNow(triggeredAlarm);
          }
        };

        final success = await _nativeIOSGeofenceService.startGeofencing(alarm);
        if (success) {
          debugPrint('✅ Native iOS geofence started successfully');
          _isServiceRunning = true;

          // Also check if already inside the geofence
          await _checkIfAlreadyInsideGeofence(alarm);
        }
        return success;
      }

      // For Android, use geofence_foreground_service package
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

      // CRITICAL: Encode alarm data in zone ID for background isolate access
      // Format: alarmId|||alarmName|||address|||soundLevel
      final encodedZoneId = '${alarm.id}|||${alarm.name}|||${alarm.address}|||${alarm.soundLevel}';
      debugPrint('📦 Encoded zone ID: $encodedZoneId');

      // Create zone with explicit triggers
      final zone = geofence.Zone(
        id: encodedZoneId, // Use encoded ID with alarm data
        radius: effectiveRadius,
        coordinates: [
          LatLng(
            Angle.degree(alarm.latitude),
            Angle.degree(alarm.longitude),
          ),
        ],
        triggers: [
          GeofenceEventType.enter,  // ONLY trigger when entering zone
        ],
        notificationResponsivenessMs: 0, // Android: Trigger as fast as possible (0ms)
      );

      debugPrint('📍 Adding geofence zone to service...');
      debugPrint('   - Triggers: ENTER ONLY');
      debugPrint('   - Android responsiveness: 0ms (immediate)');
      debugPrint('   - iOS: System managed (typically 1-2 min delay)');

      await GeofenceForegroundService().addGeofenceZone(zone: zone);

      debugPrint('✅ Geofence zone registered with system');

      debugPrint('═══════════════════════════════════════════════');
      debugPrint('✅ GEOFENCE ZONE ADDED SUCCESSFULLY');
      debugPrint('   - Alarm: ${alarm.name}');
      debugPrint('   - Zone ID: ${alarm.id}');
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('');
      debugPrint('⚠️ IMPORTANT TESTING NOTES:');
      debugPrint('1. Make sure you are OUTSIDE the geofence before testing');
      debugPrint('2. iOS geofencing has 1-2 minute delay after crossing boundary');
      debugPrint('3. Move at least ${effectiveRadius + 50}m away before entering');
      debugPrint('4. Walk/drive normally - don\'t stand still at the boundary');
      debugPrint('5. Keep app in background (don\'t kill it)');
      debugPrint('6. Check logs when you enter the zone');
      debugPrint('═══════════════════════════════════════════════');

      // Note: Alarm data is encoded in the zone ID, no need for separate caching

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
  /// Note: Alarm stays ACTIVE until user manually toggles it off
  Future<void> _triggerAlarmNow(Alarm alarm) async {
    debugPrint('🚨 Triggering alarm NOW: ${alarm.name}');

    try {
      // MARK ALARM AS COMPLETED but keep it ACTIVE
      // User must manually toggle off to stop the alarm
      alarm.isCompleted = true;
      alarm.completedAt = DateTime.now();
      // Keep isActive = true - alarm continues until user disables it
      await AlarmStorageService.updateAlarm(alarm);
      debugPrint('✅ Alarm marked as COMPLETED (still active - user must toggle off)');
      debugPrint('   - isCompleted: ${alarm.isCompleted}');
      debugPrint('   - completedAt: ${alarm.completedAt}');
      debugPrint('   - isActive: ${alarm.isActive}');

      // Stop geofencing monitoring (no need to track anymore - already arrived)
      // NOTE: On iOS, native code already stopped monitoring in didEnterRegion
      if (Platform.isIOS) {
        // Don't call stopGeofencing here - it would stop the alarm sound!
        // Native iOS already handles: sound, vibration, notification
        debugPrint('ℹ️ iOS: Native code already handled notification and sound');
      } else {
        // Android: Show notification and start sound from Flutter
        await _showBackgroundNotification(alarm);
        debugPrint('✅ Notification shown with sound');

        try {
          await _alarmSoundService.startAlarm(
            alarmId: alarm.id,
            soundLevel: alarm.soundLevel,
            ringtone: alarm.ringtone,
          );
          debugPrint('✅ Alarm sound started - will continue until user disables');
        } catch (e) {
          debugPrint('⚠️ Could not start app alarm sound (app may be in background): $e');
          debugPrint('   Alarm sound will play through notification');
        }
      }

      // Notify UI to refresh alarm list (if callback is set)
      debugPrint('📢 Checking if onAlarmCompleted callback is set: ${onAlarmCompleted != null}');
      if (onAlarmCompleted != null) {
        debugPrint('📢 Notifying UI that alarm ${alarm.id} is completed');
        onAlarmCompleted!(alarm.id);
      } else {
        debugPrint('⚠️ onAlarmCompleted callback is NOT set - UI will not refresh automatically');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error triggering alarm: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Check if user is already inside the geofence and trigger alarm if so
  Future<void> _checkIfAlreadyInsideGeofence(Alarm alarm) async {
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

      // Use effective radius (minimum 200m for iOS)
      final effectiveRadius = Platform.isIOS ? (alarm.radius < 200 ? 200.0 : alarm.radius) : alarm.radius;

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
  }

  /// Stop geofencing for an alarm
  Future<void> stopGeofencing(String alarmId) async {
    debugPrint('🛑 Stopping geofencing for alarm: $alarmId');

    try {
      // Always stop alarm sound when geofencing is stopped
      // The sound service is a singleton, so this will stop any playing alarm
      debugPrint('🔊 Stopping alarm sound (current: ${_alarmSoundService.currentAlarmId}, requested: $alarmId)');
      await _alarmSoundService.stopAlarm();

      // Use native iOS geofencing on iOS
      if (Platform.isIOS) {
        await _nativeIOSGeofenceService.stopGeofencing(alarmId);
        debugPrint('✅ Native iOS geofence stopped for: $alarmId');

        // Check if we should mark service as stopped
        final activeAlarms = AlarmStorageService.getActiveAlarms();
        if (activeAlarms.isEmpty) {
          _isServiceRunning = false;
          debugPrint('🛑 No more active alarms');
        }
        return;
      }

      // For Android, use geofence_foreground_service package
      // Get the alarm to construct the encoded zone ID
      final alarm = AlarmStorageService.getAlarm(alarmId);
      if (alarm != null) {
        final encodedZoneId = '${alarm.id}|||${alarm.name}|||${alarm.address}|||${alarm.soundLevel}';
        // Remove zone using encoded ID
        await GeofenceForegroundService().removeGeofenceZone(zoneId: encodedZoneId);
      } else {
        // Fallback: try with just the alarm ID
        await GeofenceForegroundService().removeGeofenceZone(zoneId: alarmId);
      }

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

      // Use native iOS geofencing on iOS
      if (Platform.isIOS) {
        await _nativeIOSGeofenceService.stopAllGeofencing();
        _isServiceRunning = false;
        debugPrint('✅ All native iOS geofences stopped');
        return;
      }

      // For Android, use geofence_foreground_service package
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
