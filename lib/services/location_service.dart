import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'settings_service.dart';

/// Result of location permission request
enum LocationPermissionResult {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  backgroundDenied,
}

class LocationService {
  /// Request location permission with detailed result
  static Future<LocationPermissionResult> requestPermissionDetailed() async {
    debugPrint('🔍 Starting location permission request...');

    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location services are disabled');
      return LocationPermissionResult.serviceDisabled;
    }
    debugPrint('✅ Location services are enabled');

    // Check current permission status
    permission = await Geolocator.checkPermission();
    debugPrint('📍 Current permission: $permission');

    if (permission == LocationPermission.denied) {
      debugPrint('📍 Requesting location permission...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permission denied');
        return LocationPermissionResult.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permission denied forever');
      return LocationPermissionResult.deniedForever;
    }

    debugPrint('✅ Basic location permission granted: $permission');

    // For geofencing, we need background location permission
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      debugPrint('📍 Requesting background location permission for geofencing...');

      if (Platform.isAndroid) {
        // Request background location for Android
        final status = await ph.Permission.locationAlways.request();
        debugPrint('📍 Android background location status: $status');

        if (!status.isGranted) {
          debugPrint('⚠️ Background location not granted - geofencing may not work when app is closed');
          return LocationPermissionResult.backgroundDenied;
        } else {
          debugPrint('✅ Background location granted');
        }
      } else if (Platform.isIOS) {
        // For iOS, request always authorization
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always) {
          debugPrint('⚠️ iOS "Always" permission not granted - requesting again...');
          // Try requesting with permission_handler for better control
          final status = await ph.Permission.locationAlways.request();
          debugPrint('📍 iOS always location status: $status');

          if (!status.isGranted) {
            debugPrint('⚠️ iOS "Always" permission not granted - geofencing may not work in background');
            return LocationPermissionResult.backgroundDenied;
          } else {
            debugPrint('✅ iOS "Always" permission granted');
          }
        } else {
          debugPrint('✅ iOS "Always" permission already granted');
        }
      }
    }

    return LocationPermissionResult.granted;
  }

  /// Legacy method for backwards compatibility
  static Future<bool> requestPermission() async {
    debugPrint('🔍 Starting location permission request...');

    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location services are disabled');
      return false;
    }
    debugPrint('✅ Location services are enabled');

    // Check current permission status
    permission = await Geolocator.checkPermission();
    debugPrint('📍 Current permission: $permission');

    if (permission == LocationPermission.denied) {
      debugPrint('📍 Requesting location permission...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permission denied forever');
      return false;
    }

    debugPrint('✅ Basic location permission granted: $permission');

    // For geofencing, we need background location permission
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      debugPrint('📍 Requesting background location permission for geofencing...');

      if (Platform.isAndroid) {
        // Request background location for Android
        final status = await ph.Permission.locationAlways.request();
        debugPrint('📍 Android background location status: $status');

        if (!status.isGranted) {
          debugPrint('⚠️ Background location not granted - geofencing may not work when app is closed');
        } else {
          debugPrint('✅ Background location granted');
        }
      } else if (Platform.isIOS) {
        // For iOS, request always authorization
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always) {
          debugPrint('⚠️ iOS "Always" permission not granted - requesting again...');
          // Try requesting with permission_handler for better control
          final status = await ph.Permission.locationAlways.request();
          debugPrint('📍 iOS always location status: $status');

          if (!status.isGranted) {
            debugPrint('⚠️ iOS "Always" permission not granted - geofencing may not work in background');
          } else {
            debugPrint('✅ iOS "Always" permission granted');
          }
        } else {
          debugPrint('✅ iOS "Always" permission already granted');
        }
      }
    }

    return true;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      // Use high accuracy setting from SettingsService
      final useHighAccuracy = SettingsService.highAccuracy;
      final accuracy = useHighAccuracy ? LocationAccuracy.high : LocationAccuracy.medium;

      debugPrint('📍 Getting current position...');
      debugPrint('   - High accuracy mode: $useHighAccuracy');
      debugPrint('   - Accuracy: ${accuracy.name}');

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: const Duration(seconds: 10),
      );
      debugPrint('✅ Got position: ${position.latitude}, ${position.longitude}');
      debugPrint('   Accuracy: ${position.accuracy}m');
      return position;
    } catch (e) {
      debugPrint('❌ Error getting position: $e');
      return null;
    }
  }

  static Stream<Position> getLocationStream() {
    // Use settings from SettingsService
    final useHighAccuracy = SettingsService.highAccuracy;
    final accuracy = useHighAccuracy ? LocationAccuracy.high : LocationAccuracy.medium;
    final updateInterval = SettingsService.updateInterval;
    final distanceFilter = useHighAccuracy ? 10 : 20; // meters between updates

    debugPrint('📍 Starting location stream...');
    debugPrint('   - High accuracy mode: $useHighAccuracy');
    debugPrint('   - Accuracy: ${accuracy.name}');
    debugPrint('   - Update interval: ${updateInterval}s');
    debugPrint('   - Distance filter: ${distanceFilter}m');

    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        // iOS specific settings
        timeLimit: Duration(seconds: updateInterval),
      ),
    );
  }

  /// Check if background location permission is granted
  static Future<bool> hasBackgroundPermission() async {
    if (Platform.isAndroid) {
      final status = await ph.Permission.locationAlways.status;
      return status.isGranted;
    } else if (Platform.isIOS) {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always;
    }
    return false;
  }

  /// Open app settings for user to manually grant permissions
  static Future<void> openLocationSettings() async {
    await ph.openAppSettings();
  }
}
