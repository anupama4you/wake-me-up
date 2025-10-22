import 'package:flutter/material.dart';
import '../models/alarm.dart';
// import '../widgets/alarm_card.dart'; // No longer needed
import 'active_alarm_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Alarms', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[600],
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey[50],
        child: alarms.isEmpty
            ? _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: alarms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final alarm = alarms[index];
                  return _DismissibleAlarmCard(
                    alarm: alarm,
                    onDelete: () => onDeleteAlarm(alarm.id),
                    child: _AlarmCard(
                      alarm: alarm,
                      onTap: () async {
                        // Edit flow
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MapScreen(existingAlarm: alarm),
                          ),
                        );
                        if (result != null && result is Map) {
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
                          onToggleAlarm(alarm.id, true);
                          return;
                        }

                        // Otherwise just forward the toggle
                        onToggleAlarm(alarm.id, active);
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onAddAlarm,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add),
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
          Icon(Icons.alarm_off, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Alarms Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create your first alarm',
            style: TextStyle(color: Colors.grey[400]),
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
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(Icons.delete, color: Colors.red[700]),
            const SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
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
  final ValueChanged<bool> onToggle;

  const _AlarmCard({
    Key? key,
    required this.alarm,
    required this.onTap,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = Colors.white;
    final border = Border.all(color: Colors.grey.shade200);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: border,
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 4),
                color: Colors.black.withOpacity(0.04),
              ),
            ],
          ),
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
                    // Top row: Location name | switch
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alarm.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                        // "Slider" to activate/deactivate (adaptive switch)
                        Switch.adaptive(
                          value: alarm.isActive,
                          onChanged: onToggle,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.green.shade600,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                      ],
                    ),

                    const SizedBox(height: 2),

                    // Address
                    Text(
                      alarm.address ?? 'No address set',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),

                    const SizedBox(height: 8),

                    // Bottom meta: radius | sound
                    Row(
                      children: [
                        _MetaChip(
                          icon: Icons.radar,
                          label: '${alarm.radius?.toStringAsFixed(0) ?? '-'} m',
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: Icons.volume_up,
                          label: alarm.soundLevel ?? 'Default',
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
      widget.active ? Colors.green.shade600 : Colors.grey.shade500;

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
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
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
              color: _pinColor.withOpacity(0.12),
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

  const _MetaChip({Key? key, required this.icon, required this.label})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: Colors.grey.shade300);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.fromBorderSide(border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
