import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Calculate Estimated Time of Arrival (ETA) based on movement speed
/// This provides users with intuitive time-based progress instead of percentages
class ETACalculator {
  static Position? _previousPosition;
  static DateTime? _previousTime;
  static double? _averageSpeed; // meters per second
  static final List<double> _speedSamples = [];
  static const int _maxSpeedSamples = 5; // Use last 5 samples for averaging

  /// Calculate ETA based on current movement speed
  /// Returns null if not enough data to calculate ETA
  static Duration? calculateETA({
    required double currentDistance,
    required Position currentPosition,
  }) {
    final now = DateTime.now();

    // Need at least 2 position updates to calculate speed
    if (_previousPosition == null || _previousTime == null) {
      _previousPosition = currentPosition;
      _previousTime = now;
      return null;
    }

    // Calculate time difference in seconds
    final timeDiff = now.difference(_previousTime!).inSeconds;

    // Ignore if time difference is too small (less than 5 seconds)
    if (timeDiff < 5) {
      return null;
    }

    // Calculate distance traveled since last update
    final distanceTraveled = Geolocator.distanceBetween(
      _previousPosition!.latitude,
      _previousPosition!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    // Calculate instantaneous speed (meters per second)
    final instantSpeed = distanceTraveled / timeDiff;

    // Update position and time for next calculation
    _previousPosition = currentPosition;
    _previousTime = now;

    // Add to speed samples for averaging
    _speedSamples.add(instantSpeed);
    if (_speedSamples.length > _maxSpeedSamples) {
      _speedSamples.removeAt(0); // Remove oldest sample
    }

    // Calculate average speed from samples
    if (_speedSamples.isEmpty) {
      return null;
    }

    _averageSpeed = _speedSamples.reduce((a, b) => a + b) / _speedSamples.length;

    // If not moving (less than 0.5 m/s = 1.8 km/h)
    if (_averageSpeed! < 0.5) {
      debugPrint('🚶 Not moving (${(_averageSpeed! * 3.6).toStringAsFixed(1)} km/h)');
      return null;
    }

    // Calculate ETA = distance / speed
    final etaSeconds = (currentDistance / _averageSpeed!).round();

    debugPrint('📍 ETA Calculation:');
    debugPrint('   Distance: ${currentDistance.toStringAsFixed(0)}m');
    debugPrint('   Speed: ${(_averageSpeed! * 3.6).toStringAsFixed(1)} km/h');
    debugPrint('   ETA: ${formatETA(Duration(seconds: etaSeconds))}');

    return Duration(seconds: etaSeconds);
  }

  /// Format ETA for display
  static String formatETA(Duration? eta, {bool shortFormat = false}) {
    if (eta == null) {
      return shortFormat ? '--' : 'Calculating...';
    }

    if (eta.inSeconds < 60) {
      return shortFormat ? '<1 min' : 'Arriving now';
    } else if (eta.inMinutes < 60) {
      final mins = eta.inMinutes;
      return shortFormat ? '$mins min' : '$mins min away';
    } else {
      final hours = eta.inHours;
      final mins = eta.inMinutes % 60;
      if (mins == 0) {
        return shortFormat ? '${hours}h' : '${hours}h away';
      }
      return shortFormat ? '${hours}h ${mins}m' : '${hours}h ${mins}m away';
    }
  }

  /// Format speed for display (km/h)
  static String formatSpeed(double? metersPerSecond) {
    if (metersPerSecond == null || metersPerSecond < 0.5) {
      return 'Not moving';
    }

    final kmh = metersPerSecond * 3.6;

    if (kmh < 5) {
      return 'Walking (${kmh.toStringAsFixed(1)} km/h)';
    } else if (kmh < 20) {
      return 'Cycling (${kmh.toStringAsFixed(1)} km/h)';
    } else if (kmh < 60) {
      return 'Driving (${kmh.toStringAsFixed(0)} km/h)';
    } else {
      return 'Fast (${kmh.toStringAsFixed(0)} km/h)';
    }
  }

  /// Get current average speed in m/s
  static double? get averageSpeed => _averageSpeed;

  /// Get current average speed in km/h
  static double? get averageSpeedKmh =>
      _averageSpeed != null ? _averageSpeed! * 3.6 : null;

  /// Reset ETA calculation (call when alarm is toggled or location tracking starts)
  static void reset() {
    _previousPosition = null;
    _previousTime = null;
    _averageSpeed = null;
    _speedSamples.clear();
    debugPrint('🔄 ETA calculator reset');
  }

  /// Calculate simple progress percentage based on distance
  /// Returns value between 0.0 and 1.0
  static double calculateProgress({
    required double currentDistance,
    required double targetRadius,
  }) {
    // If within geofence radius, 100% complete
    if (currentDistance <= targetRadius) {
      return 1.0;
    }

    // Use a maximum distance for progress calculation (5km)
    const maxDistance = 5000.0;

    // If more than max distance away, show 0% progress
    if (currentDistance >= maxDistance) {
      return 0.0;
    }

    // Linear progress from maxDistance (0%) to targetRadius (100%)
    final progress = 1.0 - ((currentDistance - targetRadius) / (maxDistance - targetRadius));
    return progress.clamp(0.0, 1.0);
  }

  /// Get progress color based on distance and ETA
  static Color getProgressColor({
    required double progress,
    Duration? eta,
  }) {
    // If ETA is available, use time-based coloring
    if (eta != null) {
      if (eta.inMinutes <= 5) {
        return Colors.green; // Arriving very soon
      } else if (eta.inMinutes <= 15) {
        return Colors.lightGreen; // Arriving soon
      } else if (eta.inMinutes <= 30) {
        return Colors.blue; // On the way
      } else {
        return Colors.grey; // Far away
      }
    }

    // Fallback to distance-based coloring
    if (progress >= 0.75) {
      return Colors.green;
    } else if (progress >= 0.40) {
      return Colors.lightGreen;
    } else {
      return Colors.blue;
    }
  }
}
