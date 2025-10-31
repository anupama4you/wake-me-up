import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';
import '../services/geofence_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _defaultRadius = 500.0;
  String _defaultSoundLevel = 'Loud';
  bool _vibration = true;
  bool _highAccuracy = true;
  int _updateInterval = 10;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _defaultRadius = SettingsService.defaultRadius;
      _defaultSoundLevel = SettingsService.defaultSoundLevel;
      _vibration = SettingsService.vibrationEnabled;
      _highAccuracy = SettingsService.highAccuracy;
      _updateInterval = SettingsService.updateInterval;
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
                'Default Alarm Sound',
                trailing: Text(
                  _defaultSoundLevel,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor),
                ),
                onTap: () => _showSoundLevelPicker(),
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
            _buildSectionTitle('DIAGNOSTICS'),
            _buildSettingsCard([
              _buildSettingRow(
                'Test Notification',
                subtitle: 'Send a test notification to verify notifications work',
                trailing: const Icon(Icons.notifications_active, color: AppTheme.primaryColor),
                onTap: () => _testNotification(),
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

  /// Test notification to verify notifications are working
  Future<void> _testNotification() async {
    debugPrint('🔔 Testing notification...');

    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Check permissions first
    if (Platform.isIOS) {
      final iosPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      final permissions = await iosPlugin?.checkPermissions();
      debugPrint('📱 iOS Notification Permissions: $permissions');

      if (permissions == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Could not check notification permissions. Please check Settings > Notifications > WakeMeUp'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // Send test notification
    try {
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Test notification channel',
        importance: Importance.max,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.critical,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await notificationsPlugin.show(
        999998,
        '🔔 Test Notification',
        'If you see this, notifications are working!',
        details,
      );

      debugPrint('✅ Test notification sent successfully');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Test notification sent! Check your notification center.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending test notification: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
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
