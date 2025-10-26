import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/alarm.dart';
import '../theme/app_theme.dart';

/// Live map view showing current location and destination
class AlarmDetailMapScreen extends StatefulWidget {
  final Alarm alarm;

  const AlarmDetailMapScreen({
    super.key,
    required this.alarm,
  });

  @override
  State<AlarmDetailMapScreen> createState() => _AlarmDetailMapScreenState();
}

class _AlarmDetailMapScreenState extends State<AlarmDetailMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Timer? _locationUpdateTimer;

  // Map markers and circles
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// Start tracking location
  void _startLocationTracking() {
    // Get initial location
    _updateCurrentLocation();

    // Update every 2 seconds for smooth tracking
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateCurrentLocation();
    });
  }

  /// Update current location
  Future<void> _updateCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _updateMapMarkers();
          _updateMapCamera();
        });
      }
    } catch (e) {
      debugPrint('Location update error: $e');
    }
  }

  /// Update map markers
  void _updateMapMarkers() {
    if (_currentPosition == null) return;

    _markers.clear();
    _circles.clear();
    _polylines.clear();

    // Current location marker
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Current position',
        ),
      ),
    );

    // Destination marker
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.alarm.latitude, widget.alarm.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: widget.alarm.name,
          snippet: widget.alarm.address,
        ),
      ),
    );

    // Geofence circle
    _circles.add(
      Circle(
        circleId: const CircleId('geofence'),
        center: LatLng(widget.alarm.latitude, widget.alarm.longitude),
        radius: widget.alarm.radius,
        fillColor: AppTheme.accentGreen.withValues(alpha: 0.15),
        strokeColor: AppTheme.accentGreen,
        strokeWidth: 2,
      ),
    );

    // Route line
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          LatLng(widget.alarm.latitude, widget.alarm.longitude),
        ],
        color: AppTheme.primaryColor,
        width: 3,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
  }

  /// Update camera to show both locations
  void _updateMapCamera() {
    if (_mapController == null || _currentPosition == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(_currentPosition!.latitude, widget.alarm.latitude),
        min(_currentPosition!.longitude, widget.alarm.longitude),
      ),
      northeast: LatLng(
        max(_currentPosition!.latitude, widget.alarm.latitude),
        max(_currentPosition!.longitude, widget.alarm.longitude),
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100), // 100 padding
    );
  }

  /// Calculate distance
  double _calculateDistance() {
    if (_currentPosition == null) return 0;

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.alarm.latitude,
      widget.alarm.longitude,
    );
  }

  /// Calculate progress
  /// Progress always shows based on current distance with dynamic scale
  int _calculateProgress(double currentDistance) {
    final targetRadius = widget.alarm.radius;

    // If inside geofence, you've arrived
    if (currentDistance <= targetRadius) {
      return 100;
    }

    // Dynamic scale based on distance ranges
    if (currentDistance > 10000) {
      // More than 10km: show 1-10%
      final ratio = (currentDistance - 10000) / 10000;
      return max(1, (10 - (ratio * 5)).round()).clamp(1, 10);
    } else if (currentDistance > 5000) {
      // 5-10km: show 10-30%
      final ratio = (10000 - currentDistance) / 5000;
      return (10 + (ratio * 20)).round();
    } else if (currentDistance > 2000) {
      // 2-5km: show 30-50%
      final ratio = (5000 - currentDistance) / 3000;
      return (30 + (ratio * 20)).round();
    } else if (currentDistance > 1000) {
      // 1-2km: show 50-70%
      final ratio = (2000 - currentDistance) / 1000;
      return (50 + (ratio * 20)).round();
    } else if (currentDistance > targetRadius) {
      // Less than 1km but outside radius: show 70-99%
      final ratio = (1000 - currentDistance) / (1000 - targetRadius);
      return (70 + (ratio * 29)).round().clamp(70, 99);
    }

    return 100;
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();
    final progress = _calculateProgress(distance);

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.alarm.latitude, widget.alarm.longitude),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateMapMarkers();
              _updateMapCamera();
            },
            markers: _markers,
            circles: _circles,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            compassEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Top info card
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopInfoCard(
              alarm: widget.alarm,
              distance: distance,
              progress: progress,
              onClose: () => Navigator.pop(context),
            ),
          ),

          // Bottom stats card
          if (_currentPosition != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomStatsCard(
                alarm: widget.alarm,
                currentPosition: _currentPosition!,
                distance: distance,
                progress: progress,
              ),
            ),
        ],
      ),
    );
  }
}

/* ---------------------------- Top Info Card ----------------------------- */

class _TopInfoCard extends StatelessWidget {
  final Alarm alarm;
  final double distance;
  final int progress;
  final VoidCallback onClose;

  const _TopInfoCard({
    required this.alarm,
    required this.distance,
    required this.progress,
    required this.onClose,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressColor = progress >= 75
        ? AppTheme.successColor
        : progress >= 40
            ? AppTheme.accentGreen
            : AppTheme.primaryColor;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.name,
                        style: AppTheme.headingLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alarm.address,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.borderLightColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Distance and progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.navigation_rounded,
                      color: progressColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDistance(distance),
                      style: AppTheme.headingMedium.copyWith(
                        color: progressColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'away',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$progress%',
                    style: AppTheme.labelLarge.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8,
                backgroundColor: AppTheme.borderLightColor,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------- Bottom Stats Card --------------------------- */

class _BottomStatsCard extends StatelessWidget {
  final Alarm alarm;
  final Position currentPosition;
  final double distance;
  final int progress;

  const _BottomStatsCard({
    required this.alarm,
    required this.currentPosition,
    required this.distance,
    required this.progress,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate if inside geofence
    final insideGeofence = distance <= alarm.radius;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.track_changes_rounded,
                  label: 'Distance',
                  value: _formatDistance(distance),
                  color: AppTheme.primaryColor,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.radio_button_checked_rounded,
                  label: 'Radius',
                  value: '${alarm.radius.round()}m',
                  color: AppTheme.accentGreen,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.location_on_rounded,
                  label: 'Status',
                  value: insideGeofence ? 'Inside' : 'Outside',
                  color: insideGeofence ? AppTheme.successColor : AppTheme.warningColor,
                ),
              ),
            ],
          ),

          if (insideGeofence) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You have reached your destination!',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ------------------------------- Stat Item ------------------------------ */

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTheme.headingSmall.copyWith(
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}
