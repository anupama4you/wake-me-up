import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import '../models/alarm.dart';
import '../services/location_service.dart';
import 'active_alarm_screen.dart';

// Location types enum
enum LocationType {
  all('', Icons.grid_view, 'All', Colors.blue),
  busStop('bus_station', Icons.directions_bus, 'Bus', Colors.orange),
  trainStation('train_station', Icons.train, 'Train', Colors.green),
  tramStop('light_rail_station', Icons.tram, 'Tram', Colors.purple),
  subway('subway_station', Icons.subway, 'Metro', Colors.red),
  transitStation('transit_station', Icons.commute, 'Transit', Colors.teal),
  airport('airport', Icons.local_airport, 'Airport', Colors.indigo),
  university('university', Icons.school, 'University', Colors.amber),
  hospital('hospital', Icons.local_hospital, 'Hospital', Colors.pink),
  shoppingMall('shopping_mall', Icons.shopping_bag, 'Mall', Colors.deepOrange),
  park('park', Icons.park, 'Park', Colors.lightGreen);

  final String googleType;
  final IconData icon;
  final String label;
  final Color color;

  const LocationType(this.googleType, this.icon, this.label, this.color);
}

class MapScreen extends StatefulWidget {
  final Alarm? existingAlarm;
  const MapScreen({Key? key, this.existingAlarm}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ---- Map & UI state ----
  final GlobalKey _mapKey = GlobalKey();
  GoogleMapController? _mapController;

  double _radius = 500;
  String _selectedSound = 'Loud';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  LatLng _selectedLocation = const LatLng(-34.9285, 138.6007);
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // ---- Places state ----
  late final GooglePlace _googlePlace;
  final Duration _debounce = const Duration(milliseconds: 350);
  Timer? _debounceTimer;
  List<AutocompletePrediction> _predictions = [];
  List<DetailsResult> _nearbyLocations = [];
  bool _showPredictions = false;
  bool _showingLocations = false;
  bool _hasValidLocation = false;
  bool _isLoadingLocations = false;

  // ---- Category filter ----
  LocationType _selectedCategory = LocationType.all;
  LatLng? _searchCenterLocation;

  static const _kGoogleApiKey = 'AIzaSyAtur8-rQYbfmurhULUT00-eHqfhIAGJRQ';

  @override
  void initState() {
    super.initState();

    _googlePlace = GooglePlace(_kGoogleApiKey);

    if (widget.existingAlarm != null) {
      final a = widget.existingAlarm!;
      _radius = a.radius;
      _selectedSound = a.soundLevel;
      _nameController.text = a.name;
      _addressController.text = a.address;
      _selectedLocation = LatLng(a.latitude, a.longitude);
      _hasValidLocation = true;
    }

    _requestPermissionAndLocation();
    _updateMapMarkers();

    _addressController.addListener(() {
      if (_addressController.text.isEmpty && _showPredictions) {
        setState(() {
          _showPredictions = false;
          _showingLocations = false;
          _nearbyLocations = [];
          _searchCenterLocation = null;
          _updateMapMarkers();
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    _mapController = null;
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ------- Location -------
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
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        // Only set selected location if no existing alarm
        if (widget.existingAlarm == null && !_hasValidLocation) {
          _selectedLocation = _currentLocation!;
        }
        _updateMapMarkers();
      });

      if (_mapController != null && widget.existingAlarm == null && !_hasValidLocation) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation, 15),
        );
      }
    }
  }

  void _updateMapMarkers() {
    final markers = <Marker>{};

    // Add nearby location markers (smaller, lighter)
    for (var location in _nearbyLocations) {
      final loc = location.geometry?.location;
      if (loc == null) continue;

      final latLng = LatLng(loc.lat!, loc.lng!);

      // Skip if this is the selected location
      if (_hasValidLocation &&
          (latLng.latitude - _selectedLocation.latitude).abs() < 0.0001 &&
          (latLng.longitude - _selectedLocation.longitude).abs() < 0.0001) {
        continue;
      }

      final placeTypes = location.types ?? [];

      BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(
        _getMarkerHue(placeTypes),
      );

      markers.add(
        Marker(
          markerId: MarkerId(location.placeId ?? 'place_${markers.length}'),
          position: latLng,
          icon: markerIcon,
          alpha: 0.7, // Make nearby markers slightly transparent
          infoWindow: InfoWindow(
            title: location.name ?? 'Location',
            snippet: _calculateDistance(_searchCenterLocation ?? _selectedLocation, latLng)
                .toStringAsFixed(0) + 'm away',
          ),
          onTap: () => _onMarkerTapped(location),
        ),
      );
    }

    // Add selected location marker (prominent, green if valid)
    markers.add(
      Marker(
        markerId: const MarkerId('selected_location'),
        position: _selectedLocation,
        draggable: !_hasValidLocation,
        onDragEnd: (pos) {
          setState(() {
            _selectedLocation = pos;
            _hasValidLocation = false;
            _nameController.clear();
            _addressController.clear();
            _updateMapMarkers();
          });
        },
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _hasValidLocation ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: _hasValidLocation ? _nameController.text : 'Tap to select location',
        ),
      ),
    );

    // Add current location marker (blue)
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Add circle around selected location
    final circles = <Circle>{
      Circle(
        circleId: const CircleId('radius'),
        center: _selectedLocation,
        radius: _radius,
        fillColor: (_hasValidLocation ? Colors.green : Colors.blue).withOpacity(0.2),
        strokeColor: _hasValidLocation ? Colors.green : Colors.blue,
        strokeWidth: 2,
      ),
    };

    // Add search area circle if searching
    if (_searchCenterLocation != null && _showingLocations) {
      circles.add(
        Circle(
          circleId: const CircleId('search_area'),
          center: _searchCenterLocation!,
          radius: 1500,
          fillColor: Colors.orange.withOpacity(0.05),
          strokeColor: Colors.orange.withOpacity(0.3),
          strokeWidth: 1
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  double _getMarkerHue(List<String> types) {
    if (types.contains('bus_station')) return BitmapDescriptor.hueOrange;
    if (types.contains('train_station')) return BitmapDescriptor.hueGreen;
    if (types.contains('light_rail_station')) return BitmapDescriptor.hueViolet;
    if (types.contains('subway_station')) return BitmapDescriptor.hueRose;
    if (types.contains('transit_station')) return BitmapDescriptor.hueCyan;
    if (types.contains('airport')) return BitmapDescriptor.hueAzure;
    if (types.contains('university')) return BitmapDescriptor.hueYellow;
    if (types.contains('hospital')) return BitmapDescriptor.hueMagenta;
    if (types.contains('shopping_mall')) return BitmapDescriptor.hueOrange;
    if (types.contains('park')) return BitmapDescriptor.hueGreen;
    return BitmapDescriptor.hueRed;
  }

  void _onMarkerTapped(DetailsResult location) {
    _onLocationTapped(location);
  }

  void _goToCurrentLocation() async {
    LatLng? currentLoc = _currentLocation;

    // If we don't have current location cached, get it now
    if (currentLoc == null) {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;

      if (position != null) {
        currentLoc = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = currentLoc;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
        return;
      }
    }

    // Just move the camera, don't set as alarm location
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(currentLoc, 15),
    );
  }

  // ------- Zoom controls -------
  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  // ------- Fetch nearby locations with category filter -------
  Future<void> _fetchNearbyLocations(LatLng location) async {
    setState(() {
      _isLoadingLocations = true;
      _searchCenterLocation = location;
    });

    try {
      final types = _selectedCategory == LocationType.all
          ? [
        'bus_station',
        'train_station',
        'transit_station',
        'subway_station',
        'light_rail_station',
      ]
          : [_selectedCategory.googleType];

      final allResults = <DetailsResult>[];
      final seenPlaceIds = <String>{};

      for (var type in types) {
        final result = await _googlePlace.search.getNearBySearch(
          Location(lat: location.latitude, lng: location.longitude),
          1500,
          type: type,
        );

        if (result?.results != null) {
          for (var place in result!.results!.take(10)) {
            if (place.placeId != null && !seenPlaceIds.contains(place.placeId)) {
              seenPlaceIds.add(place.placeId!);
              final detailsResp = await _googlePlace.details.get(place.placeId!);
              if (detailsResp?.result != null) {
                allResults.add(detailsResp!.result!);
              }
            }
          }
        }
      }

      // Sort by distance
      allResults.sort((a, b) {
        final distA = _calculateDistance(
          location,
          LatLng(a.geometry!.location!.lat!, a.geometry!.location!.lng!),
        );
        final distB = _calculateDistance(
          location,
          LatLng(b.geometry!.location!.lat!, b.geometry!.location!.lng!),
        );
        return distA.compareTo(distB);
      });

      if (!mounted) return;

      setState(() {
        _nearbyLocations = allResults;
        _showingLocations = true;
        _showPredictions = true;
        _isLoadingLocations = false;
        _updateMapMarkers();
      });

      // Adjust camera to show all markers
      if (allResults.isNotEmpty) {
        _fitMarkersInView(location, allResults);
      }
    } catch (e) {
      print('Error fetching locations: $e');
      if (!mounted) return;
      setState(() {
        _nearbyLocations = [];
        _showingLocations = false;
        _isLoadingLocations = false;
      });
    }
  }

  void _fitMarkersInView(LatLng center, List<DetailsResult> results) {
    if (results.isEmpty || _mapController == null) return;

    double minLat = center.latitude;
    double maxLat = center.latitude;
    double minLng = center.longitude;
    double maxLng = center.longitude;

    for (var result in results.take(5)) { // Only consider closest 5 for bounds
      final loc = result.geometry?.location;
      if (loc != null) {
        minLat = min(minLat, loc.lat!);
        maxLat = max(maxLat, loc.lat!);
        minLng = min(minLng, loc.lng!);
        maxLng = max(maxLng, loc.lng!);
      }
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  // ------- Places Autocomplete -------
  void _onSearchChanged(String input) {
    _debounceTimer?.cancel();

    if (input.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _nearbyLocations = [];
        _showPredictions = false;
        _showingLocations = false;
        _searchCenterLocation = null;
        _updateMapMarkers();
      });
      return;
    }

    _debounceTimer = Timer(_debounce, () async {
      final result = await _googlePlace.autocomplete.get(
        input,
        location: _currentLocation != null
            ? LatLon(_currentLocation!.latitude, _currentLocation!.longitude)
            : null,
        radius: _currentLocation != null ? 30000 : null,
      );

      if (!mounted) return;

      final preds = result?.predictions ?? [];
      setState(() {
        _predictions = preds;
        _nearbyLocations = [];
        _showingLocations = false;
        _showPredictions = preds.isNotEmpty;
      });
    });
  }

  // Handle location selection from list or marker
  Future<void> _onLocationTapped(DetailsResult location) async {
    FocusScope.of(context).unfocus();

    final loc = location.geometry?.location;
    if (loc == null) return;

    final newLatLng = LatLng(loc.lat!, loc.lng!);
    final locationName = location.name ?? 'Location';
    final formatted = location.formattedAddress ?? location.vicinity ?? '';

    setState(() {
      _selectedLocation = newLatLng;
      _addressController.text = formatted;
      _nameController.text = locationName;
      _hasValidLocation = true;
      _showPredictions = false;
      _showingLocations = false;
      _updateMapMarkers();
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(newLatLng, 17),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Selected: $locationName')),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Handle general location selection from predictions
  Future<void> _onPredictionTapped(AutocompletePrediction p) async {
    FocusScope.of(context).unfocus();

    final placeId = p.placeId;
    if (placeId == null) return;

    setState(() {
      _showPredictions = false;
    });

    final detailsResp = await _googlePlace.details.get(placeId);
    final details = detailsResp?.result;
    final loc = details?.geometry?.location;

    if (loc == null) return;

    final newLatLng = LatLng(loc.lat!, loc.lng!);

    // Move camera first
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(newLatLng, 14),
    );

    // Don't set this as the alarm location yet, just search around it
    await _fetchNearbyLocations(newLatLng);
  }

  // ------- Category filter -------
  void _onCategoryChanged(LocationType category) {
    setState(() {
      _selectedCategory = category;
    });

    if (_searchCenterLocation != null) {
      _fetchNearbyLocations(_searchCenterLocation!);
    }
  }

  Widget _buildCategoryTabs() {
    final categories = [
      LocationType.all,
      LocationType.busStop,
      LocationType.trainStation,
      LocationType.tramStop,
      LocationType.subway,
      LocationType.airport,
      LocationType.university,
      LocationType.hospital,
      LocationType.shoppingMall,
      LocationType.park,
    ];

    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category.icon,
                    size: 16,
                    color: isSelected ? Colors.white : category.color,
                  ),
                  const SizedBox(width: 4),
                  Text(category.label),
                ],
              ),
              backgroundColor: Colors.grey[100],
              selectedColor: category.color,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) => _onCategoryChanged(category),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPredictionsOverlay() {
    if (!_showPredictions) return const SizedBox.shrink();

    return Positioned(
      top: 130,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350),
          child: _showingLocations
              ? _buildLocationsList()
              : _buildLocationPredictionsList(),
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _selectedCategory.color.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(_selectedCategory.icon, color: _selectedCategory.color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Nearby ${_selectedCategory.label}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _selectedCategory.color,
                ),
              ),
              const Spacer(),
              if (_isLoadingLocations)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_selectedCategory.color),
                  ),
                )
              else
                Text(
                  '${_nearbyLocations.length} found',
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedCategory.color,
                  ),
                ),
            ],
          ),
        ),
        if (_isLoadingLocations)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          )
        else if (_nearbyLocations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No ${_selectedCategory.label.toLowerCase()} found nearby',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _nearbyLocations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final location = _nearbyLocations[i];
                final distance = _calculateDistance(
                  _searchCenterLocation ?? _selectedLocation,
                  LatLng(
                    location.geometry!.location!.lat!,
                    location.geometry!.location!.lng!,
                  ),
                );

                final types = location.types ?? [];
                final icon = _getIconForTypes(types);
                final color = _getColorForTypes(types);

                return ListTile(
                  dense: true,
                  leading: Icon(icon, color: color),
                  title: Text(
                    location.name ?? 'Location',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${distance.toStringAsFixed(0)}m away${location.vicinity != null ? " • ${location.vicinity}" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                  onTap: () => _onLocationTapped(location),
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _getIconForTypes(List<String> types) {
    if (types.contains('bus_station')) return Icons.directions_bus;
    if (types.contains('train_station')) return Icons.train;
    if (types.contains('light_rail_station')) return Icons.tram;
    if (types.contains('subway_station')) return Icons.subway;
    if (types.contains('transit_station')) return Icons.commute;
    if (types.contains('airport')) return Icons.local_airport;
    if (types.contains('university')) return Icons.school;
    if (types.contains('hospital')) return Icons.local_hospital;
    if (types.contains('shopping_mall')) return Icons.shopping_bag;
    if (types.contains('park')) return Icons.park;
    return Icons.place;
  }

  Color _getColorForTypes(List<String> types) {
    if (types.contains('bus_station')) return Colors.orange;
    if (types.contains('train_station')) return Colors.green;
    if (types.contains('light_rail_station')) return Colors.purple;
    if (types.contains('subway_station')) return Colors.red;
    if (types.contains('transit_station')) return Colors.teal;
    if (types.contains('airport')) return Colors.indigo;
    if (types.contains('university')) return Colors.amber;
    if (types.contains('hospital')) return Colors.pink;
    if (types.contains('shopping_mall')) return Colors.deepOrange;
    if (types.contains('park')) return Colors.lightGreen;
    return Colors.blue;
  }

  Widget _buildLocationPredictionsList() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: _predictions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = _predictions[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.location_on),
          title: Text(p.structuredFormatting?.mainText ?? p.description ?? ''),
          subtitle: Text(
            p.structuredFormatting?.secondaryText ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          onTap: () => _onPredictionTapped(p),
        );
      },
    );
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    final dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final dLng = _degreesToRadians(point2.longitude - point1.longitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(point1.latitude)) *
            cos(_degreesToRadians(point2.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Widget _buildSoundButton(String sound) {
    final isSelected = _selectedSound == sound;
    return ElevatedButton(
      onPressed: () => setState(() => _selectedSound = sound),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue[100] : Colors.grey[100],
        foregroundColor: isSelected ? Colors.blue[600] : Colors.grey[600],
        elevation: 0,
      ),
      child: Text(sound),
    );
  }

  void _saveAlarm(bool startNow) {
    // Validate location
    if (!_hasValidLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid location from the search results'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate name
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
      return;
    }

    final alarm = Alarm(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      address: _addressController.text.isEmpty
          ? 'Custom Location'
          : _addressController.text.trim(),
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      radius: _radius,
      soundLevel: _selectedSound,
      isActive: startNow,
    );

    if (startNow) {
      // Navigate to Active Alarm Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveAlarmScreen(alarm: alarm),
        ),
      );
    } else {
      // Just return the alarm to be saved
      Navigator.pop(context, alarm);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Alarm "${alarm.name}" saved for later'),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Set Location', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue[600],
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
            children: [
            // Category tabs
            _buildCategoryTabs(),

        // Map section
        Expanded(
            flex: 2,
            child: GestureDetector(
                onTap: () {
                  if (_showPredictions) {
                    setState(() {
                      _showPredictions = false;
                      _showingLocations = false;
                    });
                  }
                  FocusScope.of(context).unfocus();
                },
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  children: [
                  GoogleMap(
                  key: _mapKey,
                  onMapCreated: (controller) {
                    if (_mapController == null) {
                      _mapController = controller;
                    }
                  },
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 15,
                  ),
                  markers: _markers,
                  circles: _circles,
                  onTap: (pos) {
                    // Don't allow manual tap selection, must select from list
                    FocusScope.of(context).unfocus();
                    if (_showPredictions) {
                      setState(() {
                        _showPredictions = false;
                        _showingLocations = false;
                      });
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Search box
                Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10),
                        ],
                      ),
                      child: TextField(
                        controller: _addressController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search for a location...',
                          border: InputBorder.none,
                          icon: const Icon(Icons.search),
                          suffixIcon: _hasValidLocation
                              ? Icon(Icons.check_circle,
                              color: Colors.green[600])
                              : null,
                        ),
                      ),
                    ),
                ),

                    // Suggestions dropdown
                    _buildPredictionsOverlay(),

                    // Control buttons - right side
                    Positioned(
                      top: 80,
                      right: 16,
                      child: Column(
                        children: [
                          // My Location button
                          FloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.white,
                            heroTag: 'myLocation',
                            onPressed: _goToCurrentLocation,
                            child: const Icon(Icons.my_location, color: Colors.blue),
                          ),
                          const SizedBox(height: 8),
                          // Zoom in button
                          FloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.white,
                            heroTag: 'zoomIn',
                            onPressed: _zoomIn,
                            child: const Icon(Icons.add, color: Colors.blue),
                          ),
                          const SizedBox(height: 8),
                          // Zoom out button
                          FloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.white,
                            heroTag: 'zoomOut',
                            onPressed: _zoomOut,
                            child: const Icon(Icons.remove, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),

                    // Quick action button - left side
                    if (_currentLocation != null && !_showingLocations)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _fetchNearbyLocations(_currentLocation!);
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(_currentLocation!, 14),
                            );
                          },
                          icon: const Icon(Icons.near_me),
                          label: const Text('Find Nearby'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                  ],
                ),
            ),
        ),

              // Bottom sheet
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Alarm Settings',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        // Show validation status
                        if (!_hasValidLocation)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange[700]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Search and select a location to continue',
                                    style: TextStyle(color: Colors.orange[900]),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Selected location info card
                        if (_hasValidLocation)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green[700]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Location Selected ✓',
                                        style: TextStyle(
                                          color: Colors.green[900],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _nameController.text,
                                        style: TextStyle(
                                          color: Colors.green[800],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Location Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.label),
                          ),
                          enabled: _hasValidLocation,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Trigger Radius',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_radius.toInt()}m',
                                style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _radius,
                          min: 100,
                          max: 2000,
                          divisions: 19,
                          activeColor: Colors.blue[600],
                          onChanged: (v) => setState(() {
                            _radius = v;
                            _updateMapMarkers();
                          }),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('100m',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                            Text('2km',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Text('Alarm Sound',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildSoundButton('Loud')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildSoundButton('Medium')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildSoundButton('Soft')),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _hasValidLocation
                                    ? () => _saveAlarm(false)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[100],
                                  foregroundColor: Colors.grey[700],
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  disabledBackgroundColor: Colors.grey[200],
                                ),
                                child: const Text('Save for Later'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _hasValidLocation
                                    ? () => _saveAlarm(true)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 2,
                                  disabledBackgroundColor: Colors.grey[300],
                                ),
                                child: const Text('Start Alarm'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
        ),
    );
  }
}
