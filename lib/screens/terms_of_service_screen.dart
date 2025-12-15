import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms of Service',
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
              'Terms of Service',
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
              'Acceptance of Terms',
              'By downloading, installing, or using WakeMeUp ("the App"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.',
            ),

            _buildSection(
              'Description of Service',
              'WakeMeUp is a location-based alarm application that notifies you when you approach your selected destination. The App uses GPS and geofencing technology to monitor your location and trigger alarms.',
            ),

            _buildSection(
              'User Responsibilities',
              'You are responsible for:\n\n• Maintaining the confidentiality of your account\n• All activities that occur under your account\n• Ensuring your device has location services enabled\n• Using the App in accordance with all applicable laws\n• Not using the App while driving or operating machinery',
            ),

            _buildSection(
              'Location Services',
              'The App requires access to your device\'s location services to function properly. By using the App, you consent to the collection and use of location data as described in our Privacy Policy. You can disable location services at any time, but this will prevent the App from functioning.',
            ),

            _buildSection(
              'Subscription Plans',
              'WakeMeUp offers multiple subscription tiers:\n\n• Free Plan: Limited features with basic functionality\n• Commuter Plan: Enhanced features for regular commuters\n• Pro Plan: Full access to all features\n\nSubscription fees are charged through the Apple App Store. All subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. Cancellations take effect at the end of the current billing period.',
            ),

            _buildSection(
              'Payment and Refunds',
              'All payments are processed through the Apple App Store. Refund policies are governed by Apple\'s terms and conditions. We do not have access to or control over Apple\'s refund process.',
            ),

            _buildSection(
              'Disclaimer of Warranties',
              'THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND. We do not guarantee that:\n\n• The App will be uninterrupted or error-free\n• Location tracking will always be 100% accurate\n• Alarms will trigger at the exact moment you reach your destination\n• The App will work in all geographic locations\n\nYou use the App at your own risk. Always use additional alarm methods for critical appointments.',
            ),

            _buildSection(
              'Limitation of Liability',
              'To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the App. This includes missed alarms, late arrivals, or any other damages arising from the use or inability to use the App.',
            ),

            _buildSection(
              'User Conduct',
              'You agree not to:\n\n• Use the App for any illegal purpose\n• Attempt to hack, reverse engineer, or modify the App\n• Interfere with the App\'s functionality\n• Share your account credentials with others\n• Use the App in a manner that could damage our servers or infrastructure',
            ),

            _buildSection(
              'Intellectual Property',
              'All content, features, and functionality of the App are owned by WakeMeUp and are protected by international copyright, trademark, and other intellectual property laws.',
            ),

            _buildSection(
              'Changes to Service',
              'We reserve the right to modify, suspend, or discontinue any part of the App at any time without notice. We may also update these Terms of Service periodically. Continued use of the App after changes constitutes acceptance of the new terms.',
            ),

            _buildSection(
              'Termination',
              'We may terminate or suspend your access to the App immediately, without prior notice, for any reason, including breach of these Terms. Upon termination, your right to use the App will cease immediately.',
            ),

            _buildSection(
              'Governing Law',
              'These Terms shall be governed by and construed in accordance with applicable laws, without regard to conflict of law provisions.',
            ),

            _buildSection(
              'Contact Information',
              'For questions about these Terms of Service, please contact:\n\nanupama.dilshan@icloud.com',
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
