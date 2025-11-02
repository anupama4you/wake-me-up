import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Adaptive location tracking that adjusts polling frequency based on distance to destination
/// - Far away (>5km): Update every 30 seconds
/// - Medium distance (1-5km): Update every 15 seconds  
/// - Getting close (500m-1km): Update every 10 seconds
/// - Very close (<500m): Update every 5 seconds
/// - Critical proximity (<100m): Update every 2-3 seconds
class AdaptiveLocationTracker {
  Timer? _timer;
  StreamController<Position>? _positionController;
  double? _targetLatitude;
  double? _targetLongitude;
  Position? _lastPosition;
  bool _isTracking = false;

  /// Start adaptive location tracking
  Stream<Position> startTracking({
    required double targetLatitude,
    required double targetLongitude,
  }) {
    _targetLatitude = targetLatitude;
    _targetLongitude = targetLongitude;
    _isTracking = true;

    _positionController = StreamController<Position>.broadcast();

    // Start with immediate position
    _updatePosition();

    return _positionController!.stream;
  }

  /// Stop tracking and clean up resources
  void stopTracking() {
    _isTracking = false;
    _timer?.cancel();
    _timer = null;
    _positionController?.close();
    _positionController = null;
    _lastPosition = null;
    debugPrint('🔋 Adaptive location tracking stopped');
  }

  /// Update position and schedule next update based on distance
  Future<void> _updatePosition() async {
    if (!_isTracking || _targetLatitude == null || _targetLongitude == null) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _lastPosition = position;

      // Calculate distance to target
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _targetLatitude!,
        _targetLongitude!,
      );

      // Determine next update interval based on distance
      final interval = _getUpdateInterval(distance);

      debugPrint('📍 Position updated: ${position.latitude}, ${position.longitude}');
      debugPrint('📏 Distance to target: ${distance.toStringAsFixed(0)}m');
      debugPrint('🔋 Next update in: ${interval.inSeconds}s (battery optimized)');

      // Emit position to stream
      if (_isTracking && !(_positionController?.isClosed ?? true)) {
        _positionController?.add(position);
      }

      // Schedule next update
      _timer?.cancel();
      _timer = Timer(interval, _updatePosition);
    } catch (e) {
      debugPrint('⚠️ Error updating position: $e');
      // Retry after default interval
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 15), _updatePosition);
    }
  }

  /// Determine update interval based on distance to target
  Duration _getUpdateInterval(double distanceInMeters) {
    if (distanceInMeters < 100) {
      // Critical proximity - update frequently
      return const Duration(seconds: 3);
    } else if (distanceInMeters < 500) {
      // Very close - update every 5 seconds
      return const Duration(seconds: 5);
    } else if (distanceInMeters < 1000) {
      // Getting close - update every 10 seconds
      return const Duration(seconds: 10);
    } else if (distanceInMeters < 5000) {
      // Medium distance - update every 15 seconds
      return const Duration(seconds: 15);
    } else {
      // Far away - update every 30 seconds
      return const Duration(seconds: 30);
    }
  }

  /// Get the last known position
  Position? get lastPosition => _lastPosition;

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Get current distance to target (if available)
  double? get distanceToTarget {
    if (_lastPosition == null || _targetLatitude == null || _targetLongitude == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      _targetLatitude!,
      _targetLongitude!,
    );
  }
}
