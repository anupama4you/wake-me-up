import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/first_time_setup_service.dart';
import '../main_screen.dart';

/// Screen to request necessary permissions with context
class PermissionRequestScreen extends StatefulWidget {
  const PermissionRequestScreen({super.key});

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _locationGranted = false;
  bool _notificationsGranted = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
    // Listen for app lifecycle changes to detect when user returns from settings
    WidgetsBinding.instance.addObserver(this);

    // Setup animation for location icon
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned to app, recheck permissions
      _checkCurrentPermissions();
    }
  }

  Future<void> _checkCurrentPermissions() async {
    final permission = await Geolocator.checkPermission();
    setState(() {
      // IMPORTANT: Only "Always" permission is sufficient for background alarms
      _locationGranted = permission == LocationPermission.always;
    });

    // Check notification permissions (iOS specific)
    final plugin = FlutterLocalNotificationsPlugin();
    final iosPlugin = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final allowed = await iosPlugin.checkPermissions();
      setState(() {
        _notificationsGranted = allowed?.isEnabled ?? false;
      });
    }
  }

  /// Handle location permission tile tap
  Future<void> _handleLocationPermission() async {
    // Request location permission
    final permission = await Geolocator.requestPermission();

    // Update state
    if (mounted) {
      setState(() {
        _locationGranted = permission == LocationPermission.always;
      });
    }

    // If user selected "While Using App", explain that "Always" is required
    if (permission == LocationPermission.whileInUse) {
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Background Location Required'),
          content: const Text(
            'WakeMeUp needs "Always Allow" location access to wake you up even when:\n\n'
            '• The app is closed\n'
            '• Your phone is locked\n'
            '• You\'re using other apps\n\n'
            'Please change location permission to "Always" in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
    // If permission completely denied, show explanation
    else if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'WakeMeUp needs location access to alert you when you arrive at your destination.\n\n'
            'Please grant "Always Allow" location permission in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  /// Handle notification permission tile tap
  Future<void> _handleNotificationPermission() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final iosPlugin = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      // Try to request permissions (this will only work first time on iOS)
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (mounted) {
        setState(() {
          _notificationsGranted = granted ?? false;
        });
      }

      // If permission was denied (null means user hasn't decided, false means denied)
      // Note: On iOS, if user previously denied, requestPermissions returns the current state
      // and doesn't show the dialog again
      if (granted == false && mounted) {
        // Give a small delay to ensure state is updated
        await Future.delayed(const Duration(milliseconds: 300));

        if (!mounted) return;

        // Show dialog to direct user to Settings
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable Notifications'),
            content: const Text(
              'Notifications are currently disabled.\n\n'
              'To enable:\n'
              '1. Tap "Open Settings" below\n'
              '2. Find "Notifications"\n'
              '3. Enable "Allow Notifications"\n\n'
              'This allows the app to alert you when you arrive at your destination.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Open iOS app settings using the app-settings URL scheme
                  final url = Uri.parse('app-settings:');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _continueToApp() async {
    // Mark permissions setup as complete
    await FirstTimeSetupService.markPermissionsGranted();

    if (!mounted) return;

    // Navigate to main app
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Header icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Permissions Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),

              const SizedBox(height: 16),

              // Description
              const Text(
                'To wake you at the right place, we need:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryColor,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Step 1: Location Permission - Clickable Tile
              InkWell(
                onTap: _locationGranted ? null : _handleLocationPermission,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _locationGranted
                          ? AppTheme.accentGreen.withValues(alpha: 0.5)
                          : AppTheme.primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Animated container for location icon
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _locationGranted ? 1.0 : _pulseAnimation.value,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _locationGranted
                                        ? AppTheme.accentGreen.withValues(alpha: 0.15)
                                        : AppTheme.primaryColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _locationGranted ? Icons.check_circle : Icons.location_on,
                                    color: _locationGranted ? AppTheme.accentGreen : AppTheme.primaryColor,
                                    size: 28,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location - Always Allow',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _locationGranted
                                      ? 'Granted ✓'
                                      : 'Tap to grant permission',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _locationGranted
                                        ? AppTheme.accentGreen
                                        : AppTheme.textSecondaryColor,
                                    fontWeight: _locationGranted ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_locationGranted)
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppTheme.textSecondaryColor,
                            ),
                        ],
                      ),
                      if (!_locationGranted) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Select "Always Allow" in the popup or settings',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 14, color: AppTheme.textSecondaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Works when app is closed or phone is locked',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Step 2: Notifications Permission - Clickable Tile
              InkWell(
                onTap: _notificationsGranted ? null : _handleNotificationPermission,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _notificationsGranted
                          ? AppTheme.accentGreen.withValues(alpha: 0.5)
                          : AppTheme.borderColor,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _notificationsGranted
                              ? AppTheme.accentGreen.withValues(alpha: 0.15)
                              : AppTheme.primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _notificationsGranted ? Icons.check_circle : Icons.notifications,
                          color: _notificationsGranted ? AppTheme.accentGreen : AppTheme.primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _notificationsGranted
                                  ? 'Granted ✓'
                                  : 'Tap to grant permission',
                              style: TextStyle(
                                fontSize: 13,
                                color: _notificationsGranted
                                    ? AppTheme.accentGreen
                                    : AppTheme.textSecondaryColor,
                                fontWeight: _notificationsGranted ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_notificationsGranted)
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppTheme.textSecondaryColor,
                        ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              const SizedBox(height: 20),

              // Continue button - only show when both permissions granted
              if (_locationGranted && _notificationsGranted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continueToApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue to App',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Skip button (not recommended)
              if (!_locationGranted || !_notificationsGranted)
                TextButton(
                  onPressed: _continueToApp,
                  child: const Text(
                    'Skip for now (not recommended)',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

}
