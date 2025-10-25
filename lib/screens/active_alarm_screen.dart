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

    // No app notification - phone notification handles alarm trigger
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Active Alarm',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Alarm Card with Map Preview
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border(
                  left: BorderSide(
                    color: _alarmTriggered ? Colors.green : Colors.blue,
                    width: 4,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Map Preview
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: SizedBox(
                      height: 200,
                      child: GoogleMap(
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
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        zoomGesturesEnabled: false,
                        scrollGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                      ),
                    ),
                  ),

                  // Card Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with name and status badge
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.alarm.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.alarm.address,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _alarmTriggered
                                    ? Colors.green[100]
                                    : Colors.blue[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _alarmTriggered ? 'ARRIVED' : 'ACTIVE',
                                style: TextStyle(
                                  color: _alarmTriggered
                                      ? Colors.green[700]
                                      : Colors.blue[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Info chips
                        Row(
                          children: [
                            Icon(
                              Icons.radio_button_checked,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.alarm.radius.toInt()}m radius',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.volume_up,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.alarm.soundLevel,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Distance indicator
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _alarmTriggered
                                    ? Colors.green[50]
                                    : Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _alarmTriggered
                                      ? Colors.green[200]!
                                      : Colors.blue[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.scale(
                                    scale: _alarmTriggered ? 1.0 : _pulseAnimation.value,
                                    child: Icon(
                                      _alarmTriggered
                                          ? Icons.check_circle
                                          : Icons.navigation,
                                      color: _alarmTriggered
                                          ? Colors.green[700]
                                          : Colors.blue[700],
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentLocation == null
                                        ? 'Getting location...'
                                        : _alarmTriggered
                                            ? 'You\'ve arrived!'
                                            : '${_distanceToTarget.toStringAsFixed(0)}m away',
                                    style: TextStyle(
                                      color: _alarmTriggered
                                          ? Colors.green[900]
                                          : Colors.blue[900],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                        Divider(height: 1, color: Colors.grey[200]),
                        const SizedBox(height: 16),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _stopAlarm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[50],
                                  foregroundColor: Colors.red[600],
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Stop',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _alarmTriggered ? _deactivateAlarmAndReturn : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _alarmTriggered
                                      ? Colors.green[600]
                                      : Colors.blue[50],
                                  foregroundColor: _alarmTriggered
                                      ? Colors.white
                                      : Colors.blue[600],
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _alarmTriggered ? 'Finish' : 'View Map',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Tip Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _alarmTriggered ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _alarmTriggered ? Colors.green[200]! : Colors.blue[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _alarmTriggered ? Icons.check_circle_outline : Icons.info_outline,
                    color: _alarmTriggered ? Colors.green[700] : Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _alarmTriggered ? 'Congratulations!' : 'Tracking Active',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _alarmTriggered ? Colors.green[900] : Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _alarmTriggered
                              ? 'You\'ve reached your destination. Tap "Finish" to complete the alarm.'
                              : 'Your location is being monitored. You\'ll be alerted when you enter the geofence area.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _alarmTriggered ? Colors.green[700] : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}