import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';

import '../../models/alarm.dart';
import '../../services/location_service.dart';
import 'location_type.dart';
import 'widgets/category_tabs.dart';
import 'widgets/search_box.dart';
import 'widgets/map_controls.dart';
import 'widgets/predictions_overlay.dart';
import 'helpers/map_helpers.dart';
import 'alarm_settings_screen.dart';

class MapScreen extends StatefulWidget {
  final Alarm? existingAlarm;
  const MapScreen({super.key, this.existingAlarm});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ---- Map & UI state ----
  final GlobalKey _mapKey = GlobalKey();
  GoogleMapController? _mapController;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Will be set to user's current location once available
  LatLng? _selectedLocation;
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
  bool _isLoadingPlaceDetails = false;
  bool _pinModeActive = false;

  // ---- Category filter ----
  LocationType _selectedCategory = LocationType.all;
  LatLng? _searchCenterLocation;

  // ---- Search session & caching ----
  String? _sessionToken; // Autocomplete session token
  final Map<String, DetailsResult> _detailsCache = {}; // Lazy Details cache

  @override
  void initState() {
    super.initState();

    // Load API key from .env file
    final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('⚠️ WARNING: GOOGLE_API_KEY not found in .env file!');
    } else {
      debugPrint('✅ Google API Key loaded from .env');
    }

    _googlePlace = GooglePlace(apiKey);

    if (widget.existingAlarm != null) {
      final a = widget.existingAlarm!;
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
      final currentLoc = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = currentLoc;
        // Set selected location to current location if no existing alarm
        if (widget.existingAlarm == null && !_hasValidLocation) {
          _selectedLocation = currentLoc;
        }
        _updateMapMarkers();
      });

      if (_mapController != null &&
          widget.existingAlarm == null &&
          !_hasValidLocation &&
          _selectedLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
        );
      }
    }
  }

  void _updateMapMarkers() {
    final markers = <Marker>{};

    // Only show limited nearby markers to avoid clutter (top 10 closest)
    final displayLocations = _nearbyLocations.take(10).toList();

    for (var location in displayLocations) {
      final loc = location.geometry?.location;
      if (loc == null) continue;

      final latLng = LatLng(loc.lat!, loc.lng!);

      // Skip if this is (roughly) the selected location
      if (_hasValidLocation &&
          _selectedLocation != null &&
          latLngRoughEqual(latLng, _selectedLocation!, epsilon: 1e-4)) {
        continue;
      }

      final placeTypes = location.types ?? [];
      final hue = getMarkerHueForTypes(placeTypes);
      final markerIcon =
          BitmapDescriptor.defaultMarkerWithHue(hue);

      markers.add(
        Marker(
          markerId:
              MarkerId(location.placeId ?? 'place_${markers.length}'),
          position: latLng,
          icon: markerIcon,
          alpha: 0.75, // slightly transparent
          infoWindow: InfoWindow(
            title: location.name ?? 'Location',
            snippet:
                '${calculateDistance(_searchCenterLocation ?? _selectedLocation ?? latLng, latLng).toStringAsFixed(0)}m away',
          ),
          onTap: () => _onLocationTapped(location),
        ),
      );
    }

    // Add selected location marker (prominent, green if valid)
    if (_hasValidLocation && _selectedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: _nameController.text,
            snippet: 'Selected alarm location',
          ),
        ),
      );
    }

    // Add current location marker (blue) - only if not showing locations
    if (_currentLocation != null && !_showingLocations) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure),
          alpha: 0.8,
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Circles not shown on this selection screen (only on alarm settings)
    setState(() {
      _markers = markers;
      _circles = const <Circle>{};
    });
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

  // ------- Nearby locations (FAST → lazy Details on tap) -------
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

      final seen = <String>{};
      final all = <DetailsResult>[];

      for (final type in types) {
        final res = await _googlePlace.search.getNearBySearch(
          Location(lat: location.latitude, lng: location.longitude),
          1500,
          type: type,
        );

        for (final p in (res?.results ?? []).take(15)) {
          final pid = p.placeId;
          if (pid == null || seen.contains(pid)) continue;
          seen.add(pid);

          // Build a lightweight DetailsResult so UI can render immediately
          all.add(
            DetailsResult(
              placeId: pid,
              name: p.name,
              vicinity: p.vicinity,
              geometry: Geometry(
                location: Location(
                  lat: p.geometry?.location?.lat,
                  lng: p.geometry?.location?.lng,
                ),
              ),
              types: p.types,
              rating: p.rating,
              userRatingsTotal: p.userRatingsTotal,
              openingHours: p.openingHours,
              photos: p.photos,
            ),
          );
        }
      }

      // Sort by distance from center
      all.sort((a, b) {
        final la = LatLng(
            a.geometry!.location!.lat!, a.geometry!.location!.lng!);
        final lb = LatLng(
            b.geometry!.location!.lat!, b.geometry!.location!.lng!);
        final da = calculateDistance(location, la);
        final db = calculateDistance(location, lb);
        return da.compareTo(db);
      });

      if (!mounted) return;

      setState(() {
        _nearbyLocations = all;
        _showingLocations = true;
        _showPredictions = true;
        _isLoadingLocations = false;
        _updateMapMarkers();
      });

      // Fit the closest few + center, add padding for the bottom bar
      if (all.isNotEmpty) {
        final pts = <LatLng>[
          location,
          ...all.take(6).map((e) => LatLng(
                e.geometry!.location!.lat!,
                e.geometry!.location!.lng!,
              )),
        ];
        final bounds = pts.toBounds();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      }
    } catch (e) {
      debugPrint('Error fetching locations: $e');
      if (!mounted) return;
      setState(() {
        _nearbyLocations = [];
        _showingLocations = false;
        _isLoadingLocations = false;
      });
    }
  }


  // ------- Autocomplete (debounced + session token + location bias) -------
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

    // Start a session when user starts typing
    _sessionToken ??= UniqueKey().toString();

    _debounceTimer = Timer(_debounce, () async {
      // Use current location or map center for better biasing
      LatLng? biasLocation = _currentLocation;

      // If we have a map controller, use the visible map center
      if (_mapController != null) {
        try {
          final visibleRegion = await _mapController!.getVisibleRegion();
          biasLocation = LatLng(
            (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) / 2,
            (visibleRegion.northeast.longitude + visibleRegion.southwest.longitude) / 2,
          );
        } catch (_) {
          // Fall back to current location if map region fails
        }
      }

      final result = await _googlePlace.autocomplete.get(
        input,
        sessionToken: _sessionToken,
        location: biasLocation != null
            ? LatLon(biasLocation.latitude, biasLocation.longitude)
            : null,
        radius: biasLocation != null ? 50000 : null, // 50km radius for strong local bias
        components: [Component('country', 'au')], // Restrict to Australia
        strictbounds: false, // Allow results outside bounds but prioritize within
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

  // ------- Map tap for pin drop (reverse geocode) -------
  Future<void> _onMapTapped(LatLng position) async {
    setState(() {
      _isLoadingPlaceDetails = true;
    });

    try {
      // Try to find a nearby place for reverse geocoding
      final result = await _googlePlace.search.getNearBySearch(
        Location(lat: position.latitude, lng: position.longitude),
        50, // Very small radius to get nearest place
      );

      String locationName = 'Pinned Location';

      // Try to get a meaningful name from nearby search
      if (result?.results != null && result!.results!.isNotEmpty) {
        final nearestPlace = result.results!.first;
        if (nearestPlace.name != null) {
          locationName = nearestPlace.name!;
        }
      }

      if (!mounted) return;

      setState(() {
        _selectedLocation = position;
        _addressController.text = locationName;
        _nameController.text = locationName;
        _hasValidLocation = true;
        _showPredictions = false;
        _showingLocations = false;
        _pinModeActive = false; // Exit pin mode after dropping
        _isLoadingPlaceDetails = false;
        _updateMapMarkers();
      });

      // Animate to dropped pin location
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 17, tilt: 0),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.push_pin, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Pin dropped')),
              ],
            ),
            backgroundColor: Colors.blue[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');

      if (!mounted) return;

      // Still set the pin even if reverse geocoding fails
      setState(() {
        _selectedLocation = position;
        _addressController.text = 'Pinned Location';
        _nameController.text = 'Pinned Location';
        _hasValidLocation = true;
        _showPredictions = false;
        _showingLocations = false;
        _pinModeActive = false;
        _isLoadingPlaceDetails = false;
        _updateMapMarkers();
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 17, tilt: 0),
        ),
      );
    }
  }

  // ------- Location selection from list or marker (lazy Details) -------
  Future<void> _onLocationTapped(DetailsResult location) async {
    FocusScope.of(context).unfocus();

    final pid = location.placeId;
    DetailsResult? full = pid != null ? _detailsCache[pid] : null;

    if (pid != null && full == null) {
      try {
        final det = await _googlePlace.details.get(pid);
        full = det?.result ?? location;
        _detailsCache[pid] = full;
      } catch (_) {
        full = location;
      }
    } else {
      full ??= location;
    }

    final loc = full.geometry?.location;
    if (loc == null) return;

    final newLatLng = LatLng(loc.lat!, loc.lng!);
    final name = full.name ?? 'Location';
    final addr = full.formattedAddress ?? full.vicinity ?? name;

    setState(() {
      _selectedLocation = newLatLng;
      _addressController.text = addr; // Show nice address/name
      _nameController.text = name;
      _hasValidLocation = true;
      _showPredictions = false;
      _showingLocations = false;
      _updateMapMarkers();
    });

    // Smooth camera animation to selected location
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: newLatLng, zoom: 17, tilt: 0),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Selected: $name')),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ------- Prediction tapped: details + show Nearby; end session -------
  Future<void> _onPredictionTapped(AutocompletePrediction p) async {
    FocusScope.of(context).unfocus();

    final placeId = p.placeId;
    if (placeId == null) return;

    setState(() {
      _showPredictions = false;
      _isLoadingPlaceDetails = true;
      _addressController.text =
          p.structuredFormatting?.mainText ?? p.description ?? '';
    });

    try {
      final detailsResp =
          await _googlePlace.details.get(placeId, sessionToken: _sessionToken);
      final details = detailsResp?.result;
      final loc = details?.geometry?.location;
      _sessionToken = null; // end billing/ranking session

      if (loc == null) {
        if (!mounted) return;
        setState(() {
          _isLoadingPlaceDetails = false;
        });
        return;
      }

      final newLatLng = LatLng(loc.lat!, loc.lng!);

      // Update search text with full address if available
      if (mounted) {
        setState(() {
          _addressController.text =
              details?.formattedAddress ?? details?.name ?? p.description ?? '';
        });
      }

      // Move camera with smooth animation
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newLatLng, zoom: 15, tilt: 0),
        ),
      );

      // Fetch nearby locations
      await _fetchNearbyLocations(newLatLng);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlaceDetails = false;
        });
      }
    }
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

  void _goToAlarmSettings() {
    // Validate location
    if (!_hasValidLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid location first'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Navigate to alarm settings screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlarmSettingsScreen(
          locationName: _nameController.text.trim().isEmpty
              ? 'Selected Location'
              : _nameController.text.trim(),
          address: _addressController.text.trim(),
          selectedLocation: _selectedLocation!,
          existingAlarm: widget.existingAlarm,
        ),
      ),
    ).then((alarm) {
      // If an alarm was returned, pass it back to the caller
      if (alarm != null && mounted) {
        Navigator.pop(context, alarm);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Set Location', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[600],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Category tabs
          CategoryTabs(
            selectedCategory: _selectedCategory,
            onCategoryChanged: _onCategoryChanged,
          ),

          // Map section - prominently displayed
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_showPredictions && !_showingLocations) {
                  setState(() {
                    _showPredictions = false;
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
                      _mapController ??= controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation ?? const LatLng(-33.8688, 151.2093), // Default to Sydney
                      zoom: 15,
                    ),
                    markers: _markers,
                    circles: _circles,
                    onTap: (pos) {
                      FocusScope.of(context).unfocus();

                      if (_pinModeActive) {
                        // Pin mode: set location at tapped position
                        _onMapTapped(pos);
                      } else if (_showPredictions) {
                        // Regular mode: just hide predictions
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
                    compassEnabled: true,
                    buildingsEnabled: true,
                    tiltGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    trafficEnabled: false,
                  ),

                  // Search box and pin button
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: SearchBox(
                            controller: _addressController,
                            onChanged: _onSearchChanged,
                            hasValidLocation: _hasValidLocation,
                            isLoading:
                                _isLoadingPlaceDetails || _isLoadingLocations,
                            onClear: () {
                              _addressController.clear();
                              setState(() {
                                _showPredictions = false;
                                _showingLocations = false;
                                _nearbyLocations = [];
                                _predictions = [];
                                _searchCenterLocation = null;
                                _hasValidLocation = false;
                                _pinModeActive = false;
                                _sessionToken = null;
                                _updateMapMarkers();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Pin mode toggle button
                        Container(
                          decoration: BoxDecoration(
                            color: _pinModeActive
                                ? Colors.blue[600]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              _pinModeActive
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              size: 24,
                            ),
                            color: _pinModeActive
                                ? Colors.white
                                : Colors.grey[700],
                            tooltip: _pinModeActive
                                ? 'Cancel pin mode'
                                : 'Drop a pin',
                            onPressed: () {
                              setState(() {
                                _pinModeActive = !_pinModeActive;
                                if (_pinModeActive) {
                                  // Clear predictions when entering pin mode
                                  _showPredictions = false;
                                  _showingLocations = false;
                                  FocusScope.of(context).unfocus();
                                }
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _pinModeActive
                                        ? 'Tap on the map to drop a pin'
                                        : 'Pin mode cancelled',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Suggestions dropdown
                  PredictionsOverlay(
                    showPredictions: _showPredictions,
                    showingLocations: _showingLocations,
                    predictions: _predictions,
                    nearbyLocations: _nearbyLocations,
                    selectedCategory: _selectedCategory,
                    isLoadingLocations: _isLoadingLocations,
                    searchCenterLocation: _searchCenterLocation,
                    selectedLocation: _selectedLocation ?? const LatLng(-33.8688, 151.2093),
                    onPredictionTapped: _onPredictionTapped,
                    onLocationTapped: _onLocationTapped,
                  ),

                  // Control buttons - right side
                  Positioned(
                    top: 80,
                    right: 16,
                    child: MapControls(
                      onMyLocation: _goToCurrentLocation,
                      onZoomIn: _zoomIn,
                      onZoomOut: _zoomOut,
                    ),
                  ),

                  // Quick action button - bottom center
                  if (_currentLocation != null &&
                      !_showingLocations &&
                      !_hasValidLocation)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Get the center of the visible map area
                            if (_mapController != null) {
                              final visibleRegion = await _mapController!.getVisibleRegion();
                              final center = LatLng(
                                (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) / 2,
                                (visibleRegion.northeast.longitude + visibleRegion.southwest.longitude) / 2,
                              );
                              _fetchNearbyLocations(center);
                            } else {
                              // Fallback to current location if map controller not ready
                              _fetchNearbyLocations(_currentLocation!);
                            }
                          },
                          icon: const Icon(Icons.search, size: 20),
                          label: const Text(
                            'Search This Area',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            elevation: 6,
                            shadowColor:
                                Colors.black.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom info section - compact
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Location info or instruction
                  if (!_hasValidLocation)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Search or drop a pin to select a location',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameController.text.isEmpty
                                      ? 'Location Selected'
                                      : _nameController.text,
                                  style: TextStyle(
                                    color: Colors.green[900],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_addressController.text.isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 2),
                                    child: Text(
                                      _addressController.text,
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _hasValidLocation ? _goToAlarmSettings : null,
                      icon: const Icon(Icons.settings, size: 20),
                      label: const Text(
                        'Continue to Alarm Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
