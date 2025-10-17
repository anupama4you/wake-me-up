import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math';
import '../models/alarm.dart';
import '../services/location_service.dart';
import '../services/alarm_storage_service.dart';
import '../services/geofence_service.dart';
import '../services/alarm_sound_service.dart';

class ActiveAlarmScreen extends StatefulWidget {
  final Alarm alarm;
  const ActiveAlarmScreen({Key? key, required this.alarm}) : super(key: key);

  @override
  State<ActiveAlarmScreen> createState() => _ActiveAlarmScreenState();
}

class _ActiveAlarmScreenState extends State<ActiveAlarmScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  StreamSubscription? _locationSubscription;
  LatLng? _currentLocation;
  double _distanceToTarget = 0;
  bool _alarmTriggered = false;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation for active tracking
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startLocationTracking();
    _updateMapMarkers();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startLocationTracking() async {
    // Get initial location
    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _calculateDistance();
        _updateMapMarkers();
      });
    }

    // Start listening to location updates
    _locationSubscription = LocationService.getLocationStream().listen(
          (position) {
        if (!mounted) return;

        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _calculateDistance();
          _updateMapMarkers();
        });

        // Check if alarm should trigger
        if (_distanceToTarget <= widget.alarm.radius && !_alarmTriggered) {
          _triggerAlarm();
        }

        // Update camera to follow user
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation!),
        );
      },
      onError: (error) {
        print('Location error: $error');
      },
    );
  }

  void _calculateDistance() {
    if (_currentLocation == null) return;

    const double earthRadius = 6371000; // meters
    final dLat = _degreesToRadians(
        widget.alarm.latitude - _currentLocation!.latitude);
    final dLng = _degreesToRadians(
        widget.alarm.longitude - _currentLocation!.longitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(_currentLocation!.latitude)) *
            cos(_degreesToRadians(widget.alarm.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    _distanceToTarget = earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _updateMapMarkers() {
    final markers = <Marker>{};

    // Target location marker
    markers.add(
      Marker(
        markerId: const MarkerId('target'),
        position: LatLng(widget.alarm.latitude, widget.alarm.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _alarmTriggered ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: widget.alarm.name,
          snippet: 'Target Location',
        ),
      ),
    );

    // Current location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'You are here',
          ),
        ),
      );
    }

    // Target radius circles with pulse effect
    final baseColor = _alarmTriggered ? Colors.green : Colors.blue;
    final circles = <Circle>{
      // Inner circle
      Circle(
        circleId: const CircleId('target_radius_inner'),
        center: LatLng(widget.alarm.latitude, widget.alarm.longitude),
        radius: widget.alarm.radius,
        fillColor: baseColor.withValues(alpha: 0.25),
        strokeColor: baseColor,
        strokeWidth: 3,
      ),
      // Outer pulsing circle
      Circle(
        circleId: const CircleId('target_radius_outer'),
        center: LatLng(widget.alarm.latitude, widget.alarm.longitude),
        radius: widget.alarm.radius * 1.2,
        fillColor: baseColor.withValues(alpha: 0.1),
        strokeColor: baseColor.withValues(alpha: 0.5),
        strokeWidth: 2,
      ),
    };

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  void _triggerAlarm() {
    setState(() {
      _alarmTriggered = true;
      _updateMapMarkers();
    });

    // Stop the pulse animation when alarm triggers
    _pulseController.stop();

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'You\'ve arrived! Tap "Finish" to complete.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Deactivate the alarm and return to home screen
  Future<void> _deactivateAlarmAndReturn() async {
    debugPrint('🛑 Deactivating alarm: ${widget.alarm.name}');

    try {
      // Stop alarm sound and vibration first
      final alarmSoundService = AlarmSoundService();
      await alarmSoundService.stopAlarm();
      debugPrint('🔇 Alarm sound stopped');

      // Update alarm status to inactive
      widget.alarm.isActive = false;
      await AlarmStorageService.updateAlarm(widget.alarm);
      debugPrint('✅ Alarm deactivated in storage');

      // Stop geofencing
      final geofenceService = GeofenceAlarmService();
      await geofenceService.stopGeofencing(widget.alarm.id);
      debugPrint('✅ Geofencing stopped');
    } catch (e) {
      debugPrint('❌ Error deactivating alarm: $e');
    }

    // Return to home screen with result to trigger reload
    if (mounted) {
      Navigator.pop(context, true); // true = alarm was stopped
    }
  }

  void _stopAlarm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Alarm?'),
        content: const Text('Are you sure you want to stop this alarm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _deactivateAlarmAndReturn();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.alarm.name,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: _alarmTriggered ? Colors.green[600] : Colors.blue[600],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Animated status card
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _alarmTriggered
                            ? [Colors.green[600]!, Colors.green[700]!]
                            : [Colors.blue[600]!, Colors.blue[700]!],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Animated icon
                        Transform.scale(
                          scale: _alarmTriggered ? 1.0 : _pulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _alarmTriggered
                                  ? Icons.notifications_active
                                  : Icons.my_location,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _alarmTriggered
                              ? 'You\'ve Arrived!'
                              : 'Tracking Your Location',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentLocation == null
                                ? 'Getting location...'
                                : '${_distanceToTarget.toStringAsFixed(0)}m away',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Map with animated overlay
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_currentLocation != null) {
                          controller.animateCamera(
                            CameraUpdate.newLatLngZoom(_currentLocation!, 15),
                          );
                        }
                      },
                      initialCameraPosition: CameraPosition(
                        target: LatLng(widget.alarm.latitude, widget.alarm.longitude),
                        zoom: 15,
                      ),
                      markers: _markers,
                      circles: _circles,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: false,
                    ),
                  ],
                ),
              ),

              // Bottom info card with finish button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Location info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (_alarmTriggered ? Colors.green : Colors.blue)[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: (_alarmTriggered ? Colors.green : Colors.blue)[700],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.alarm.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.alarm.address,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoChip(
                            Icons.radio_button_checked,
                            'Radius',
                            '${widget.alarm.radius.toInt()}m',
                            _alarmTriggered ? Colors.green : Colors.blue,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          _buildInfoChip(
                            Icons.volume_up,
                            'Sound',
                            widget.alarm.soundLevel,
                            _alarmTriggered ? Colors.green : Colors.blue,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          _buildInfoChip(
                            Icons.navigation,
                            'Distance',
                            '${_distanceToTarget.toStringAsFixed(0)}m',
                            _alarmTriggered ? Colors.green : Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _alarmTriggered ? _deactivateAlarmAndReturn : _stopAlarm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _alarmTriggered ? Colors.green[600] : Colors.red[600],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _alarmTriggered ? Icons.check_circle : Icons.stop_circle,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _alarmTriggered ? 'Finish & Return Home' : 'Stop Tracking',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, MaterialColor color) {
    return Column(
      children: [
        Icon(icon, color: color[600], size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.grey[900],
          ),
        ),
      ],
    );
  }
}