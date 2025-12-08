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
import '../../services/settings_service.dart';
import '../../services/tier_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../paywall_screen.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;

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
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final GlobalKey _mapKey = GlobalKey();

  // Location state
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // Custom marker icon
  BitmapDescriptor? _customMarkerIcon;

  // Places API
  late final GooglePlacesService _googlePlacesService;
  final Duration _debounce = const Duration(milliseconds: 350);
  Timer? _debounceTimer;
  List<PlacePrediction> _predictions = [];
  bool _showPredictions = false;
  bool _isLoadingSuggestions = false;
  String? _sessionToken;

  // Alarm settings
  double _triggerRadius = 500.0; // Default 500m
  String _soundLevel = 'Loud';

  // UI state
  bool _pinModeActive = false;

  @override
  void initState() {
    super.initState();

    final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
    _googlePlacesService = GooglePlacesService(apiKey);

    // Create custom marker icon
    _createCustomMarker();

    // Load existing alarm if editing, otherwise use default settings
    if (widget.existingAlarm != null) {
      final alarm = widget.existingAlarm!;
      _searchController.text = alarm.address;
      _selectedLocation = LatLng(alarm.latitude, alarm.longitude);
      _triggerRadius = alarm.radius;
      _soundLevel = alarm.soundLevel;
      // Don't call _updateMapMarkers here - map controller isn't ready yet
    } else {
      // Initialize settings and load defaults for new alarms
      _loadDefaultSettings();
    }

    _requestPermissionAndLocation();
  }

  Future<void> _createCustomMarker() async {
    // Create a custom marker using asset or default with better visibility
    _customMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueAzure,
    );
    if (mounted) {
      setState(() {});
    }
  }

  /// Reverse geocode a location to get address
  Future<void> _reverseGeocodeLocation(LatLng position) async {
    try {
      final result = await _googlePlacesService.reverseGeocode(
        lat: position.latitude,
        lng: position.longitude,
      );

      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        setState(() {
          _searchController.text = result;
        });
      } else {
        // Fallback to a friendly name if reverse geocoding returns nothing
        setState(() {
          _searchController.text = 'Pinned Location';
        });
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      // Fallback to a friendly name
      if (mounted) {
        setState(() {
          _searchController.text = 'Pinned Location';
        });
      }
    }
  }

  Future<void> _loadDefaultSettings() async {
    setState(() {
      _triggerRadius = SettingsService.defaultRadius;
      _soundLevel = SettingsService.defaultSoundLevel;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  String _generateSessionToken() {
    final random = Random.secure();
    String randomHex(int length) {
      return List.generate(
        length,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
    }

    return '${randomHex(8)}-${randomHex(4)}-4${randomHex(3)}-${randomHex(4)}-${randomHex(12)}';
  }

  /// Calculate an offset position to show the pin towards the top of the visible map area
  /// This accounts for the bottom sheet covering part of the map
  LatLng _getOffsetPosition(LatLng target) {
    // Offset the latitude by approximately 0.0045 degrees (~500 meters south)
    // This moves the camera center down moderately, positioning the pin in the upper-middle area
    // The bottom sheet at 25% height requires careful balance - too much offset pushes pin off screen
    return LatLng(target.latitude - 0.0045, target.longitude);
  }

  Future<void> _requestPermissionAndLocation() async {
    // Use detailed permission request for better error handling
    final result = await LocationService.requestPermissionDetailed();

    if (!mounted) return;

    // Handle permission result with user-friendly messages
    switch (result) {
      case LocationPermissionResult.denied:
        ErrorHandler.showErrorSnackBar(
          context,
          'Location permission denied. Please grant permission to create location-based alarms.',
        );
        return;

      case LocationPermissionResult.deniedForever:
        await ErrorHandler.showErrorDialog(
          context,
          title: 'Location Permission Required',
          message:
              'Location permission has been permanently denied. '
              'Please enable it in Settings:\n\n'
              'Settings → WakeMeUp → Location → Always',
          actionLabel: 'Open Settings',
          onAction: () async {
            await LocationService.openLocationSettings();
          },
        );
        return;

      case LocationPermissionResult.serviceDisabled:
        ErrorHandler.showErrorSnackBar(
          context,
          'Location services are disabled. Please enable them in your device settings.',
        );
        return;

      case LocationPermissionResult.backgroundDenied:
        ErrorHandler.showWarningSnackBar(
          context,
          'Background location not granted. Alarms may not work when app is closed. '
          'Please enable "Always Allow" in Settings.',
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.black87,
            onPressed: () async {
              await LocationService.openLocationSettings();
            },
          ),
        );
        // Continue anyway - basic location is granted
        break;

      case LocationPermissionResult.granted:
        // All good, continue
        break;
    }

    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(
        context,
        'Unable to get current location. Please check your GPS and try again.',
      );
      return;
    }

    if (mounted) {
      final currentLoc = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = currentLoc;
        // Only set selected location to current location if this is a new alarm
        if (widget.existingAlarm == null && _selectedLocation == null) {
          _selectedLocation = currentLoc;
        }
      });

      // Update markers if map controller is ready
      if (_mapController != null) {
        _updateMapMarkers();

        // Only animate camera if we just set the location to current location
        if (widget.existingAlarm == null && _selectedLocation != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              _getOffsetPosition(_selectedLocation!),
              13.5,
            ),
          );
        }
      }
    }
  }

  void _updateMapMarkers() {
    final markers = <Marker>{};
    final circles = <Circle>{};

    if (_selectedLocation != null) {
      // Add marker for selected location with custom visible icon
      markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation!,
          icon:
              _customMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          draggable: true,
          onDragEnd: (newPosition) async {
            setState(() {
              _selectedLocation = newPosition;
              _searchController.text = 'Loading address...';
            });

            // Reverse geocode to get address
            await _reverseGeocodeLocation(newPosition);
            _updateMapMarkers();

            // Center map on dragged position
            _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));
          },
        ),
      );

      // Add circle for geofence radius
      circles.add(
        Circle(
          circleId: const CircleId('geofence'),
          center: _selectedLocation!,
          radius: _triggerRadius,
          fillColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          strokeColor: AppTheme.primaryColor,
          strokeWidth: 3,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  void _centerOnLocation(LatLng position) {
    if (_mapController == null) return;
    // Calculate zoom level to show the radius fully
    final zoomLevel = _calculateZoomForRadius(_triggerRadius);
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: zoomLevel),
      ),
    );
  }

  /// Calculate the appropriate zoom level to show the entire radius circle
  double _calculateZoomForRadius(double radiusInMeters) {
    // At zoom level 15, roughly 1 pixel = 4.77 meters at the equator
    // We want the radius to take up about 1/3 of the screen (visible with padding)
    // Screen is roughly 400 logical pixels wide, so we want radius to be ~130 pixels
    // Formula: zoom = log2(156543.03 * cos(lat) / metersPerPixel)
    // For simplicity, use a lookup approach:

    if (radiusInMeters <= 100) return 17.0;
    if (radiusInMeters <= 200) return 16.5;
    if (radiusInMeters <= 300) return 16.0;
    if (radiusInMeters <= 500) return 15.5;
    if (radiusInMeters <= 750) return 15.0;
    if (radiusInMeters <= 1000) return 14.5;
    if (radiusInMeters <= 1500) return 14.0;
    if (radiusInMeters <= 2000) return 13.5;
    return 13.0;
  }

  void _onSearchChanged(String input) {
    _debounceTimer?.cancel();

    if (input.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _showPredictions = false;
        _isLoadingSuggestions = false;
      });
      return;
    }

    _sessionToken ??= _generateSessionToken();

    // Show loading indicator
    setState(() {
      _isLoadingSuggestions = true;
      _showPredictions = true;
    });

    _debounceTimer = Timer(_debounce, () async {
      try {
        LatLng? biasLocation = _currentLocation;

        if (_mapController != null) {
          try {
            final visibleRegion = await _mapController!.getVisibleRegion();
            biasLocation = LatLng(
              (visibleRegion.northeast.latitude +
                      visibleRegion.southwest.latitude) /
                  2,
              (visibleRegion.northeast.longitude +
                      visibleRegion.southwest.longitude) /
                  2,
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
          _isLoadingSuggestions = false;
        });
      } catch (e) {
        debugPrint('Error fetching predictions: $e');
        if (mounted) {
          setState(() {
            _isLoadingSuggestions = false;
          });
        }
      }
    });
  }

  Future<void> _onPredictionTapped(PlacePrediction prediction) async {
    setState(() {
      _showPredictions = false;
      _searchController.text =
          prediction.structuredFormat?.mainText?.text ??
          prediction.text?.text ??
          '';
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
        _searchController.text =
            details.formattedAddress ??
            details.displayName?.text ??
            prediction.text?.text ??
            '';
        _updateMapMarkers();
      });

      _centerOnLocation(newLatLng);

      // Expand sheet after selecting location
      _expandSheet();
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }
  }

  Future<void> _onMapTapped(LatLng position) async {
    // If pin mode is active, set the location
    if (_pinModeActive) {
      setState(() {
        _selectedLocation = position;
        _searchController.text = 'Loading address...';
        _showPredictions = false;
        _pinModeActive = false; // Exit pin mode after dropping pin
        _updateMapMarkers();
      });

      // Reverse geocode to get actual address
      await _reverseGeocodeLocation(position);

      _centerOnLocation(position);

      // Expand sheet after selecting location
      _expandSheet();
    } else {
      // Collapse sheet when tapping map (not in pin mode)
      _collapseSheet();
    }
  }

  void _expandSheet() {
    _sheetController.animateTo(
      0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _collapseSheet() {
    _sheetController.animateTo(
      0.12,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
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
        // Unable to get location - fail silently
        return;
      }
    }

    // Center directly on current location without offset
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentLoc, 15.0));
  }

  Future<void> _saveAlarm(bool activate) async {
    if (_selectedLocation == null) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Please select a location on the map first',
      );
      return;
    }

    // Validate trip distance against tier limits (only for new alarms or when activating)
    if (_currentLocation != null && activate) {
      final distanceInMeters = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      final distanceKm = distanceInMeters / 1000;

      final tierError = await TierService.canCreateAlarmAtDistance(distanceKm);
      if (tierError != null) {
        if (!mounted) return;
        // Show upgrade dialog
        final shouldUpgrade = await _showUpgradeDialog(tierError);
        if (shouldUpgrade == true) {
          // Navigate to paywall screen
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PaywallScreen(
                highlightedMessage: tierError,
              ),
            ),
          );
        }
        return;
      }
    }

    final isEditing = widget.existingAlarm != null;
    final wasActive = widget.existingAlarm?.isActive ?? false;

    final alarm = Alarm(
      id:
          widget.existingAlarm?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _searchController.text.isNotEmpty
          ? _searchController.text
          : 'My Alarm',
      address: _searchController.text.isNotEmpty
          ? _searchController.text
          : 'Selected Location',
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      radius: _triggerRadius,
      soundLevel: _soundLevel,
      isActive: activate,
    );

    try {
      // If editing an existing alarm that was active, stop the old geofence first
      if (isEditing && wasActive) {
        await GeofenceAlarmService().stopGeofencing(alarm.id);
      }

      // Save/update alarm
      if (isEditing) {
        await AlarmStorageService.updateAlarm(alarm);
      } else {
        await AlarmStorageService.saveAlarm(alarm);
      }

      // Start geofencing if activated
      if (activate) {
        final success = await GeofenceAlarmService().startGeofencing(alarm);
        if (!success) {
          if (!mounted) return;
          ErrorHandler.showErrorDialog(
            context,
            title: 'Geofencing Error',
            message:
                'Failed to activate alarm. Please check that:\n\n'
                '• Location services are enabled\n'
                '• Background location permission is granted\n'
                '• You have granted "Always Allow" location access\n\n'
                'The alarm has been saved but is not active.',
          );
          return;
        }
      }

      if (!mounted) return;

      // Removed success notification - user can see alarm state in UI

      // Return to previous screen
      Navigator.of(context).pop(alarm);
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving alarm: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      await ErrorHandler.handleStorageError(
        context,
        isEditing ? 'update alarm' : 'save alarm',
        e,
      );
    }
  }

  /// Show upgrade dialog when tier limit is exceeded
  Future<bool?> _showUpgradeDialog(String message) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: AppTheme.warningColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Upgrade Required',
                style: AppTheme.headingMedium,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.existingAlarm != null
                    ? AppTheme.accentGreen.withValues(alpha: 0.15)
                    : AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.existingAlarm != null
                    ? Icons.edit_location_alt_rounded
                    : Icons.add_location_alt_rounded,
                color: widget.existingAlarm != null
                    ? AppTheme.accentGreen
                    : AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.existingAlarm != null ? 'Edit Alarm' : 'New Alarm',
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceColor,
        iconTheme: const IconThemeData(color: AppTheme.textPrimaryColor),
        elevation: 0,
        actions: [
          // Pin mode toggle - more visible button
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _pinModeActive
                    ? AppTheme.accentGreen
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _pinModeActive
                      ? AppTheme.accentGreen
                      : AppTheme.primaryColor,
                  width: 2,
                ),
                boxShadow: _pinModeActive
                    ? [
                        BoxShadow(
                          color: AppTheme.accentGreen.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _pinModeActive = !_pinModeActive;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _pinModeActive
                              ? Icons.touch_app
                              : Icons.add_location_alt,
                          color: _pinModeActive
                              ? Colors.white
                              : AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _pinModeActive ? 'Tap Map' : 'Drop Pin',
                          style: TextStyle(
                            color: _pinModeActive
                                ? Colors.white
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            key: _mapKey,
            onMapCreated: (controller) {
              _mapController = controller;
              // Update markers when map is ready
              _updateMapMarkers();
              // Animate to selected location after a brief delay to ensure map is fully initialized
              if (_selectedLocation != null) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      _getOffsetPosition(_selectedLocation!),
                      13.5,
                    ),
                  );
                });
              }
            },
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ?? const LatLng(-33.8688, 151.2093),
              zoom: 13.5,
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
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Search location or enter address...',
                          hintStyle: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textDisabledColor,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppTheme.primaryColor,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _predictions = [];
                                      _showPredictions = false;
                                      _selectedLocation =
                                          null; // Deselect location
                                      _updateMapMarkers(); // Update map to remove marker
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.paddingMedium,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    // Predictions dropdown
                    if (_showPredictions)
                      Container(
                        margin: const EdgeInsets.only(
                          top: AppTheme.paddingSmall,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: _isLoadingSuggestions
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    AppTheme.paddingLarge,
                                  ),
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              )
                            : _predictions.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(AppTheme.paddingLarge),
                                child: Center(
                                  child: Text(
                                    'No locations found',
                                    style: AppTheme.bodyMedium,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppTheme.paddingSmall,
                                ),
                                shrinkWrap: true,
                                itemCount: _predictions.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                      height: 1,
                                      color: AppTheme.borderLightColor,
                                    ),
                                itemBuilder: (context, index) {
                                  final prediction = _predictions[index];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.location_on,
                                      color: AppTheme.primaryColor,
                                    ),
                                    title: Text(
                                      prediction
                                              .structuredFormat
                                              ?.mainText
                                              ?.text ??
                                          prediction.text?.text ??
                                          '',
                                      style: AppTheme.labelLarge,
                                    ),
                                    subtitle:
                                        prediction
                                                .structuredFormat
                                                ?.secondaryText
                                                ?.text !=
                                            null
                                        ? Text(
                                            prediction
                                                .structuredFormat!
                                                .secondaryText!
                                                .text,
                                            style: AppTheme.bodySmall,
                                          )
                                        : null,
                                    onTap: () =>
                                        _onPredictionTapped(prediction),
                                  );
                                },
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Map control buttons (My Location, Zoom In, Zoom Out)
          Positioned(
            top: 80,
            right: 16,
            child: Column(
              children: [
                // My Location button
                FloatingActionButton(
                  mini: true,
                  heroTag: 'myLocation',
                  backgroundColor: AppTheme.surfaceColor,
                  onPressed: _goToCurrentLocation,
                  child: const Icon(
                    Icons.my_location,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Zoom In button
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoomIn',
                  backgroundColor: AppTheme.surfaceColor,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                  child: const Icon(Icons.add, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 8),
                // Zoom Out button
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoomOut',
                  backgroundColor: AppTheme.surfaceColor,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                  child: const Icon(Icons.remove, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),

          // Bottom sheet with alarm settings
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.25,
            minChildSize: 0.1,
            maxChildSize: 0.75,
            snap: true,
            snapSizes: const [0.1, 0.25, 0.5, 0.75],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusXLarge),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(
                        top: AppTheme.paddingMedium,
                        bottom: AppTheme.paddingMedium,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              'Alarm Settings',
                              style: AppTheme.headingLarge,
                            ),
                            const SizedBox(height: AppTheme.paddingLarge),

                            // Trigger Radius
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Trigger Radius',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.paddingMedium,
                                    vertical: AppTheme.paddingSmall,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSmall,
                                    ),
                                  ),
                                  child: Text(
                                    '${_triggerRadius.toInt()}m',
                                    style: AppTheme.labelLarge.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _triggerRadius,
                              min: 100,
                              max: 5000,
                              divisions: 49,
                              activeColor: AppTheme.primaryColor,
                              inactiveColor: AppTheme.borderLightColor,
                              onChanged: (value) {
                                setState(() {
                                  _triggerRadius = value;
                                  _updateMapMarkers();
                                });
                              },
                              onChangeEnd: (value) {
                                // After radius change, zoom to show the full circle
                                if (_selectedLocation != null) {
                                  _centerOnLocation(_selectedLocation!);
                                }
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('100m', style: AppTheme.caption),
                                Text('5km', style: AppTheme.caption),
                              ],
                            ),
                            const SizedBox(height: AppTheme.paddingLarge),

                            // Alarm Sound
                            Text(
                              'Alarm Sound',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildSoundButton('Loud')),
                                const SizedBox(width: 12),
                                Expanded(child: _buildSoundButton('Medium')),
                                const SizedBox(width: 12),
                                Expanded(child: _buildSoundButton('Soft')),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Action buttons
                            Column(
                              children: [
                                // Primary action button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _selectedLocation != null
                                        ? () => _saveAlarm(true)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      backgroundColor: AppTheme.accentGreen,
                                      foregroundColor:
                                          AppTheme.textOnPrimaryColor,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          widget.existingAlarm != null
                                              ? Icons.check_circle_rounded
                                              : Icons.alarm_on_rounded,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.existingAlarm != null
                                              ? 'Update & Activate'
                                              : 'Activate Alarm',
                                          style: AppTheme.buttonMedium.copyWith(
                                            color: AppTheme.textOnPrimaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Secondary action button
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => _saveAlarm(false),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      side: BorderSide(
                                        color: AppTheme.borderColor.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.bookmark_border_rounded,
                                          size: 20,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.existingAlarm != null
                                              ? 'Save Changes'
                                              : 'Save for Later',
                                          style: AppTheme.buttonMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                            fontWeight: FontWeight.w600,
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
                      ),
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
        padding: const EdgeInsets.symmetric(vertical: AppTheme.paddingMedium),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.borderLightColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          level,
          textAlign: TextAlign.center,
          style: AppTheme.labelMedium.copyWith(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.textSecondaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
