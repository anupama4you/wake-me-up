import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math';
import '../models/alarm.dart';
import '../services/location_service.dart';

class ActiveAlarmScreen extends StatefulWidget {
  final Alarm alarm;
  const ActiveAlarmScreen({Key? key, required this.alarm}) : super(key: key);

  @override
  State<ActiveAlarmScreen> createState() => _ActiveAlarmScreenState();
}

class _ActiveAlarmScreenState extends State<ActiveAlarmScreen> {
  GoogleMapController? _mapController;
  StreamSubscription? _locationSubscription;
  LatLng? _currentLocation;
  double _distanceToTarget = 0;
  bool _alarmTriggered = false;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _updateMapMarkers();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
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

    // Target radius circle
    final circles = <Circle>{
      Circle(
        circleId: const CircleId('target_radius'),
        center: LatLng(widget.alarm.latitude, widget.alarm.longitude),
        radius: widget.alarm.radius,
        fillColor: (_alarmTriggered ? Colors.green : Colors.red)
            .withOpacity(0.2),
        strokeColor: _alarmTriggered ? Colors.green : Colors.red,
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

    // Show alarm dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.green[600], size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Alarm Triggered!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have arrived at:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              widget.alarm.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.alarm.address,
                      style: TextStyle(color: Colors.green[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to home
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    // Play sound (you can implement actual sound playing here)
    // For now, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.volume_up, color: Colors.white),
            const SizedBox(width: 8),
            Text('Playing ${widget.alarm.soundLevel} alarm sound'),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 3),
      ),
    );
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
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to home
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
        backgroundColor: Colors.green[600],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle),
            onPressed: _stopAlarm,
            tooltip: 'Stop Alarm',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _alarmTriggered ? Colors.green[600] : Colors.blue[600],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  _alarmTriggered
                      ? Icons.check_circle
                      : Icons.my_location,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _alarmTriggered
                      ? 'Alarm Triggered!'
                      : 'Tracking Your Location',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentLocation == null
                      ? 'Getting location...'
                      : '${_distanceToTarget.toStringAsFixed(0)}m away from target',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
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
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),

          // Bottom info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.alarm.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.alarm.address,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoChip(
                      Icons.radio_button_checked,
                      'Radius',
                      '${widget.alarm.radius.toInt()}m',
                    ),
                    _buildInfoChip(
                      Icons.volume_up,
                      'Sound',
                      widget.alarm.soundLevel,
                    ),
                    _buildInfoChip(
                      Icons.navigation,
                      'Distance',
                      '${_distanceToTarget.toStringAsFixed(0)}m',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[600], size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}