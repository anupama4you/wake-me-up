import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';

/// Health issue severity levels
enum HealthIssueSeverity {
  critical, // Prevents alarms from working
  warning,  // May cause issues
  info,     // Informational
}

/// Represents a health check issue
class HealthIssue {
  final String title;
  final String description;
  final HealthIssueSeverity severity;
  final VoidCallback? fixAction;
  final String? fixButtonLabel;

  const HealthIssue({
    required this.title,
    required this.description,
    required this.severity,
    this.fixAction,
    this.fixButtonLabel,
  });

  Color get color {
    switch (severity) {
      case HealthIssueSeverity.critical:
        return Colors.red;
      case HealthIssueSeverity.warning:
        return Colors.orange;
      case HealthIssueSeverity.info:
        return Colors.blue;
    }
  }

  IconData get icon {
    switch (severity) {
      case HealthIssueSeverity.critical:
        return Icons.error;
      case HealthIssueSeverity.warning:
        return Icons.warning;
      case HealthIssueSeverity.info:
        return Icons.info;
    }
  }
}

/// Monitor app health and detect issues that may prevent alarms from working
class AppHealthMonitor {
  /// Get complete health status
  static Future<Map<String, dynamic>> getHealthStatus() async {
    final status = <String, dynamic>{};

    // 1. Check location services
    try {
      status['location_services_enabled'] = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      status['location_services_enabled'] = false;
      debugPrint('Error checking location services: $e');
    }

    // 2. Check location permission
    try {
      final permission = await Geolocator.checkPermission();
      status['location_permission'] = permission;
      status['location_permission_granted'] =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      status['location_permission'] = LocationPermission.denied;
      status['location_permission_granted'] = false;
      debugPrint('Error checking location permission: $e');
    }

    // 3. Check background location permission
    try {
      status['background_location_granted'] = await LocationService.hasBackgroundPermission();
    } catch (e) {
      status['background_location_granted'] = false;
      debugPrint('Error checking background location: $e');
    }

    // 4. Check notification permission (Android 13+, iOS always)
    try {
      final notificationStatus = await Permission.notification.status;
      status['notification_permission'] = notificationStatus.isGranted;
    } catch (e) {
      // Fallback for older Android versions
      status['notification_permission'] = true;
      debugPrint('Error checking notification permission: $e');
    }

    // 5. Check battery optimization (Android only)
    if (Platform.isAndroid) {
      try {
        final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        status['battery_optimization_disabled'] = batteryStatus.isGranted;
      } catch (e) {
        status['battery_optimization_disabled'] = false;
        debugPrint('Error checking battery optimization: $e');
      }
    } else {
      status['battery_optimization_disabled'] = true; // Not applicable on iOS
    }

    // 6. Platform information
    status['platform'] = Platform.operatingSystem;
    status['is_android'] = Platform.isAndroid;
    status['is_ios'] = Platform.isIOS;

    return status;
  }

  /// Get list of health issues that need attention
  static Future<List<HealthIssue>> getHealthIssues() async {
    final issues = <HealthIssue>[];
    final health = await getHealthStatus();

    // 1. Location services disabled (CRITICAL)
    if (health['location_services_enabled'] == false) {
      issues.add(HealthIssue(
        title: 'Location Services Disabled',
        description: 'Location services must be enabled in system settings for alarms to work.',
        severity: HealthIssueSeverity.critical,
        fixAction: () async {
          await Geolocator.openLocationSettings();
        },
        fixButtonLabel: 'Open Settings',
      ));
    }

    // 2. Location permission not granted (CRITICAL)
    if (health['location_permission_granted'] == false) {
      issues.add(HealthIssue(
        title: 'Location Permission Required',
        description: 'WakeMeUp needs location permission to trigger alarms when you arrive.',
        severity: HealthIssueSeverity.critical,
        fixAction: () async {
          await LocationService.requestPermission();
        },
        fixButtonLabel: 'Grant Permission',
      ));
    }

    // 3. Background location not granted (CRITICAL)
    if (health['background_location_granted'] == false &&
        health['location_permission_granted'] == true) {
      issues.add(HealthIssue(
        title: 'Background Location Required',
        description: Platform.isAndroid
            ? 'Alarms won\'t work when app is closed without "Allow all the time" permission.'
            : 'Alarms won\'t work when app is closed without "Always" permission.',
        severity: HealthIssueSeverity.critical,
        fixAction: () async {
          if (Platform.isAndroid) {
            await Permission.locationAlways.request();
          } else {
            await LocationService.openLocationSettings();
          }
        },
        fixButtonLabel: 'Grant Permission',
      ));
    }

    // 4. Notifications disabled (WARNING)
    if (health['notification_permission'] == false) {
      issues.add(HealthIssue(
        title: 'Notifications Disabled',
        description: 'You won\'t see or hear alarm notifications without notification permission.',
        severity: HealthIssueSeverity.warning,
        fixAction: () async {
          await Permission.notification.request();
        },
        fixButtonLabel: 'Enable Notifications',
      ));
    }

    // 5. Battery optimization enabled (CRITICAL for Android)
    if (Platform.isAndroid && health['battery_optimization_disabled'] == false) {
      issues.add(HealthIssue(
        title: 'Battery Optimization Detected',
        description: 'Android may kill this app in the background, preventing alarms from working. '
            'Please disable battery optimization for WakeMeUp.',
        severity: HealthIssueSeverity.critical,
        fixAction: () async {
          await Permission.ignoreBatteryOptimizations.request();
        },
        fixButtonLabel: 'Disable Optimization',
      ));
    }

    return issues;
  }

  /// Get only critical issues (prevents alarms from working)
  static Future<List<HealthIssue>> getCriticalIssues() async {
    final allIssues = await getHealthIssues();
    return allIssues.where((issue) =>
      issue.severity == HealthIssueSeverity.critical
    ).toList();
  }

  /// Check if app is healthy (no critical issues)
  static Future<bool> isHealthy() async {
    final criticalIssues = await getCriticalIssues();
    return criticalIssues.isEmpty;
  }

  /// Get health summary for display
  static Future<String> getHealthSummary() async {
    final issues = await getHealthIssues();

    if (issues.isEmpty) {
      return '✅ All systems operational';
    }

    final critical = issues.where((i) => i.severity == HealthIssueSeverity.critical).length;
    final warnings = issues.where((i) => i.severity == HealthIssueSeverity.warning).length;

    if (critical > 0) {
      return '🔴 $critical critical issue${critical > 1 ? 's' : ''} detected';
    } else if (warnings > 0) {
      return '⚠️ $warnings warning${warnings > 1 ? 's' : ''} detected';
    } else {
      return '✅ All systems operational';
    }
  }

  /// Show health check dialog
  static Future<void> showHealthCheckDialog(BuildContext context) async {
    final issues = await getHealthIssues();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              issues.isEmpty ? Icons.check_circle : Icons.health_and_safety,
              color: issues.isEmpty ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            const Text('App Health Check'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (issues.isEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'All systems operational!\n\nYour alarms are configured correctly and will work reliably.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'The following issues may prevent alarms from working:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...issues.map((issue) => _buildIssueCard(context, issue)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build issue card widget
  static Widget _buildIssueCard(BuildContext context, HealthIssue issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: issue.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: issue.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(issue.icon, color: issue.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  issue.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: issue.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            issue.description,
            style: const TextStyle(fontSize: 13),
          ),
          if (issue.fixAction != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  issue.fixAction?.call();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: issue.color,
                  foregroundColor: Colors.white,
                ),
                child: Text(issue.fixButtonLabel ?? 'Fix'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
