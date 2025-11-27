import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';
import '../services/geofence_service.dart';
import '../services/alarm_storage_service.dart';
import '../services/alarm_sound_service.dart';
import '../services/tier_service.dart';
import '../models/tier.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onSettingsApplied;

  const SettingsScreen({Key? key, this.onSettingsApplied}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _defaultRadius = 500.0;
  String _defaultSoundLevel = 'Loud';
  AlarmRingtone _defaultRingtone = AlarmRingtone.alarm;
  bool _vibration = true;
  bool _highAccuracy = true;
  int _updateInterval = 10;

  Tier _currentTier = Tier.free;
  TierLimits? _tierLimits;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final tier = await TierService.getCurrentTier();
    final limits = await TierService.getTierLimits();

    setState(() {
      _defaultRadius = SettingsService.defaultRadius;
      _defaultSoundLevel = SettingsService.defaultSoundLevel;
      _defaultRingtone = AlarmRingtone.fromString(SettingsService.defaultRingtone);
      _vibration = SettingsService.vibrationEnabled;
      _highAccuracy = SettingsService.highAccuracy;
      _updateInterval = SettingsService.updateInterval;
      _currentTier = tier;
      _tierLimits = limits;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: AppTheme.textOnPrimaryColor)),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Subscription Section
            _buildSubscriptionSection(),
            const SizedBox(height: 24),

            _buildSectionTitle('GENERAL'),
            _buildSettingsCard([
              _buildSettingRow(
                'Default Radius',
                trailing: Text(
                  '${_defaultRadius.toInt()}m',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor),
                ),
                onTap: () => _showRadiusPicker(),
              ),
              const Divider(height: 1),
              _buildSettingRow(
                'Default Volume',
                trailing: Text(
                  _defaultSoundLevel,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor),
                ),
                onTap: () => _showSoundLevelPicker(),
              ),
              const Divider(height: 1),
              _buildSettingRow(
                'Default Ringtone',
                trailing: Text(
                  _defaultRingtone.displayName,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor),
                ),
                onTap: () => _showRingtonePicker(),
              ),
              const Divider(height: 1),
              _buildSettingRow(
                'Vibration',
                trailing: Switch(
                  value: _vibration,
                  activeTrackColor: AppTheme.primaryColor,
                  onChanged: (v) async {
                    setState(() => _vibration = v);
                    await SettingsService.setVibrationEnabled(v);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 16),
            // Apply to All Alarms button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _applySettingsToAllAlarms,
                icon: const Icon(Icons.sync, size: 20),
                label: const Text('Apply Settings to All Alarms'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('GPS SETTINGS'),
            _buildSettingsCard([
              _buildSettingRow(
                'High Accuracy Mode',
                subtitle: 'Uses more battery for better location tracking',
                trailing: Switch(
                  value: _highAccuracy,
                  activeTrackColor: AppTheme.primaryColor,
                  onChanged: (v) async {
                    setState(() => _highAccuracy = v);
                    await SettingsService.setHighAccuracy(v);
                    // Reload geofence settings with new accuracy
                    await _reloadGeofenceSettings();
                  },
                ),
              ),
              const Divider(height: 1),
              _buildSettingRow(
                'Update Interval',
                trailing: Text(
                  '$_updateInterval sec',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor),
                ),
                onTap: () => _showUpdateIntervalPicker(),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle('ABOUT'),
            _buildSettingsCard([
              _buildSettingRow('Version',
                  trailing:
                  Text('1.0.0', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor))),
              const Divider(height: 1),
              _buildSettingRow('Privacy Policy'),
              const Divider(height: 1),
              _buildSettingRow('Terms of Service'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    if (_tierLimits == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _currentTier.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentTier.displayName} Plan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentTier.price,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_currentTier != Tier.pro)
                OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaywallScreen(),
                      ),
                    );
                    _loadSettings(); // Reload in case user upgraded
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Upgrade'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 12),
          _buildLimitRow(
            Icons.route,
            'Trip Distance',
            _tierLimits!.formattedTripDistance,
          ),
          const SizedBox(height: 8),
          _buildLimitRow(
            Icons.alarm,
            'Active Alarms',
            _tierLimits!.formattedAlarmLimit,
          ),
          const SizedBox(height: 8),
          _buildLimitRow(
            Icons.update,
            'GPS Updates',
            '${_tierLimits!.gpsUpdateIntervalSeconds}s',
          ),
        ],
      ),
    );
  }

  Widget _buildLimitRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.paddingSmall, left: 4),
      child: Text(
        title,
        style: AppTheme.labelSmall.copyWith(
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingRow(String title, {String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Future<void> _showRadiusPicker() async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) => _RadiusPickerDialog(initialValue: _defaultRadius),
    );

    if (result != null) {
      setState(() => _defaultRadius = result);
      await SettingsService.setDefaultRadius(result);
    }
  }

  Future<void> _showSoundLevelPicker() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _SoundLevelPickerDialog(initialValue: _defaultSoundLevel),
    );

    if (result != null) {
      setState(() => _defaultSoundLevel = result);
      await SettingsService.setDefaultSoundLevel(result);
    }
  }

  Future<void> _showUpdateIntervalPicker() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _UpdateIntervalPickerDialog(initialValue: _updateInterval),
    );

    if (result != null) {
      setState(() => _updateInterval = result);
      await SettingsService.setUpdateInterval(result);
      // Reload geofence settings with new interval
      await _reloadGeofenceSettings();
    }
  }

  Future<void> _showRingtonePicker() async {
    final result = await showDialog<AlarmRingtone>(
      context: context,
      builder: (context) => _RingtonePickerDialog(initialValue: _defaultRingtone),
    );

    if (result != null) {
      setState(() => _defaultRingtone = result);
      await SettingsService.setDefaultRingtone(result.name);
    }
  }

  /// Reload geofence settings after GPS settings change
  Future<void> _reloadGeofenceSettings() async {
    try {
      final geofenceService = GeofenceAlarmService();
      await geofenceService.reloadSettings();
      debugPrint('✅ Geofence settings reloaded');
    } catch (e) {
      debugPrint('⚠️ Error reloading geofence settings: $e');
    }
  }

  /// Apply current settings to all existing alarms
  Future<void> _applySettingsToAllAlarms() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply to All Alarms?'),
        content: Text(
          'This will update all existing alarms with:\n\n'
          '• Radius: ${_defaultRadius.toInt()}m\n'
          '• Volume: $_defaultSoundLevel\n'
          '• Ringtone: ${_defaultRingtone.displayName}\n\n'
          'Active alarms will be restarted with new settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Get all alarms
      final alarms = AlarmStorageService.getAllAlarms();
      if (alarms.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No alarms to update')),
          );
        }
        return;
      }

      final geofenceService = GeofenceAlarmService();
      int updatedCount = 0;

      for (final alarm in alarms) {
        // Create updated alarm with new settings using copyWith
        final updatedAlarm = alarm.copyWith(
          radius: _defaultRadius,
          soundLevel: _defaultSoundLevel,
          ringtone: _defaultRingtone.name,
        );

        // Save updated alarm
        await AlarmStorageService.updateAlarm(updatedAlarm);

        // If alarm is active, restart geofencing with new settings
        if (updatedAlarm.isActive) {
          await geofenceService.stopGeofencing(updatedAlarm.id);
          await geofenceService.startGeofencing(updatedAlarm);
        }

        updatedCount++;
      }

      debugPrint('✅ Updated $updatedCount alarms with new settings');

      // Notify parent to refresh the home screen
      widget.onSettingsApplied?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $updatedCount alarm${updatedCount != 1 ? 's' : ''} with new settings'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error applying settings to alarms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating alarms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Radius Picker Dialog
class _RadiusPickerDialog extends StatefulWidget {
  final double initialValue;

  const _RadiusPickerDialog({required this.initialValue});

  @override
  State<_RadiusPickerDialog> createState() => _RadiusPickerDialogState();
}

class _RadiusPickerDialogState extends State<_RadiusPickerDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Default Radius'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_value.toInt()}m',
            style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryColor),
          ),
          Slider(
            value: _value,
            min: 100,
            max: 2000,
            divisions: 19,
            onChanged: (v) => setState(() => _value = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('100m', style: AppTheme.caption),
              Text('2km', style: AppTheme.caption),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _value),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Sound Level Picker Dialog
class _SoundLevelPickerDialog extends StatelessWidget {
  final String initialValue;

  const _SoundLevelPickerDialog({required this.initialValue});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Default Alarm Sound'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(context, 'Loud'),
          _buildOption(context, 'Medium'),
          _buildOption(context, 'Soft'),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String level) {
    final isSelected = level == initialValue;
    return ListTile(
      title: Text(level),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
      onTap: () => Navigator.pop(context, level),
    );
  }
}

// Update Interval Picker Dialog
class _UpdateIntervalPickerDialog extends StatelessWidget {
  final int initialValue;

  const _UpdateIntervalPickerDialog({required this.initialValue});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Interval'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(context, 5, '5 seconds'),
          _buildOption(context, 10, '10 seconds (Recommended)'),
          _buildOption(context, 15, '15 seconds'),
          _buildOption(context, 30, '30 seconds'),
          _buildOption(context, 60, '1 minute'),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, int seconds, String label) {
    final isSelected = seconds == initialValue;
    return ListTile(
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
      onTap: () => Navigator.pop(context, seconds),
    );
  }
}

// Ringtone Picker Dialog with Preview
class _RingtonePickerDialog extends StatefulWidget {
  final AlarmRingtone initialValue;

  const _RingtonePickerDialog({required this.initialValue});

  @override
  State<_RingtonePickerDialog> createState() => _RingtonePickerDialogState();
}

class _RingtonePickerDialogState extends State<_RingtonePickerDialog> {
  AudioPlayer? _audioPlayer;
  AlarmRingtone? _playingRingtone;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _disposeAudioPlayer();
    super.dispose();
  }

  void _disposeAudioPlayer() {
    final player = _audioPlayer;
    _audioPlayer = null;
    _playingRingtone = null;
    if (player != null) {
      player.stop().then((_) => player.dispose()).catchError((_) {});
    }
  }

  Future<void> _playPreview(AlarmRingtone ringtone) async {
    // Stop any currently playing preview
    await _stopPreview();

    if (_isDisposed) return;
    setState(() => _playingRingtone = ringtone);

    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setVolume(0.7);
      await _audioPlayer!.play(AssetSource(ringtone.assetPath));

      // Auto-stop after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isDisposed && _playingRingtone == ringtone) {
          _stopPreview();
        }
      });
    } catch (e) {
      debugPrint('Error playing preview: $e');
      if (!_isDisposed && mounted) {
        setState(() => _playingRingtone = null);
      }
    }
  }

  Future<void> _stopPreview() async {
    final player = _audioPlayer;
    _audioPlayer = null;

    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    if (!_isDisposed && mounted) {
      setState(() => _playingRingtone = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Default Ringtone'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AlarmRingtone.values.map((ringtone) {
            final isSelected = ringtone == widget.initialValue;
            final isPlaying = _playingRingtone == ringtone;
            return ListTile(
              leading: IconButton(
                icon: Icon(
                  isPlaying ? Icons.stop_circle : Icons.play_circle,
                  color: isPlaying ? Colors.red : AppTheme.primaryColor,
                  size: 28,
                ),
                onPressed: () {
                  if (isPlaying) {
                    _stopPreview();
                  } else {
                    _playPreview(ringtone);
                  }
                },
              ),
              title: Text(ringtone.displayName),
              trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
              onTap: () {
                _stopPreview();
                Navigator.pop(context, ringtone);
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _stopPreview();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
