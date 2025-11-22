import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alarm.dart';
import 'alarm_sound_service.dart';

/// Native iOS geofencing service using Core Location
/// This provides reliable background geofencing on iOS
class NativeIOSGeofenceService {
  static const MethodChannel _channel = MethodChannel('com.wakemeup/geofence');
  static final NativeIOSGeofenceService _instance = NativeIOSGeofenceService._internal();

  factory NativeIOSGeofenceService() => _instance;
  NativeIOSGeofenceService._internal() {
    _setupMethodCallHandler();
  }

  Function(String id, String name)? onGeofenceEntered;
  final _alarmSoundService = AlarmSoundService();

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onGeofenceEntered':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = args['id'] as String;
          final name = args['name'] as String;
          debugPrint('🎯 Flutter received geofence enter: $name ($id)');
          onGeofenceEntered?.call(id, name);
          break;
        case 'stopAlarm':
          // User tapped "Stop Alarm" button on notification
          debugPrint('🛑 Flutter received stopAlarm from native iOS');
          await _alarmSoundService.stopAlarm();
          break;
      }
    });
  }

  /// Start native iOS geofencing for an alarm
  /// Returns true if successful
  Future<bool> startGeofencing(Alarm alarm) async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ Native iOS geofencing only works on iOS');
      return false;
    }

    try {
      debugPrint('📍 Starting NATIVE iOS geofence for: ${alarm.name}');
      final result = await _channel.invokeMethod('startGeofence', {
        'id': alarm.id,
        'latitude': alarm.latitude,
        'longitude': alarm.longitude,
        'radius': alarm.radius,
        'name': alarm.name,
      });
      debugPrint('✅ Native iOS geofence started: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ Error starting native iOS geofence: $e');
      return false;
    }
  }

  /// Stop native iOS geofencing for an alarm
  Future<void> stopGeofencing(String alarmId) async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('stopGeofence', {'id': alarmId});
      debugPrint('🛑 Native iOS geofence stopped: $alarmId');
    } catch (e) {
      debugPrint('❌ Error stopping native iOS geofence: $e');
    }
  }

  /// Stop all native iOS geofences
  Future<void> stopAllGeofencing() async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('stopAllGeofences');
      debugPrint('🛑 All native iOS geofences stopped');
    } catch (e) {
      debugPrint('❌ Error stopping all native iOS geofences: $e');
    }
  }
}
