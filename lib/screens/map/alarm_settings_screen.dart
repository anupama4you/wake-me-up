import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/alarm.dart';
import '../../models/tier.dart';
import '../../services/alarm_storage_service.dart';
import '../../services/geofence_service.dart';
import '../../services/alarm_sound_service.dart';
import '../../services/tier_service.dart';
import '../../services/settings_service.dart';
import '../../utils/trip_distance_calculator.dart';
import '../alarm_detail_map_screen.dart';
import '../paywall_screen.dart';

class AlarmSettingsScreen extends StatefulWidget {
  final String locationName;
  final String address;
  final LatLng selectedLocation;
  final Alarm? existingAlarm;

  const AlarmSettingsScreen({
    super.key,
    required this.locationName,
    required this.address,
    required this.selectedLocation,
    this.existingAlarm,
  });

  @override
  State<AlarmSettingsScreen> createState() => _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen>
    with SingleTickerProviderStateMixin {
  static const List<int> _radiusOptionsKm = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  static const List<String> _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  double _radius = 1000;
  AlarmRingtone _selectedRingtone = AlarmRingtone.alarm;
  List<int> _repeatDays = [];
  late final TextEditingController _nameController;
  late final String _originalName;
  late final double _originalRadius;
  late final AlarmRingtone _originalRingtone;
  late final List<int> _originalRepeatDays;
  GoogleMapController? _mapController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.locationName);

    if (widget.existingAlarm != null) {
      // Clamp existing alarm radius to valid range (1km - 10km)
      _radius = _normalizeRadius(widget.existingAlarm!.radius);
      _selectedRingtone = AlarmRingtone.fromString(
        widget.existingAlarm!.ringtone,
      );
      _nameController.text = widget.existingAlarm!.name;
      _repeatDays = List<int>.from(widget.existingAlarm!.repeatDays);
    } else {
      // Load default radius from settings for new alarms, clamped to valid range
      _radius = _normalizeRadius(SettingsService.defaultRadius);
      _selectedRingtone = AlarmRingtone.fromString(
        SettingsService.defaultRingtone,
      );
      _repeatDays = [];
    }

    _originalName = _nameController.text.trim();
    _originalRadius = _radius;
    _originalRingtone = _selectedRingtone;
    _originalRepeatDays = List<int>.from(_repeatDays);

    // Initialize animation controller for pulsing effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  double _normalizeRadius(double radiusInMeters) {
    // Snap to nearest 1km increment within 1km-10km bounds
    final km = (radiusInMeters / 1000).round().clamp(1, 10);
    return km * 1000.0;
  }

  int get _selectedRadiusKm => (_radius / 1000).round().clamp(1, 10);

  String _buildRepeatLabel() {
    if (_repeatDays.isEmpty) return '';
    final sorted = List<int>.from(_repeatDays)..sort();
    if (sorted.length == 5 && !sorted.contains(5) && !sorted.contains(6)) {
      return 'Weekdays';
    }
    if (sorted.length == 2 && sorted.contains(5) && sorted.contains(6)) {
      return 'Weekends';
    }
    if (sorted.length == 7) return 'Every day';
    return sorted.map((d) => _dayAbbr[d]).join(', ');
  }

  bool get _hasUnsavedChanges {
    final repeatChanged = _repeatDays.length != _originalRepeatDays.length ||
        _repeatDays.any((d) => !_originalRepeatDays.contains(d));
    return _nameController.text.trim() != _originalName ||
        _radius != _originalRadius ||
        _selectedRingtone != _originalRingtone ||
        repeatChanged;
  }

  Future<bool> _confirmNavigationAway() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Save changes?'),
            content: const Text(
              'You have unsaved changes to this alarm. Save before leaving?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'discard'),
                child: const Text('Discard'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, 'save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (!mounted) return false;

    if (result == 'discard') return true;
    if (result == 'save') {
      await _saveAlarm(false);
      return false; // saveAlarm handles navigation
    }
    return false; // cancel
  }

  Future<void> _saveAlarm(bool startNow) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
      return;
    }

    // Check trip distance against tier limits (MANDATORY - blocks creation if validation fails)
    try {
      final currentPosition = await Geolocator.getCurrentPosition();
      final distanceKm = TripDistanceCalculator.calculateDistanceFromPosition(
        currentPosition: currentPosition,
        targetLat: widget.selectedLocation.latitude,
        targetLon: widget.selectedLocation.longitude,
      );

      debugPrint(
        '🔍 Trip distance validation: ${distanceKm.toStringAsFixed(1)}km',
      );

      // Validate distance against tier limits
      final tierError = await TierService.canCreateAlarmAtDistance(distanceKm);
      if (tierError != null) {
        // debugPrint('⚠️ Trip distance exceeds tier limit: $tierError');
        // Show upgrade dialog
        if (!mounted) return;
        await _showDistanceLimitDialog(tierError, distanceKm);
        return;
      }

      // debugPrint('✅ Trip distance within tier limits');
    } catch (e) {
      debugPrint('❌ Failed to validate trip distance: $e');
      if (!mounted) return;

      // BLOCK alarm creation if location validation fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot validate trip distance: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final alarm = Alarm(
      id:
          widget.existingAlarm?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      address: widget.address.isEmpty ? 'Custom Location' : widget.address,
      latitude: widget.selectedLocation.latitude,
      longitude: widget.selectedLocation.longitude,
      radius: _radius,
      soundLevel: 'Loud', // Default value - actual volume controlled by phone
      ringtone: _selectedRingtone.name,
      isActive: startNow,
      repeatDays: List<int>.from(_repeatDays),
    );

    // Save alarm to local storage
    try {
      debugPrint('💾 Saving alarm to storage: ${alarm.name} (ID: ${alarm.id})');
      await AlarmStorageService.saveAlarm(alarm);
      debugPrint('✅ Alarm saved successfully to Hive');

      // Verify save by reading back
      final savedAlarm = AlarmStorageService.getAlarm(alarm.id);
      if (savedAlarm != null) {
        debugPrint(
          '✅ Verified: Alarm found in storage with isActive=${savedAlarm.isActive}',
        );
      } else {
        debugPrint('⚠️ Warning: Alarm saved but cannot be retrieved');
      }
    } catch (e) {
      debugPrint('❌ Failed to save alarm: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving alarm: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If starting now, set up geofencing
    if (startNow) {
      try {
        final geofenceService = GeofenceAlarmService();
        await geofenceService.initialize();
        final success = await geofenceService.startGeofencing(alarm);

        if (!success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start background geofencing'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('⚠️ Geofencing setup error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geofencing error: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (!mounted) return;

    if (startNow) {
      // Navigate to active alarm detail screen and wait for result
      final result = await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AlarmDetailMapScreen(alarm: alarm),
        ),
      );

      // If alarm was stopped (result == true), return to previous screen
      // This will cause main screen to reload
      if (result == true && mounted) {
        Navigator.pop(context, alarm);
      }
    } else {
      Navigator.pop(context, alarm);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Alarm "${alarm.name}" saved')),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Show distance limit exceeded dialog with upgrade option
  Future<void> _showDistanceLimitDialog(
    String message,
    double distanceKm,
  ) async {
    final currentTier = await TierService.getCurrentTier();
    final requiredTier = TripDistanceCalculator.getRequiredTier(distanceKm);

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.lock,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Trip Distance Limit')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place, size: 18, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Trip Distance: ${TripDistanceCalculator.formatDistance(distanceKm)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Plan: ${currentTier.displayName}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Required: ${requiredTier.displayName} or higher',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => PaywallScreen(
                            highlightedMessage: message,
                            suggestedTier: requiredTier,
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Upgrade'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmNavigationAway,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Alarm Settings',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.blue[600],
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canLeave = await _confirmNavigationAway();
              if (canLeave && mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Small preview map
            SizedBox(
              height: 200,
              child: GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                initialCameraPosition: CameraPosition(
                  target: widget.selectedLocation,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('selected_location'),
                    position: widget.selectedLocation,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
                },
                circles: {
                  Circle(
                    circleId: const CircleId('radius'),
                    center: widget.selectedLocation,
                    radius: _radius,
                    fillColor: Colors.green.withValues(alpha: 0.1),
                    strokeColor: Colors.green.withValues(alpha: 0.5),
                    strokeWidth: 2,
                  ),
                },
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
              ),
            ),

            // Settings section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: Colors.white),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location info card
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.green[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Location',
                                    style: TextStyle(
                                      color: Colors.green[900],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.address.isEmpty
                                        ? widget.locationName
                                        : widget.address,
                                    style: TextStyle(
                                      color: Colors.green[800],
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Text(
                        'Alarm Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Location Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Trigger Radius',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_selectedRadiusKm}km',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _radiusOptionsKm.map((km) {
                              final isSelected = _selectedRadiusKm == km;
                              return ChoiceChip(
                                label: Text('${km}km'),
                                selected: isSelected,
                                onSelected:
                                    (_) => setState(() {
                                      _radius = (km * 1000).toDouble();
                                    }),
                                selectedColor: Colors.blue[600],
                                labelStyle: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: Colors.grey[100],
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Ringtone selection
                      const Text(
                        'Alarm Sound',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AlarmRingtone>(
                            value: _selectedRingtone,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            borderRadius: BorderRadius.circular(8),
                            items:
                                AlarmRingtone.values.map((ringtone) {
                                  return DropdownMenuItem<AlarmRingtone>(
                                    value: ringtone,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.music_note,
                                          color: Colors.blue[600],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(ringtone.displayName),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            onChanged: (AlarmRingtone? value) {
                              if (value != null) {
                                setState(() => _selectedRingtone = value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Repeat days section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Repeat',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (_repeatDays.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() => _repeatDays.clear()),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (i) {
                          final selected = _repeatDays.contains(i);
                          return GestureDetector(
                            onTap: () => setState(() {
                              selected
                                  ? _repeatDays.remove(i)
                                  : _repeatDays.add(i);
                            }),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? Colors.blue[600]
                                    : Colors.grey[100],
                                border: Border.all(
                                  color: selected
                                      ? Colors.blue[600]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _dayAbbr[i].substring(0, 1),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_repeatDays.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Repeats: ${_buildRepeatLabel()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _saveAlarm(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[100],
                                foregroundColor: Colors.grey[700],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                elevation: 0,
                              ),
                              child: const Text('Save for Later'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1a237e),
                                      Color(0xFF283593),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1a237e,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () => _saveAlarm(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.play_circle_filled,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Start Alarm',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
      ),
    );
  }
}
