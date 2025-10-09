import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _vibration = true;
  bool _highAccuracy = true;
  bool _progressUpdates = false;
  bool _batteryWarnings = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[600],
      ),
      body: Container(
        color: Colors.grey[50],
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('GENERAL'),
            _buildSettingsCard([
              _buildSettingRow('Default Radius',
                  trailing:
                  Text('500m', style: TextStyle(color: Colors.grey[600]))),
              const Divider(height: 1),
              _buildSettingRow('Default Alarm Sound',
                  trailing:
                  Text('Loud', style: TextStyle(color: Colors.grey[600]))),
              const Divider(height: 1),
              _buildSettingRow(
                'Vibration',
                trailing: Switch(
                  value: _vibration,
                  onChanged: (v) => setState(() => _vibration = v),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle('GPS SETTINGS'),
            _buildSettingsCard([
              _buildSettingRow(
                'High Accuracy Mode',
                subtitle: 'Uses more battery',
                trailing: Switch(
                  value: _highAccuracy,
                  onChanged: (v) => setState(() => _highAccuracy = v),
                ),
              ),
              const Divider(height: 1),
              _buildSettingRow('Update Interval',
                  trailing:
                  Text('30 sec', style: TextStyle(color: Colors.grey[600]))),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle('NOTIFICATIONS'),
            _buildSettingsCard([
              _buildSettingRow(
                'Progress Updates',
                trailing: Switch(
                  value: _progressUpdates,
                  onChanged: (v) => setState(() => _progressUpdates = v),
                ),
              ),
              const Divider(height: 1),
              _buildSettingRow(
                'Battery Warnings',
                trailing: Switch(
                  value: _batteryWarnings,
                  onChanged: (v) => setState(() => _batteryWarnings = v),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle('ABOUT'),
            _buildSettingsCard([
              _buildSettingRow('Version',
                  trailing:
                  Text('1.0.0', style: TextStyle(color: Colors.grey[600]))),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingRow(String title, {String? subtitle, Widget? trailing}) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: trailing,
    );
  }
}
