import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

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
      debugPrint('📍 Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
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
    debugPrint('📍 Starting location stream...');
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
        // iOS specific settings
        timeLimit: const Duration(seconds: 5),
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
