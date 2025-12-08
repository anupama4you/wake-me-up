import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dedicated Help/Instructions screen
class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help & Instructions',
          style: TextStyle(color: AppTheme.textOnPrimaryColor),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: AppTheme.textOnPrimaryColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        children: [
          // Header
          const Icon(
            Icons.help_outline,
            size: 64,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: AppTheme.paddingMedium),
          const Text(
            'How to Use WakeMeUp',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.paddingLarge),

          // Quick Start
          _buildSection(
            title: '🚀 Quick Start',
            items: [
              _HelpItem(
                icon: Icons.location_on,
                title: '1. Set Your Destination',
                description:
                    'Tap the "+" button and search for your destination on the map.',
              ),
              _HelpItem(
                icon: Icons.notifications,
                title: '2. Create an Alarm',
                description:
                    'Set how far before arrival you want to be notified. Choose a radius between 100m and 5km.',
              ),
              _HelpItem(
                icon: Icons.play_arrow,
                title: '3. Activate the Alarm',
                description:
                    'Toggle the alarm ON. WakeMeUp will track your location in the background.',
              ),
              _HelpItem(
                icon: Icons.alarm,
                title: '4. Get Notified',
                description:
                    'When you enter the alarm radius, you\'ll receive a notification with your chosen sound.',
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingLarge),

          // Tips
          _buildSection(
            title: '💡 Pro Tips',
            items: [
              _HelpItem(
                icon: Icons.battery_charging_full,
                title: 'Battery Optimization',
                description:
                    'WakeMeUp uses smart location tracking to preserve battery while ensuring accurate alerts.',
              ),
              _HelpItem(
                icon: Icons.volume_up,
                title: 'Custom Sounds',
                description:
                    'Choose from built-in sounds or upload your own to personalize your alerts.',
              ),
              _HelpItem(
                icon: Icons.edit,
                title: 'Edit Anytime',
                description:
                    'Tap any alarm to edit its location, radius, or sound settings.',
              ),
              _HelpItem(
                icon: Icons.delete,
                title: 'Swipe to Delete',
                description:
                    'Swipe left on any alarm to quickly delete it when you no longer need it.',
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingLarge),

          // Battery & Multiple Alarms
          _buildSection(
            title: '🔋 Multiple Alarms & Battery',
            items: [
              _HelpItem(
                icon: Icons.battery_alert,
                title: 'Multiple Active Alarms',
                description:
                    'You can activate multiple alarms at once. Each active alarm continuously tracks your location in the background.',
              ),
              _HelpItem(
                icon: Icons.battery_charging_full,
                title: 'Battery Impact',
                description:
                    'Multiple active alarms will increase battery usage as the app tracks your location more frequently. Disable alarms when not needed to save battery.',
              ),
              _HelpItem(
                icon: Icons.gps_fixed,
                title: 'Location Updates',
                description:
                    'Active alarms check your GPS location every 10 seconds to ensure accurate notifications.',
              ),
              _HelpItem(
                icon: Icons.workspace_premium,
                title: 'Plan Limits',
                description:
                    'Free: 1 alarm, Commuter: 5 alarms, Pro: Unlimited alarms. Upgrade in Settings to increase your limit.',
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingLarge),

          // Permissions
          _buildSection(
            title: '🔐 Permissions Required',
            items: [
              _HelpItem(
                icon: Icons.location_on,
                title: 'Location (Always)',
                description:
                    'Required to track your location in the background and trigger alarms when you arrive.',
              ),
              _HelpItem(
                icon: Icons.notifications,
                title: 'Notifications',
                description:
                    'Required to alert you when you reach your destination.',
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingLarge),

          // Subscription Info
          _buildSection(
            title: '⭐ Upgrade Your Experience',
            items: [
              _HelpItem(
                icon: Icons.free_breakfast,
                title: 'Free Plan',
                description: '1 active alarm, 20km max distance',
              ),
              _HelpItem(
                icon: Icons.commute,
                title: 'Commuter Plan (\$0.99/mo)',
                description:
                    '5 active alarms, 50km range, custom ringtones, high-accuracy GPS',
              ),
              _HelpItem(
                icon: Icons.star,
                title: 'Pro Plan (\$1.99/mo)',
                description:
                    'Unlimited alarms, unlimited distance, all features, priority support',
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingLarge),

          // Support
          const Card(
            color: AppTheme.cardColor,
            child: Padding(
              padding: EdgeInsets.all(AppTheme.paddingLarge),
              child: Column(
                children: [
                  Icon(
                    Icons.contact_support,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                  SizedBox(height: AppTheme.paddingMedium),
                  Text(
                    'Need More Help?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.paddingSmall),
                  Text(
                    'Visit Settings → About for contact information and support options.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.paddingLarge),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<_HelpItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.paddingMedium),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.icon,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: AppTheme.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: const TextStyle(
                            color: Colors.grey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _HelpItem {
  final IconData icon;
  final String title;
  final String description;

  _HelpItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
