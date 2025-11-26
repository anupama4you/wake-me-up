import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/alarm.dart';
import '../theme/app_theme.dart';
import 'map_screen.dart';
import 'alarm_detail_map_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  bool _isEditMode = false;
  Position? _currentLocation;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  /// Start tracking location for progress bars
  void _startLocationTracking() {
    // Get initial location
    _updateCurrentLocation();

    // Set up periodic updates every 3 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _updateCurrentLocation();
    });
  }

  /// Update current location
  Future<void> _updateCurrentLocation() async {
    try {
      // Check if we have any active alarms
      final hasActiveAlarms = widget.alarms.any((alarm) => alarm.isActive);
      if (!hasActiveAlarms) return;

      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentLocation = position;
        });
      }
    } catch (e) {
      // Ignore errors silently
      debugPrint('Location update error: $e');
    }
  }

  /// Calculate distance between two coordinates in meters
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000; // meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Calculate progress percentage (0-100)
  /// Progress always starts from current location (0%) to destination (100%)
  int _calculateProgress(double currentDistance, double targetRadius) {
    // If inside geofence, you've arrived
    if (currentDistance <= targetRadius) {
      return 100;
    }

    // For active alarms, we want to show progress from wherever you are
    // Since we don't track starting distance, we'll use a dynamic scale:
    // - Show low % when far away
    // - Show high % when close
    // Use logarithmic scale for better visual feedback

    // Define distance thresholds for visual feedback
    if (currentDistance > 10000) {
      // More than 10km: show 1-10%
      final ratio = (currentDistance - 10000) / 10000; // Normalize beyond 10km
      return max(1, (10 - (ratio * 5)).round()).clamp(1, 10);
    } else if (currentDistance > 5000) {
      // 5-10km: show 10-30%
      final ratio = (10000 - currentDistance) / 5000;
      return (10 + (ratio * 20)).round();
    } else if (currentDistance > 2000) {
      // 2-5km: show 30-50%
      final ratio = (5000 - currentDistance) / 3000;
      return (30 + (ratio * 20)).round();
    } else if (currentDistance > 1000) {
      // 1-2km: show 50-70%
      final ratio = (2000 - currentDistance) / 1000;
      return (50 + (ratio * 20)).round();
    } else if (currentDistance > targetRadius) {
      // Less than 1km but outside radius: show 70-99%
      final ratio = (1000 - currentDistance) / (1000 - targetRadius);
      return (70 + (ratio * 29)).round().clamp(70, 99);
    }

    return 100;
  }

  /// Format distance for display
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  /// Show battery warning dialog when enabling multiple alarms
  Future<bool?> _showBatteryWarning(
    BuildContext context,
    int totalActive,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.battery_alert, color: AppTheme.warningColor, size: 28),
            const SizedBox(width: 12),
            const Text('Battery Usage Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to enable $totalActive active alarms.',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            Text(
              'Multiple active alarms will:',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildWarningPoint(
              Icons.battery_charging_full,
              'Increase battery usage',
            ),
            _buildWarningPoint(
              Icons.location_on,
              'Track your location continuously',
            ),
            _buildWarningPoint(Icons.gps_fixed, 'Check GPS every 10 seconds'),
            const SizedBox(height: AppTheme.paddingMedium),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: AppTheme.infoColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates,
                    color: AppTheme.infoColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.paddingSmall),
                  Expanded(
                    child: Text(
                      'Tip: Disable alarms when not needed to save battery',
                      style: AppTheme.labelMedium.copyWith(
                        color: AppTheme.infoColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: AppTheme.textOnPrimaryColor,
            ),
            child: const Text('Enable Anyway'),
          ),
        ],
      ),
    );
  }

  /// Build warning point widget
  Widget _buildWarningPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.paddingSmall, bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppTheme.iconSizeSmall,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: AppTheme.paddingSmall),
          Text(text, style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  /// Show maximum limit dialog
  Future<void> _showMaxLimitDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.errorColor, size: 28),
            const SizedBox(width: AppTheme.paddingMedium),
            const Text('Maximum Limit Reached'),
          ],
        ),
        content: Text(
          'You can have a maximum of 10 active alarms at once.\n\n'
          'Please disable some alarms before enabling new ones.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Count active alarms
    final activeCount = widget.alarms.where((a) => a.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Image.asset(
            'assets/icons/wakemeup_text.png',
            height: 36,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _isEditMode ? Icons.done : Icons.edit,
            color: AppTheme.textOnPrimaryColor,
          ),
          onPressed: () {
            setState(() {
              _isEditMode = !_isEditMode;
            });
          },
        ),
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
        child: widget.alarms.isEmpty
            ? _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.alarms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final alarm = widget.alarms[index];

                  // Calculate distance and progress if alarm is active and we have location
                  double? distance;
                  int? progress;
                  if (alarm.isActive && _currentLocation != null) {
                    distance = _calculateDistance(
                      _currentLocation!.latitude,
                      _currentLocation!.longitude,
                      alarm.latitude,
                      alarm.longitude,
                    );
                    progress = _calculateProgress(distance, alarm.radius);
                  }

                  return _AlarmCard(
                    alarm: alarm,
                    isEditMode: _isEditMode,
                    currentDistance: distance,
                    progress: progress,
                    onTap: () {
                      // Navigate to live map detail view
                      if (alarm.isActive) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AlarmDetailMapScreen(alarm: alarm),
                          ),
                        );
                      }
                    },
                    onEdit: () async {
                      // Navigate to edit screen
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapScreen(existingAlarm: alarm),
                        ),
                      );
                      // Exit edit mode after editing
                      setState(() {
                        _isEditMode = false;
                      });
                      // Trigger refresh after editing
                      widget.onRefreshNeeded?.call();
                    },
                    onDelete: () => widget.onDeleteAlarm(alarm.id),
                    onToggle: (active) async {
                      // If we're turning ON an inactive alarm:
                      if (active && !alarm.isActive) {
                        // Count currently active alarms
                        final activeCount = widget.alarms
                            .where((a) => a.isActive && a.id != alarm.id)
                            .length;

                        // Check maximum limit first (10 active alarms)
                        if (activeCount >= 10) {
                          await _showMaxLimitDialog(context);
                          return;
                        }

                        // Show battery warning if enabling 2nd or more alarm
                        if (activeCount >= 1) {
                          final shouldEnable = await _showBatteryWarning(
                            context,
                            activeCount + 1,
                          );
                          if (shouldEnable == true) {
                            widget.onToggleAlarm(alarm.id, true);
                          }
                          return;
                        }

                        // First alarm - no warning needed
                        widget.onToggleAlarm(alarm.id, true);
                        return;
                      }

                      // Otherwise just forward the toggle
                      widget.onToggleAlarm(alarm.id, active);
                    },
                  );
                },
              ),
      ),
    );
  }
}

/* ----------------------------- Empty State ------------------------------ */

class _EmptyState extends StatelessWidget {
  const _EmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_outlined,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: AppTheme.paddingLarge),
          Text(
            'No Location Alarms',
            style: AppTheme.displaySmall.copyWith(
              color: AppTheme.textPrimaryColor,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: AppTheme.paddingSmall),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingXLarge,
            ),
            child: Text(
              'Create your first location-based alarm to get notified when you arrive',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.paddingLarge),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingMedium,
              vertical: AppTheme.paddingSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.accentGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 18,
                  color: AppTheme.accentGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap the + button to get started',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.accentGreen,
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

/* ----------------------------- Dismissible ------------------------------ */

class _DismissibleAlarmCard extends StatelessWidget {
  final Alarm alarm;
  final Widget child;
  final VoidCallback onDelete;

  const _DismissibleAlarmCard({
    Key? key,
    required this.alarm,
    required this.child,
    required this.onDelete,
  }) : super(key: key);

  Future<bool?> _confirm(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alarm?'),
        content: Text('Are you sure you want to delete "${alarm.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(alarm.id),
      direction: DismissDirection.startToEnd, // slide right
      confirmDismiss: (_) => _confirm(context),
      onDismissed: (_) {
        onDelete();
        // No app notification for delete
      },
      background: Container(
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingMedium),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.delete, color: AppTheme.errorColor),
            const SizedBox(width: AppTheme.paddingSmall),
            Text(
              'Delete',
              style: AppTheme.labelLarge.copyWith(color: AppTheme.errorColor),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

/* -------------------------------- Card ---------------------------------- */

class _AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final bool isEditMode;
  final double? currentDistance;
  final int? progress;

  const _AlarmCard({
    Key? key,
    required this.alarm,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.isEditMode,
    this.currentDistance,
    this.progress,
  }) : super(key: key);

  /// Format distance for display
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m away';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)}km away';
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alarm'),
        content: Text('Are you sure you want to delete "${alarm.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDelete();
    }
  }

  /// Format completed time
  String _formatCompletedTime(DateTime? completedAt) {
    if (completedAt == null) return 'Completed';
    final now = DateTime.now();
    final diff = now.difference(completedAt);
    if (diff.inMinutes < 1) {
      return 'Just arrived';
    } else if (diff.inMinutes < 60) {
      return 'Arrived ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Arrived ${diff.inHours}h ago';
    } else {
      return 'Arrived ${diff.inDays}d ago';
    }
  }

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
        onTap: isEditMode ? onEdit : onTap,
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
                              color: isCompleted
                                  ? AppTheme.successColor
                                  : AppTheme.getTextColor(isActive: isActive),
                            ),
                          ),
                        ),
                        // Show edit/delete buttons or switch
                        if (isEditMode)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ModernActionButton(
                                icon: Icons.edit_rounded,
                                color: AppTheme.primaryColor,
                                onPressed: onEdit,
                                tooltip: 'Edit',
                              ),
                              const SizedBox(width: 8),
                              _ModernActionButton(
                                icon: Icons.delete_rounded,
                                color: AppTheme.errorColor,
                                onPressed: () =>
                                    _showDeleteConfirmation(context),
                                tooltip: 'Delete',
                              ),
                            ],
                          )
                        else
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
                                activeThumbColor: AppTheme.textOnPrimaryColor,
                                activeTrackColor: isCompleted
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
                        color: isCompleted
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
                    ] else if (isActive &&
                        currentDistance != null &&
                        progress != null) ...[
                      const SizedBox(height: AppTheme.paddingSmall),
                      _ProgressIndicator(
                        distance: currentDistance!,
                        progress: progress!,
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
    final chipColor = isCompleted
        ? AppTheme.successColor.withValues(alpha: 0.1)
        : null;
    final contentColor = isCompleted
        ? AppTheme.successColor.withValues(alpha: 0.7)
        : AppTheme.getTextColor(isActive: isActive);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingSmall + 2,
        vertical: 6,
      ),
      decoration: isCompleted
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
            color: isCompleted
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

/* ------------------------- Modern Action Button ------------------------- */

class _ModernActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  const _ModernActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

/* ------------------------- Progress Indicator --------------------------- */

class _ProgressIndicator extends StatelessWidget {
  final double distance;
  final int progress;
  final bool isActive;

  const _ProgressIndicator({
    required this.distance,
    required this.progress,
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
    final progressColor = progress >= 75
        ? AppTheme.successColor
        : progress >= 40
        ? AppTheme.accentGreen
        : AppTheme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Distance text and progress percentage
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
            Text(
              '$progress%',
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
            value: progress / 100,
            minHeight: 6,
            backgroundColor: isActive
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
