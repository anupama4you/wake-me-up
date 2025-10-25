import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../theme/app_theme.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Alarm> alarms;
  final Function(String, bool) onToggleAlarm;
  final Function(String) onDeleteAlarm;
  final VoidCallback onAddAlarm;

  const HomeScreen({
    Key? key,
    required this.alarms,
    required this.onToggleAlarm,
    required this.onDeleteAlarm,
    required this.onAddAlarm,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isEditMode = false;

  /// Show battery warning dialog when enabling multiple alarms
  Future<bool?> _showBatteryWarning(BuildContext context, int totalActive) async {
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
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 8),
            _buildWarningPoint(Icons.battery_charging_full, 'Increase battery usage'),
            _buildWarningPoint(Icons.location_on, 'Track your location continuously'),
            _buildWarningPoint(Icons.gps_fixed, 'Check GPS every 10 seconds'),
            const SizedBox(height: AppTheme.paddingMedium),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates, color: AppTheme.infoColor, size: 20),
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
          Icon(icon, size: AppTheme.iconSizeSmall, color: AppTheme.warningColor),
          const SizedBox(width: AppTheme.paddingSmall),
          Text(
            text,
            style: AppTheme.bodySmall,
          ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WakeMeUp', style: TextStyle(color: AppTheme.textOnPrimaryColor, fontSize: 20)),
            if (activeCount > 0)
              Text(
                '$activeCount active ${activeCount == 1 ? 'alarm' : 'alarms'}',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textOnPrimaryColor.withValues(alpha: 0.9),
                ),
              ),
          ],
        ),
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
                  return _DismissibleAlarmCard(
                    alarm: alarm,
                    onDelete: () => widget.onDeleteAlarm(alarm.id),
                    child: _AlarmCard(
                      alarm: alarm,
                      isEditMode: _isEditMode,
                      onTap: () {
                        // Card tap disabled in normal mode - no action
                      },
                      onEdit: () async {
                        // Navigate to edit screen
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MapScreen(existingAlarm: alarm),
                          ),
                        );
                        if (result != null && result is Map && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Alarm updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
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
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/* ----------------------------- Empty State ------------------------------ */

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.alarm_off, size: 100, color: AppTheme.borderColor),
          const SizedBox(height: AppTheme.paddingMedium),
          Text(
            'No Alarms Yet',
            style: AppTheme.displaySmall.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.paddingSmall),
          Text(
            'Tap the + button to create your first alarm',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textDisabledColor,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${alarm.name}"'),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
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
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.errorColor,
              ),
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
  final ValueChanged<bool> onToggle;
  final bool isEditMode;

  const _AlarmCard({
    Key? key,
    required this.alarm,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.isEditMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Modern styling for active vs inactive cards
    final bool isActive = alarm.isActive;

    return Material(
      color: isActive ? null : AppTheme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      elevation: isActive ? AppTheme.elevationMedium : AppTheme.elevationNone,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        onTap: isEditMode ? onEdit : onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          decoration: AppTheme.alarmCardDecoration(isActive: isActive),
          child: Row(
            children: [
              // Animated pin with pulsing radius
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
                              color: AppTheme.getTextColor(isActive: isActive),
                            ),
                          ),
                        ),
                        // Show edit button in edit mode, switch otherwise
                        if (isEditMode)
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                            onPressed: onEdit,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          Switch.adaptive(
                            value: alarm.isActive,
                            onChanged: onToggle,
                            activeThumbColor: AppTheme.textOnPrimaryColor,
                            activeTrackColor: AppTheme.accentGreen,
                            inactiveThumbColor: AppTheme.textOnPrimaryColor,
                            inactiveTrackColor: AppTheme.borderColor,
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
                        color: AppTheme.getTextColor(isActive: isActive, isSecondary: true),
                      ),
                    ),

                    const SizedBox(height: AppTheme.paddingSmall + 2),

                    // Bottom meta: radius | sound
                    Row(
                      children: [
                        _MetaChip(
                          icon: Icons.radar,
                          label: '${alarm.radius?.toStringAsFixed(0) ?? '-'} m',
                          isActive: isActive,
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: Icons.volume_up,
                          label: alarm.soundLevel ?? 'Default',
                          isActive: isActive,
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

  const _MetaChip({
    Key? key,
    required this.icon,
    required this.label,
    this.isActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingSmall + 2,
        vertical: 6,
      ),
      decoration: AppTheme.chipDecoration(isActive: isActive),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: AppTheme.getIconColor(isActive: isActive),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.getTextColor(isActive: isActive),
            ),
          ),
        ],
      ),
    );
  }
}
