import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alarm.dart';
import 'settings_service.dart';

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

  /// Callback to stop alarm sound - set by AlarmSoundService to avoid circular dependency
  Future<void> Function()? onStopAlarmRequested;

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
          // Call the callback if set (to avoid circular dependency)
          if (onStopAlarmRequested != null) {
            await onStopAlarmRequested!();
          } else {
            // Fallback: directly stop the native sound
            await stopSystemSound();
          }
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
      debugPrint('   - Ringtone: ${alarm.ringtone}');
      debugPrint('   - Vibration: ${SettingsService.vibrationEnabled}');
      final result = await _channel.invokeMethod('startGeofence', {
        'id': alarm.id,
        'latitude': alarm.latitude,
        'longitude': alarm.longitude,
        'radius': alarm.radius,
        'name': alarm.name,
        'ringtone': alarm.ringtone, // Pass ringtone to native iOS for background playback
        'vibrationEnabled': SettingsService.vibrationEnabled, // Pass vibration setting to native iOS
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

  /// Play iOS system sound
  /// soundType options: 'alarm', 'tritone', 'alert', 'bell', 'electronic', 'horn', 'radar', 'beacon', 'bulletin', 'chime'
  Future<bool> playSystemSound({required String soundType, bool loop = true}) async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ iOS system sounds only work on iOS');
      return false;
    }

    try {
      debugPrint('🔊 Playing iOS system sound: $soundType');
      final result = await _channel.invokeMethod('playSystemSound', {
        'soundType': soundType,
        'loop': loop,
      });
      return result == true;
    } catch (e) {
      debugPrint('❌ Error playing iOS system sound: $e');
      return false;
    }
  }

  /// Stop iOS system sound
  Future<void> stopSystemSound() async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('stopSystemSound');
      debugPrint('🛑 iOS system sound stopped');
    } catch (e) {
      debugPrint('❌ Error stopping iOS system sound: $e');
    }
  }
}
