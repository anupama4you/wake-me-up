import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: AppTheme.textOnPrimaryColor),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: AppTheme.textOnPrimaryColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy for WakeMeUp',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().year}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            _buildSection(
              'Introduction',
              'WakeMeUp ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our location-based alarm application.',
            ),

            _buildSection(
              'Information We Collect',
              'Location Data: We collect and process your precise location data to provide alarm functionality. This data is used only to trigger alarms when you reach your specified destinations.\n\nAccount Information: If you create an account, we collect your email address and authentication information.\n\nSubscription Information: We process subscription data through RevenueCat and Apple App Store to manage your plan.',
            ),

            _buildSection(
              'How We Use Your Information',
              'We use your information to:\n\n• Provide location-based alarm services\n• Trigger notifications when you reach your destination\n• Manage your account and subscription\n• Improve our app and services\n• Comply with legal obligations',
            ),

            _buildSection(
              'Data Storage and Security',
              'Your alarm data is stored locally on your device using Hive database. Location tracking only occurs when you have active alarms enabled. We implement industry-standard security measures to protect your data.',
            ),

            _buildSection(
              'Third-Party Services',
              'We use the following third-party services:\n\n• Google Maps: For map display and location search\n• Firebase Authentication: For secure user authentication\n• RevenueCat: For subscription management\n• Apple App Store: For payment processing',
            ),

            _buildSection(
              'Your Rights',
              'You have the right to:\n\n• Access your personal data\n• Request deletion of your data\n• Disable location services at any time\n• Cancel your subscription\n• Export your alarm data',
            ),

            _buildSection(
              'Data Retention',
              'We retain your data only as long as necessary to provide our services. You can delete your account and all associated data at any time through the app settings.',
            ),

            _buildSection(
              'Children\'s Privacy',
              'Our service is not directed to children under 13. We do not knowingly collect information from children under 13. If you believe we have collected such information, please contact us immediately.',
            ),

            _buildSection(
              'Changes to This Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date.',
            ),

            _buildSection(
              'Contact Us',
              'If you have questions about this Privacy Policy, please contact us at:\n\nanupama.dilshan@icloud.com',
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
