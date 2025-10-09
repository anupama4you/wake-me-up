import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import '../models/alarm.dart';
import 'map_screen.dart';

class MapViewScreen extends StatefulWidget {
  final List<Alarm> alarms;
  const MapViewScreen({Key? key, required this.alarms}) : super(key: key);

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  Alarm? _selectedAlarm;
  bool _showActiveOnly = false;

  @override
  void initState() {
    super.initState();
    _updateMapMarkers();
  }

  @override
  void didUpdateWidget(MapViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alarms != widget.alarms) {
      _updateMapMarkers();
    }
  }

  List<Alarm> get _filteredAlarms {
    if (_showActiveOnly) {
      return widget.alarms.where((alarm) => alarm.isActive).toList();
    }
    return widget.alarms;
  }

  void _updateMapMarkers() {
    final markers = <Marker>{};
    final circles = <Circle>{};
    final alarms = _filteredAlarms;

    for (var alarm in alarms) {
      final isSelected = _selectedAlarm?.id == alarm.id;

      markers.add(
        Marker(
          markerId: MarkerId(alarm.id),
          position: LatLng(alarm.latitude, alarm.longitude),
          infoWindow: InfoWindow(
            title: alarm.name,
            snippet: '${alarm.radius.toInt()}m • ${alarm.isActive ? "Active" : "Inactive"}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            alarm.isActive ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          alpha: isSelected ? 1.0 : 0.8,
          onTap: () => _onMarkerTapped(alarm),
        ),
      );

      circles.add(
        Circle(
          circleId: CircleId(alarm.id),
          center: LatLng(alarm.latitude, alarm.longitude),
          radius: alarm.radius,
          fillColor: (alarm.isActive ? Colors.green : Colors.grey).withOpacity(
            isSelected ? 0.3 : 0.15,
          ),
          strokeColor: alarm.isActive ? Colors.green : Colors.grey,
          strokeWidth: isSelected ? 3 : 2,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });

    // Fit all markers in view if we have alarms
    if (alarms.isNotEmpty && _mapController != null) {
      _fitAllMarkers(alarms);
    }
  }

  void _fitAllMarkers(List<Alarm> alarms) {
    if (alarms.isEmpty) return;

    // If only one alarm, just zoom to it
    if (alarms.length == 1) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(alarms.first.latitude, alarms.first.longitude),
            15,
          ),
        );
      });
      return;
    }

    double minLat = alarms.first.latitude;
    double maxLat = alarms.first.latitude;
    double minLng = alarms.first.longitude;
    double maxLng = alarms.first.longitude;

    for (var alarm in alarms) {
      minLat = min(minLat, alarm.latitude);
      maxLat = max(maxLat, alarm.latitude);
      minLng = min(minLng, alarm.longitude);
      maxLng = max(maxLng, alarm.longitude);
    }

    // Add some padding to bounds
    const double padding = 0.001;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    });
  }

  void _onMarkerTapped(Alarm alarm) {
    setState(() {
      _selectedAlarm = alarm;
    });
  }

  void _zoomToAlarm(Alarm alarm) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(alarm.latitude, alarm.longitude),
        16,
      ),
    );
    setState(() {
      _selectedAlarm = alarm;
    });
  }

  void _showAllAlarms() {
    setState(() {
      _selectedAlarm = null;
    });
    _fitAllMarkers(_filteredAlarms);
  }

  Widget _buildAlarmCard(Alarm alarm) {
    final isSelected = _selectedAlarm?.id == alarm.id;

    return GestureDetector(
      onTap: () => _zoomToAlarm(alarm),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (alarm.isActive ? Colors.green : Colors.blue)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (alarm.isActive ? Colors.green : Colors.grey)
                    .withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                alarm.isActive ? Icons.notifications_active : Icons.notifications_off,
                color: alarm.isActive ? Colors.green[700] : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${alarm.radius.toInt()}m radius',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.location_on,
              color: alarm.isActive ? Colors.green[600] : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAlarmsList() {
    final alarms = _filteredAlarms;

    if (alarms.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        // Add safe area padding at the bottom for navigation bar
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
        ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${alarms.length} Alarm${alarms.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (alarms.length > 1)
                    TextButton.icon(
                      onPressed: _showAllAlarms,
                      icon: const Icon(Icons.zoom_out_map, size: 16),
                      label: const Text('Show All'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
            ),
            // Horizontal list
            SizedBox(
              height: 80, // Fixed height instead of Expanded
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: alarms.length,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 200,
                    child: _buildAlarmCard(alarms[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip() {
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            setState(() {
              _showActiveOnly = !_showActiveOnly;
              _selectedAlarm = null;
            });
            _updateMapMarkers();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _showActiveOnly ? Colors.green[50] : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showActiveOnly ? Icons.check_circle : Icons.filter_alt,
                  size: 18,
                  color: _showActiveOnly ? Colors.green[700] : Colors.grey[700],
                ),
                const SizedBox(width: 4),
                Text(
                  _showActiveOnly ? 'Active Only' : 'All Alarms',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _showActiveOnly ? Colors.green[700] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      top: 70,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            heroTag: 'mapViewZoomIn',
            onPressed: () {
              _mapController?.animateCamera(CameraUpdate.zoomIn());
            },
            child: const Icon(Icons.add, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            heroTag: 'mapViewZoomOut',
            onPressed: () {
              _mapController?.animateCamera(CameraUpdate.zoomOut());
            },
            child: const Icon(Icons.remove, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 16,
      left: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Active',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Inactive',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alarms.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Map View', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue[600],
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 100, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No Alarms Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create an alarm to see it on the map',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Create Alarm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[600],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _updateMapMarkers();
              _showAllAlarms();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _fitAllMarkers(_filteredAlarms);
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.alarms.first.latitude,
                widget.alarms.first.longitude,
              ),
              zoom: 13.0,
            ),
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: (_) {
              setState(() {
                _selectedAlarm = null;
              });
            },
          ),

          // Legend
          _buildLegend(),

          // Filter chip
          _buildFilterChip(),

          // Zoom controls
          _buildZoomControls(),

          // Bottom alarms list
          _buildBottomAlarmsList(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}