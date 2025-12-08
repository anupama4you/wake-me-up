import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';
import '../services/geofence_service.dart';
import '../services/alarm_storage_service.dart';
import '../services/alarm_sound_service.dart';
import '../services/tier_service.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import '../models/tier.dart';
import 'paywall_screen.dart';
import 'auth_screen.dart';
import 'help_screen.dart';

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

  final _authService = AuthService();
  final _subscriptionService = SubscriptionService();
  StreamSubscription<Tier>? _subscriptionStreamListener;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _listenToSubscriptionChanges();
  }

  @override
  void dispose() {
    _subscriptionStreamListener?.cancel();
    super.dispose();
  }

  /// Listen to subscription tier changes from RevenueCat
  void _listenToSubscriptionChanges() {
    _subscriptionStreamListener = _subscriptionService.subscriptionStream.listen((tier) {
      setState(() {
        _currentTier = tier;
      });
      // Reload tier limits when tier changes
      _loadTierLimits();
    });
  }

  /// Load tier limits separately
  Future<void> _loadTierLimits() async {
    final limits = await TierService.getTierLimits();
    setState(() {
      _tierLimits = limits;
    });
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
            // Account Section
            _buildAccountSection(),
            const SizedBox(height: 24),

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
              _buildSettingRow(
                'Help & Instructions',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                },
              ),
              const Divider(height: 1),
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

  Widget _buildAccountSection() {
    final currentUser = _authService.currentUser;
    final isSignedIn = currentUser != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSignedIn ? Icons.account_circle : Icons.account_circle_outlined,
                size: 28,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Text(
                'Account',
                style: AppTheme.headingMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          if (isSignedIn) ...[
            // User is signed in - show profile
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.email ?? 'No email',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSignInMethod(currentUser),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAccountOptions,
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Manage'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // User is not signed in - show sign in prompt
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign in to sync your data',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Access your alarms and subscriptions across all your devices',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToSignIn,
                    icon: const Icon(Icons.login, size: 20),
                    label: const Text('Sign In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getSignInMethod(User user) {
    for (final providerData in user.providerData) {
      if (providerData.providerId == 'google.com') {
        return 'Signed in with Google';
      } else if (providerData.providerId == 'password') {
        return 'Signed in with Email';
      }
    }
    return 'Signed in';
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
                        _currentTier.displayName,
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
              OutlinedButton(
                onPressed: () => _showPlanOptions(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Change Plan'),
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

  /// Show dialog to change subscription plan
  Future<void> _showChangePlanDialog() async {
    final result = await showDialog<Tier>(
      context: context,
      builder: (context) => _ChangePlanDialog(currentTier: _currentTier),
    );

    if (result != null && result != _currentTier) {
      if (!mounted) return;

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Switch to ${result.displayName}?'),
          content: Text(
            'You are about to switch from ${_currentTier.displayName} (${_currentTier.price}) '
            'to ${result.displayName} (${result.price}).\n\n'
            'This change will take effect immediately.',
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
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Change the tier
        await TierService.setTier(result);
        await _loadSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched to ${result.displayName} plan'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      }
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

  /// Show plan options (change plan or cancel subscription)
  Future<void> _showPlanOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Plan Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: AppTheme.primaryColor),
              title: const Text('View All Plans'),
              subtitle: const Text('Upgrade, downgrade, or compare plans'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaywallScreen(),
                  ),
                );
                _loadSettings();
              },
            ),
            if (_currentTier != Tier.free) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Cancel Subscription'),
                subtitle: const Text('Manage or cancel your subscription'),
                onTap: () {
                  Navigator.pop(context);
                  _manageSubscription();
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Open subscription management page via deep link
  Future<void> _manageSubscription() async {
    try {
      // Try to open App Store subscriptions page directly
      final url = Uri.parse('https://apps.apple.com/account/subscriptions');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: Show instructions if deep link fails
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Manage Subscription'),
            content: const Text(
              'To manage your subscription (cancel, change plan, etc.), '
              'go to your device\'s subscription settings:\n\n'
              '• iOS: Settings → [Your Name] → Subscriptions\n'
              '• Android: Play Store → Menu → Subscriptions',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to open subscription management: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please manage your subscription through iOS Settings → Subscriptions'),
        ),
      );
    }
  }

  /// Navigate to sign in screen
  Future<void> _navigateToSignIn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
    );
    // Reload settings after returning from auth screen
    _loadSettings();
  }

  /// Handle sign out
  Future<void> _handleSignOut() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange),
            SizedBox(width: 12),
            Text('Sign Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?\n\n'
          'You can sign back in anytime to restore your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Sign out from Firebase
      await _authService.signOut();

      // Reset to free tier
      await TierService.setTier(Tier.free);

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Reload settings
      await _loadSettings();

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show account options dialog
  Future<void> _showAccountOptions() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_reset, color: AppTheme.primaryColor),
              title: const Text('Reset Password'),
              subtitle: const Text('Send password reset email'),
              onTap: () => Navigator.pop(context, 'reset_password'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account'),
              subtitle: const Text('Permanently delete your account'),
              onTap: () => Navigator.pop(context, 'delete_account'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'reset_password') {
      _handlePasswordReset();
    } else if (action == 'delete_account') {
      _handleDeleteAccount();
    }
  }

  /// Handle password reset
  Future<void> _handlePasswordReset() async {
    final currentUser = _authService.currentUser;
    if (currentUser?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email associated with this account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text(
          'A password reset email will be sent to:\n\n${currentUser!.email}\n\n'
          'Please check your inbox and follow the instructions.',
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
            child: const Text('Send Email'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _authService.sendPasswordResetEmail(currentUser!.email!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle account deletion
  Future<void> _handleDeleteAccount() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    // Show warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          '⚠️ WARNING: This action cannot be undone!\n\n'
          'Deleting your account will:\n'
          '• Remove all your data\n'
          '• Cancel active subscriptions\n'
          '• Delete all saved alarms\n\n'
          'Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Delete all alarms
      await AlarmStorageService.deleteAllAlarms();

      // Delete account from Firebase
      await _authService.deleteAccount();

      // Reset to free tier
      await TierService.setTier(Tier.free);

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload settings
      await _loadSettings();
    } catch (e) {
      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
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
            max: 5000,
            divisions: 49,
            onChanged: (v) => setState(() => _value = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('100m', style: AppTheme.caption),
              Text('5km', style: AppTheme.caption),
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

// Change Plan Dialog
class _ChangePlanDialog extends StatelessWidget {
  final Tier currentTier;

  const _ChangePlanDialog({required this.currentTier});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Subscription Plan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: Tier.values.map((tier) {
            final isSelected = tier == currentTier;
            final benefits = TierBenefit.getBenefits(tier);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: isSelected ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => Navigator.pop(context, tier),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                tier.icon,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tier.displayName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppTheme.primaryColor : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    tier.price,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryColor,
                              size: 28,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      ...benefits.map((benefit) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: AppTheme.accentGreen,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    benefit,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
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
