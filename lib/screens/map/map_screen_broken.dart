import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/alarm.dart';
import '../../services/location_service.dart';
import '../../services/google_places_service.dart';
import '../../services/geofence_service.dart';
import '../../services/alarm_storage_service.dart';

class MapScreen extends StatefulWidget {
  final Alarm? existingAlarm;
  const MapScreen({super.key, this.existingAlarm});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controllers
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  // Location state
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // Places API
  late final GooglePlacesService _googlePlacesService;
  final Duration _debounce = const Duration(milliseconds: 350);
  Timer? _debounceTimer;
  List<PlacePrediction> _predictions = [];
  bool _showPredictions = false;
  String? _sessionToken;

  // Alarm settings
  double _triggerRadius = 500.0; // Default 500m
  String _soundLevel = 'Loud';

  @override
  void initState() {
    super.initState();

    final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
    _googlePlacesService = GooglePlacesService(apiKey);

    // Load existing alarm if editing
    if (widget.existingAlarm != null) {
      final alarm = widget.existingAlarm!;
      _searchController.text = alarm.address;
      _selectedLocation = LatLng(alarm.latitude, alarm.longitude);
      _triggerRadius = alarm.radius;
      _soundLevel = alarm.soundLevel;
    }

    _requestPermissionAndLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _generateSessionToken() {
    final random = Random.secure();
    String randomHex(int length) {
      return List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
    }
    return '${randomHex(8)}-${randomHex(4)}-4${randomHex(3)}-${randomHex(4)}-${randomHex(12)}';
  }

  Future<void> _requestPermissionAndLocation() async {
    final hasPermission = await LocationService.requestPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required')),
      );
      return;
    }

    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      final currentLoc = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = currentLoc;
        if (widget.existingAlarm == null && _selectedLocation == null) {
          _selectedLocation = currentLoc;
        }
        _updateMapMarkers();
      });

      if (_mapController != null && _selectedLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
        );
      }
    }
  }

  void _updateMapMarkers() {
    final markers = <Marker>{};
    final circles = <Circle>{};

    if (_selectedLocation != null) {
      // Add marker for selected location
      markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              _selectedLocation = newPosition;
              _updateMapMarkers();
            });
          },
        ),
      );

      // Add circle for geofence radius
      circles.add(
        Circle(
          circleId: const CircleId('geofence'),
          center: _selectedLocation!,
          radius: _triggerRadius,
          fillColor: Colors.blue.withValues(alpha: 0.1),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  void _onSearchChanged(String input) {
    _debounceTimer?.cancel();

    if (input.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _showPredictions = false;
      });
      return;
    }

    _sessionToken ??= _generateSessionToken();

    _debounceTimer = Timer(_debounce, () async {
      try {
        LatLng? biasLocation = _currentLocation;

        if (_mapController != null) {
          try {
            final visibleRegion = await _mapController!.getVisibleRegion();
            biasLocation = LatLng(
              (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) / 2,
              (visibleRegion.northeast.longitude + visibleRegion.southwest.longitude) / 2,
            );
          } catch (_) {}
        }

        final result = await _googlePlacesService.autocomplete(
          input: input,
          sessionToken: _sessionToken,
          latitude: biasLocation?.latitude,
          longitude: biasLocation?.longitude,
          radiusMeters: 50000,
          regionCode: 'AU',
        );

        if (!mounted) return;

        final preds = result.suggestions
            .map((s) => s.placePrediction)
            .whereType<PlacePrediction>()
            .toList();

        setState(() {
          _predictions = preds;
          _showPredictions = preds.isNotEmpty;
        });
      } catch (e) {
        debugPrint('Error fetching predictions: $e');
      }
    });
  }

  Future<void> _onPredictionTapped(PlacePrediction prediction) async {
    setState(() {
      _showPredictions = false;
      _searchController.text = prediction.structuredFormat?.mainText?.text ?? prediction.text?.text ?? '';
    });

    try {
      final details = await _googlePlacesService.placeDetails(
        placeId: prediction.placeId,
        sessionToken: _sessionToken,
      );

      _sessionToken = null;

      final loc = details.location;
      if (loc == null || !mounted) return;

      final newLatLng = LatLng(loc.latitude, loc.longitude);

      setState(() {
        _selectedLocation = newLatLng;
        _searchController.text = details.formattedAddress ?? details.displayName?.text ?? prediction.text?.text ?? '';
        _updateMapMarkers();
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLatLng, 15),
      );
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _searchController.text = 'Selected Location';
      _showPredictions = false;
      _updateMapMarkers();
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );
  }

  void _goToCurrentLocation() async {
    LatLng? currentLoc = _currentLocation;

    if (currentLoc == null) {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;

      if (position != null) {
        currentLoc = LatLng(position.latitude, position.longitude);
        setState(() => _currentLocation = currentLoc);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
        return;
      }
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(currentLoc, 15),
    );
  }

  Future<void> _saveAlarm(bool activate) async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    final alarm = Alarm(
      id: widget.existingAlarm?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _searchController.text.isNotEmpty ? _searchController.text : 'My Alarm',
      address: _searchController.text.isNotEmpty ? _searchController.text : 'Selected Location',
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      radius: _triggerRadius,
      soundLevel: _soundLevel,
      isActive: activate,
    );

    // Save alarm
    await AlarmStorageService.saveAlarm(alarm);

    // Start geofencing if activated
    if (activate) {
      await GeofenceAlarmService().startGeofencing(alarm);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(activate ? 'Alarm activated!' : 'Alarm saved for later'),
        backgroundColor: activate ? Colors.green : Colors.blue,
      ),
    );

    Navigator.of(context).pop(alarm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingAlarm != null ? 'Edit Alarm' : 'Set Location',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_selectedLocation != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ?? const LatLng(-33.8688, 151.2093),
              zoom: 15,
            ),
            markers: _markers,
            circles: _circles,
            onTap: _onMapTapped,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Search bar at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                children: [
                  // Search box
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search location or enter address...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  // Predictions dropdown
                  if (_showPredictions && _predictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        itemCount: _predictions.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];
                          return ListTile(
                            leading: Icon(Icons.location_on, color: Colors.grey[600]),
                            title: Text(
                              prediction.structuredFormat?.mainText?.text ?? prediction.text?.text ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: prediction.structuredFormat?.secondaryText?.text != null
                                ? Text(
                                    prediction.structuredFormat!.secondaryText!.text,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  )
                                : null,
                            onTap: () => _onPredictionTapped(prediction),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // My Location button
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _goToCurrentLocation,
              child: Icon(Icons.my_location, color: Colors.blue[700]),
            ),
          ),

          // Bottom sheet with alarm settings
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.4,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title
                    const Text(
                      'Alarm Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Trigger Radius
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Trigger Radius',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_triggerRadius.toInt()}m',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _triggerRadius,
                      min: 100,
                      max: 2000,
                      divisions: 19,
                      activeColor: Colors.blue[600],
                      onChanged: (value) {
                        setState(() {
                          _triggerRadius = value;
                          _updateMapMarkers();
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '100m',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '2km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Alarm Sound
                    const Text(
                      'Alarm Sound',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSoundButton('Loud'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSoundButton('Medium'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSoundButton('Soft'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _saveAlarm(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Save for Later',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _selectedLocation != null
                                ? () => _saveAlarm(true)
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Start Alarm',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSoundButton(String level) {
    final isSelected = _soundLevel == level;
    return GestureDetector(
      onTap: () => setState(() => _soundLevel = level),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          level,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.blue[700] : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
