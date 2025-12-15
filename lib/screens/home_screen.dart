import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/alarm.dart';
import '../models/tier.dart';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/tier_service.dart';
import '../services/first_time_setup_service.dart';
import '../utils/eta_calculator.dart';
import '../utils/app_health_monitor.dart';
import 'map_screen.dart';
import 'alarm_detail_map_screen.dart';
import 'auth_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Alarm> alarms;
  final Function(String, bool) onToggleAlarm;
  final Function(String) onDeleteAlarm;
  final VoidCallback onAddAlarm;
  final VoidCallback? onRefreshNeeded;

  const HomeScreen({
    Key? key,
    required this.alarms,
    required this.onToggleAlarm,
    required this.onDeleteAlarm,
    required this.onAddAlarm,
    this.onRefreshNeeded,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Position? _currentLocation;
  Timer? _locationUpdateTimer;
  bool _isAppInForeground = true;
  List<HealthIssue> _healthIssues = [];
  bool _healthCheckDone = false;
  bool _showWelcomeBanner = false;
  Tier _currentTier = Tier.free;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLocationTrackingIfNeeded();
    // Get immediate location if there are active alarms
    if (widget.alarms.any((alarm) => alarm.isActive)) {
      debugPrint(
        '📍 Active alarms detected on init - getting immediate location',
      );
      _updateCurrentLocation();
    }
    _checkAppHealth();
    _checkWelcomeBanner();
    _loadCurrentTier();
  }

  /// Check if we should show welcome banner for new users
  Future<void> _checkWelcomeBanner() async {
    final hasCreatedFirstAlarm =
        await FirstTimeSetupService.hasCreatedFirstAlarm();
    final hasAlarms = widget.alarms.isNotEmpty;

    if (mounted) {
      setState(() {
        // Show banner if user hasn't created first alarm and list is empty
        _showWelcomeBanner = !hasCreatedFirstAlarm && !hasAlarms;
      });
    }
  }

  void _dismissWelcomeBanner() {
    setState(() {
      _showWelcomeBanner = false;
    });
    FirstTimeSetupService.markFirstAlarmCreated();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if any alarm's active status changed
    bool hasActiveStatusChange = false;
    for (final alarm in widget.alarms) {
      final oldAlarm =
          oldWidget.alarms.where((old) => old.id == alarm.id).firstOrNull;
      if (oldAlarm != null && oldAlarm.isActive != alarm.isActive) {
        hasActiveStatusChange = true;
        debugPrint(
          '📍 Alarm ${alarm.id} status changed: ${oldAlarm.isActive} → ${alarm.isActive}',
        );
        break;
      }
    }

    // Check if there are new active alarms (alarm list comparison by ID and status)
    final oldActiveIds =
        oldWidget.alarms.where((a) => a.isActive).map((a) => a.id).toSet();
    final newActiveIds =
        widget.alarms.where((a) => a.isActive).map((a) => a.id).toSet();
    final hasNewActiveAlarms = newActiveIds.difference(oldActiveIds).isNotEmpty;

    // If alarms list changed or active status changed, restart location tracking
    if (widget.alarms.length != oldWidget.alarms.length ||
        hasActiveStatusChange ||
        hasNewActiveAlarms) {
      debugPrint(
        '📍 Alarms changed (count: ${oldWidget.alarms.length} → ${widget.alarms.length}, newActive: $hasNewActiveAlarms) - restarting location tracking',
      );
      _stopLocationTracking(); // Stop first to clean up
      _startLocationTrackingIfNeeded(); // Then restart and get immediate location
      _updateCurrentLocation(); // Get location immediately for progress bar
    }
  }

  /// Load current subscription tier
  Future<void> _loadCurrentTier() async {
    final tier = await TierService.getCurrentTier();
    if (mounted) {
      setState(() {
        _currentTier = tier;
      });
    }
  }

  /// Check app health on startup
  Future<void> _checkAppHealth() async {
    final issues = await AppHealthMonitor.getHealthIssues();
    if (mounted) {
      setState(() {
        _healthIssues = issues;
        _healthCheckDone = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - start smart polling
        debugPrint(
          '📱 App resumed - starting smart GPS polling for UI updates',
        );
        _isAppInForeground = true;
        _startLocationTrackingIfNeeded();
        // Get immediate location if there are active alarms
        if (widget.alarms.any((alarm) => alarm.isActive)) {
          debugPrint(
            '📍 Active alarms detected on resume - getting immediate location',
          );
          _updateCurrentLocation();
        }
        // Re-check app health when returning from Settings
        debugPrint('🔍 Re-checking app health after resume');
        _checkAppHealth();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background - STOP polling (geofencing continues!)
        debugPrint('📱 App backgrounded - stopping GPS polling');
        debugPrint('✅ Geofencing still active - alarms will work!');
        _isAppInForeground = false;
        _stopLocationTracking();
        break;
    }
  }

  /// Start tracking location ONLY if app is visible and has active alarms
  void _startLocationTrackingIfNeeded() {
    // Don't start if app is in background
    if (!_isAppInForeground) {
      debugPrint(
        '🔋 App in background - GPS polling disabled (geofencing handles alarms)',
      );
      return;
    }

    // Don't start if no active alarms
    final hasActiveAlarms = widget.alarms.any((alarm) => alarm.isActive);
    if (!hasActiveAlarms) {
      debugPrint('🔋 No active alarms - GPS polling disabled');
      return;
    }

    // Get initial location
    _updateCurrentLocation();

    // Use user's configured update interval (default: 5s, customizable in Settings)
    final updateInterval = SettingsService.updateInterval;
    debugPrint(
      '📍 GPS polling enabled: ${updateInterval}s interval (UI updates only)',
    );
    debugPrint('🔋 Battery-efficient mode: Polling only when app is visible');

    // Set up periodic updates ONLY when app is visible
    _locationUpdateTimer?.cancel(); // Cancel existing timer if any
    _locationUpdateTimer = Timer.periodic(Duration(seconds: updateInterval), (
      _,
    ) {
      if (_isAppInForeground) {
        _updateCurrentLocation();
      }
    });
  }

  /// Stop location tracking to save battery
  void _stopLocationTracking() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    debugPrint('🔋 GPS polling stopped - saving battery');
    debugPrint('✅ Geofencing continues monitoring in background');
  }

  /// Update current location
  Future<void> _updateCurrentLocation() async {
    try {
      // Check if we have any active alarms
      final hasActiveAlarms = widget.alarms.any((alarm) => alarm.isActive);
      if (!hasActiveAlarms) {
        debugPrint('⚠️ No active alarms - skipping location update');
        return;
      }

      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission denied - cannot update location');
        return;
      }

      // Get current position using settings
      final useHighAccuracy = SettingsService.highAccuracy;
      final accuracy =
          useHighAccuracy ? LocationAccuracy.high : LocationAccuracy.medium;

      debugPrint('📍 Fetching current position (accuracy: $accuracy)...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      );

      debugPrint(
        '✅ Location received: ${position.latitude}, ${position.longitude}',
      );

      if (mounted) {
        setState(() {
          _currentLocation = position;
        });
        debugPrint(
          '✅ Location state updated - UI should rebuild with progress bar',
        );
      } else {
        debugPrint('⚠️ Widget not mounted - cannot update state');
      }
    } catch (e) {
      // Ignore errors silently
      debugPrint('❌ Location update error: $e');
    }
  }

  /// Navigate to edit alarm screen
  Future<void> _editAlarm(BuildContext context, Alarm alarm) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapScreen(existingAlarm: alarm)),
    );
    // Trigger refresh after editing
    widget.onRefreshNeeded?.call();
  }

  /// Show delete confirmation dialog
  Future<bool> _confirmDelete(BuildContext context, Alarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Alarm'),
            content: Text('Are you sure you want to delete "${alarm.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      widget.onDeleteAlarm(alarm.id);
      return true;
    }
    return false;
  }

  /// Show help dialog with instructions
  /// Show user menu when profile icon is tapped
  void _showUserMenu(BuildContext context, String email) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User info header
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingLarge),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.accentGreen,
                        radius: 24,
                        child: Text(
                          email.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.paddingMedium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Signed in',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu items
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Instructions'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to settings screen directly
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(onSettingsApplied: widget.onRefreshNeeded),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final authService = AuthService();
                    await authService.signOut();
                  },
                ),
              ],
            ),
          ),
    );
  }

  /// Build swipe background for edit/delete actions
  Widget _buildSwipeBackground(bool isEdit) {
    return Container(
      decoration: BoxDecoration(
        color: (isEdit ? AppTheme.primaryColor : AppTheme.errorColor)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingMedium),
      alignment: isEdit ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEdit ? Icons.edit_rounded : Icons.delete_rounded,
            color: isEdit ? AppTheme.primaryColor : AppTheme.errorColor,
          ),
          const SizedBox(width: AppTheme.paddingSmall),
          Text(
            isEdit ? 'Edit' : 'Delete',
            style: AppTheme.labelLarge.copyWith(
              color: isEdit ? AppTheme.primaryColor : AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Show maximum limit dialog

  @override
  Widget build(BuildContext context) {
    // Count active alarms
    final activeCount = widget.alarms.where((a) => a.isActive).length;

    final authService = AuthService();
    final currentUser = authService.currentUser;
    final isSignedIn = currentUser != null;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 115,
        leading: Row(
          children: [
            IconButton(
              icon: CircleAvatar(
                backgroundColor:
                    isSignedIn
                        ? AppTheme.accentGreen
                        : Colors.white.withValues(alpha: 0.3),
                radius: 16,
                child:
                    isSignedIn
                        ? Text(
                          currentUser.email?.substring(0, 1).toUpperCase() ??
                              'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                        : const Icon(
                          Icons.person_outline,
                          color: AppTheme.textOnPrimaryColor,
                          size: 20,
                        ),
              ),
              onPressed: () {
                if (isSignedIn) {
                  // Show user menu
                  _showUserMenu(context, currentUser.email ?? 'User');
                } else {
                  // Navigate to auth screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                }
              },
              tooltip: isSignedIn ? currentUser.email : 'Sign In',
            ),
            // Tier badge next to profile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_currentTier.icon} ${_currentTier.displayName}',
                style: const TextStyle(
                  color: AppTheme.textOnPrimaryColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        title: Image.asset(
          'assets/icons/wakemeup_text.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          // Show active alarm indicator badge
          if (activeCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.paddingSmall),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingSmall + 2,
                    vertical: AppTheme.paddingXSmall,
                  ),
                  decoration: AppTheme.badgeDecoration(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.radio_button_checked,
                        color: AppTheme.textOnPrimaryColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$activeCount',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.textOnPrimaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.textOnPrimaryColor),
            onPressed: widget.onAddAlarm,
          ),
        ],
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child:
            widget.alarms.isEmpty
                ? _EmptyState(onAddAlarm: widget.onAddAlarm)
                : Column(
                  children: [
                    // Health check banner (shows if there are critical issues)
                    if (_healthCheckDone && _healthIssues.isNotEmpty)
                      _buildHealthBanner(),
                    // Welcome banner for new users
                    if (_showWelcomeBanner) _buildWelcomeBanner(),
                    // Alarm list
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.alarms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final alarm = widget.alarms[index];

                          // Calculate distance and ETA if alarm is active and we have location
                          double? distance;
                          Duration? eta;
                          if (alarm.isActive && _currentLocation != null) {
                            distance = Geolocator.distanceBetween(
                              _currentLocation!.latitude,
                              _currentLocation!.longitude,
                              alarm.latitude,
                              alarm.longitude,
                            );

                            // Calculate ETA using new calculator
                            eta = ETACalculator.calculateETA(
                              currentDistance: distance,
                              currentPosition: _currentLocation!,
                            );
                          }

                          // Wrap card with Dismissible for swipe actions
                          return Dismissible(
                            key: ValueKey(alarm.id),
                            // Allow swipe actions for all alarms (including active/completed ones)
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                // Swipe left - Delete action (always allowed)
                                return await _confirmDelete(context, alarm);
                              } else if (direction ==
                                  DismissDirection.startToEnd) {
                                // Swipe right - Edit action
                                // For ALL active alarms (including completed), show message to toggle off first
                                if (alarm.isActive) {
                                  final message =
                                      alarm.isCompleted
                                          ? 'Please toggle off the completed alarm before editing'
                                          : 'Please toggle off the alarm before editing';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return false;
                                }
                                // Only allow editing of inactive alarms
                                await _editAlarm(context, alarm);
                                return false; // Don't dismiss
                              }
                              return false;
                            },
                            background: _buildSwipeBackground(
                              true,
                            ), // Edit (left side)
                            secondaryBackground: _buildSwipeBackground(
                              false,
                            ), // Delete (right side)
                            child: _AlarmCard(
                              alarm: alarm,
                              currentDistance: distance,
                              eta: eta,
                              onTap: () {
                                if (alarm.isActive) {
                                  // Active alarm: Navigate to live map detail view
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => AlarmDetailMapScreen(
                                            alarm: alarm,
                                          ),
                                    ),
                                  );
                                } else {
                                  // Inactive alarm: Navigate to edit screen
                                  _editAlarm(context, alarm);
                                }
                              },
                              onToggle: (active) async {
                                // Simply toggle the alarm without warnings
                                widget.onToggleAlarm(alarm.id, active);
                              },
                            ),
                          ); // Close Dismissible widget
                        },
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  /// Build welcome banner for new users
  Widget _buildWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.accentGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.celebration,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to WakeMeUp!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You\'re all set up!',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _dismissWelcomeBanner,
                tooltip: 'Dismiss',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Ready to create your first alarm?',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.touch_app,
                size: 18,
                color: AppTheme.primaryColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tap the + button below to set your first location alarm',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build health check banner showing critical issues
  Widget _buildHealthBanner() {
    final criticalIssues =
        _healthIssues
            .where((i) => i.severity == HealthIssueSeverity.critical)
            .toList();

    if (criticalIssues.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${criticalIssues.length} Critical Issue${criticalIssues.length > 1 ? 's' : ''} Detected',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            criticalIssues.first.title,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  AppHealthMonitor.showHealthCheckDialog(context);
                },
                child: const Text('View Details'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: criticalIssues.first.fixAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text(criticalIssues.first.fixButtonLabel ?? 'Fix'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ----------------------------- Empty State ------------------------------ */

class _EmptyState extends StatefulWidget {
  final VoidCallback onAddAlarm;

  const _EmptyState({Key? key, required this.onAddAlarm}) : super(key: key);

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated illustration
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      Opacity(
                        opacity: 1.0 - _fadeAnimation.value,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      // Middle ring
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Inner circle with icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 0.15),
                              AppTheme.accentGreen.withValues(alpha: 0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_location_alt_rounded,
                          size: 64,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              'Start Your Journey',
              style: AppTheme.displaySmall.copyWith(
                color: AppTheme.textPrimaryColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Description
            Text(
              'Never miss your stop again!\nSet location-based alarms for your bus, train, or any journey.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
                height: 1.6,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 24),

            // Feature highlights
            _buildFeatureRow(
              Icons.location_pin,
              'Pin Your Destination',
              'Set alarms for any location',
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              Icons.bedtime_rounded,
              'Sleep Peacefully',
              'We\'ll wake you when you arrive',
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              Icons.phone_android_rounded,
              'Works in Background',
              'Even when your phone is locked',
            ),

            const SizedBox(height: 28),

            // CTA button with animation
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.6 + (_fadeAnimation.value * 0.4),
                  child: GestureDetector(
                    onTap: widget.onAddAlarm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.accentGreen],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 24,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Create Your First Alarm',
                            style: AppTheme.labelLarge.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------- Card ---------------------------------- */

class _AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final double? currentDistance;
  final Duration? eta;

  const _AlarmCard({
    Key? key,
    required this.alarm,
    required this.onTap,
    required this.onToggle,
    this.currentDistance,
    this.eta,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Modern styling for active vs inactive vs completed cards
    final bool isActive = alarm.isActive;
    final bool isCompleted = alarm.isCompleted;

    // Determine card colors based on state
    Color? cardBackground;
    BoxDecoration cardDecoration;

    if (isCompleted) {
      cardBackground = AppTheme.successColor.withValues(alpha: 0.08);
      cardDecoration = BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      );
    } else {
      cardDecoration = AppTheme.alarmCardDecoration(isActive: isActive);
    }

    return Material(
      color: isCompleted ? null : (isActive ? null : AppTheme.cardColor),
      borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      elevation: isActive ? AppTheme.elevationMedium : AppTheme.elevationNone,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          decoration: cardDecoration,
          child: Row(
            children: [
              // Animated pin with pulsing radius (or completed checkmark)
              if (isCompleted)
                _CompletedBadge()
              else
                _AnimatedLocationPin(active: alarm.isActive),
              const SizedBox(width: 12),

              // Texts (name, address, radius|sound)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Location name | switch or edit button
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alarm.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.headingMedium.copyWith(
                              color:
                                  isCompleted
                                      ? AppTheme.successColor
                                      : AppTheme.getTextColor(
                                        isActive: isActive,
                                      ),
                            ),
                          ),
                        ),
                        // Always show switch - completed alarms can be toggled off
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Show completed badge next to switch when completed
                            if (isCompleted)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.successColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Arrived',
                                      style: AppTheme.labelSmall.copyWith(
                                        color: AppTheme.successColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Switch.adaptive(
                              value: alarm.isActive,
                              onChanged: onToggle,
                              activeColor:
                                  isCompleted
                                      ? AppTheme.successColor
                                      : AppTheme.accentGreen,
                              inactiveThumbColor: AppTheme.textOnPrimaryColor,
                              inactiveTrackColor: AppTheme.borderColor,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.paddingXSmall),

                    // Address
                    Text(
                      alarm.address ?? 'No address set',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall.copyWith(
                        color:
                            isCompleted
                                ? AppTheme.successColor.withValues(alpha: 0.7)
                                : AppTheme.getTextColor(
                                  isActive: isActive,
                                  isSecondary: true,
                                ),
                      ),
                    ),

                    // Progress bar (only for active alarms with location data)
                    // Show completed progress for completed alarms
                    if (isCompleted) ...[
                      const SizedBox(height: AppTheme.paddingSmall),
                      _CompletedProgressIndicator(),
                    ] else if (isActive && currentDistance != null) ...[
                      const SizedBox(height: AppTheme.paddingSmall),
                      _ProgressIndicator(
                        distance: currentDistance!,
                        eta: eta,
                        targetRadius: alarm.radius,
                        isActive: isActive,
                      ),
                    ],

                    const SizedBox(height: AppTheme.paddingSmall + 2),

                    // Bottom meta: radius | sound
                    Row(
                      children: [
                        _MetaChip(
                          icon: Icons.radar,
                          label: '${alarm.radius?.toStringAsFixed(0) ?? '-'} m',
                          isActive: isActive,
                          isCompleted: isCompleted,
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: Icons.volume_up,
                          label: alarm.soundLevel ?? 'Default',
                          isActive: isActive,
                          isCompleted: isCompleted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------- Animated Pin Widget ------------------------ */

class _AnimatedLocationPin extends StatefulWidget {
  final bool active;
  const _AnimatedLocationPin({Key? key, required this.active})
    : super(key: key);

  @override
  State<_AnimatedLocationPin> createState() => _AnimatedLocationPinState();
}

class _AnimatedLocationPinState extends State<_AnimatedLocationPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = Tween<double>(
      begin: 0.35,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _AnimatedLocationPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _pinColor =>
      widget.active ? AppTheme.accentGreen : AppTheme.textSecondaryColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing radius
          if (widget.active)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Transform.scale(
                  scale: _scale.value,
                  child: Opacity(
                    opacity: _fade.value,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentGreenLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          // Pin badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _pinColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_pin, color: _pinColor),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------- Meta Chip ------------------------------ */

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _MetaChip({
    Key? key,
    required this.icon,
    required this.label,
    this.isActive = false,
    this.isCompleted = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chipColor =
        isCompleted ? AppTheme.successColor.withValues(alpha: 0.1) : null;
    final contentColor =
        isCompleted
            ? AppTheme.successColor.withValues(alpha: 0.7)
            : AppTheme.getTextColor(isActive: isActive);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingSmall + 2,
        vertical: 6,
      ),
      decoration:
          isCompleted
              ? BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              )
              : AppTheme.chipDecoration(isActive: isActive),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color:
                isCompleted
                    ? AppTheme.successColor.withValues(alpha: 0.7)
                    : AppTheme.getIconColor(isActive: isActive),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.labelMedium.copyWith(color: contentColor),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- Progress Indicator --------------------------- */

class _ProgressIndicator extends StatelessWidget {
  final double distance;
  final Duration? eta;
  final double targetRadius;
  final bool isActive;

  const _ProgressIndicator({
    required this.distance,
    required this.targetRadius,
    this.eta,
    required this.isActive,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress for the progress bar
    final progress = ETACalculator.calculateProgress(
      currentDistance: distance,
      targetRadius: targetRadius,
    );

    // Get color based on ETA or progress
    final progressColor = ETACalculator.getProgressColor(
      progress: progress,
      eta: eta,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Distance text and ETA (instead of percentage)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.navigation_rounded,
                  size: 14,
                  color: AppTheme.getTextColor(
                    isActive: isActive,
                    isSecondary: true,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDistance(distance),
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.getTextColor(
                      isActive: isActive,
                      isSecondary: true,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            // Show ETA instead of percentage
            Text(
              ETACalculator.formatETA(eta, shortFormat: true),
              style: AppTheme.labelSmall.copyWith(
                color: progressColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor:
                isActive
                    ? AppTheme.activeAlarmBorder.withValues(alpha: 0.2)
                    : AppTheme.borderColor.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

/* ------------------------- Completed Badge --------------------------- */

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Green circle background
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppTheme.successColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------- Completed Progress Indicator ------------------ */

class _CompletedProgressIndicator extends StatelessWidget {
  const _CompletedProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Arrived text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 14,
                  color: AppTheme.successColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Destination reached',
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '100%',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.successColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Full progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 1.0,
            minHeight: 6,
            backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.successColor,
            ),
          ),
        ),
      ],
    );
  }
}
