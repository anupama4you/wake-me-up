import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/alarm.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  StreamSubscription<Position>? _locationSubscription;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isMonitoring = false;

  Future<void> initialize() async {
    // Initialize notifications
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

    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // Request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permission denied forever');
      return;
    }

    // Start listening to location updates
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((position) async {
      await _checkAlarms(position);
    });

    print('Alarm monitoring started');
  }

  Future<void> stopMonitoring() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _isMonitoring = false;
    print('Alarm monitoring stopped');
  }

  Future<void> _checkAlarms(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString('alarms');

      if (alarmsJson == null) return;

      final List<dynamic> decoded = json.decode(alarmsJson);
      final alarms = decoded.map((json) => Alarm.fromJson(json)).toList();

      for (var alarm in alarms) {
        if (!alarm.isActive) continue;

        final distance = _calculateDistance(
          position.latitude,
          position.longitude,
          alarm.latitude,
          alarm.longitude,
        );

        if (distance <= alarm.radius) {
          await _triggerAlarm(alarm);
        }
      }
    } catch (e) {
      print('Error checking alarms: $e');
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _triggerAlarm(Alarm alarm) async {
    // Show notification
    const androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Location Alarms',
      channelDescription: 'Notifications for location-based alarms',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      alarm.id.hashCode,
      'Alarm Triggered!',
      'You have arrived at ${alarm.name}',
      details,
    );

    // Deactivate the alarm after triggering
    await _deactivateAlarm(alarm.id);
  }

  Future<void> _deactivateAlarm(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString('alarms');

      if (alarmsJson == null) return;

      final List<dynamic> decoded = json.decode(alarmsJson);
      final alarms = decoded.map((json) => Alarm.fromJson(json)).toList();

      for (var alarm in alarms) {
        if (alarm.id == alarmId) {
          alarm.isActive = false;
        }
      }

      final updatedJson = json.encode(alarms.map((a) => a.toJson()).toList());
      await prefs.setString('alarms', updatedJson);

      // Check if any alarms are still active
      final hasActiveAlarms = alarms.any((a) => a.isActive);
      if (!hasActiveAlarms) {
        await stopMonitoring();
      }
    } catch (e) {
      print('Error deactivating alarm: $e');
    }
  }
}
