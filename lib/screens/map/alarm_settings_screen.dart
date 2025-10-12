import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/alarm.dart';
import '../active_alarm_screen.dart';

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

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  double _radius = 500;
  String _selectedSound = 'Loud';
  late final TextEditingController _nameController;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.locationName);

    if (widget.existingAlarm != null) {
      _radius = widget.existingAlarm!.radius;
      _selectedSound = widget.existingAlarm!.soundLevel;
      _nameController.text = widget.existingAlarm!.name;
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    super.dispose();
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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
      return;
    }

    final alarm = Alarm(
      id: widget.existingAlarm?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      address: widget.address.isEmpty ? 'Custom Location' : widget.address,
      latitude: widget.selectedLocation.latitude,
      longitude: widget.selectedLocation.longitude,
      radius: _radius,
      soundLevel: _selectedSound,
      isActive: startNow,
    );

    if (startNow) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveAlarmScreen(alarm: alarm),
        ),
      );
    } else {
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
        title: const Text('Alarm Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[600],
        iconTheme: const IconThemeData(color: Colors.white),
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
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
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
                            '${_radius.toInt()}m',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
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
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '100m',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '2km',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Alarm Sound',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
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
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _saveAlarm(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              foregroundColor: Colors.grey[700],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            child: const Text('Save for Later'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _saveAlarm(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
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
