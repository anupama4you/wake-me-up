import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage app settings/preferences
class SettingsService {
  static SharedPreferences? _prefs;

  // Settings keys
  static const String _keyDefaultRadius = 'default_radius';
  static const String _keyDefaultSoundLevel = 'default_sound_level';
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keyHighAccuracy = 'high_accuracy';
  static const String _keyUpdateInterval = 'update_interval';

  /// Initialize the settings service
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if settings is initialized
  static bool get isInitialized => _prefs != null;

  // Default Radius (in meters)
  static double get defaultRadius => _prefs?.getDouble(_keyDefaultRadius) ?? 500.0;
  static Future<void> setDefaultRadius(double value) async {
    await _prefs?.setDouble(_keyDefaultRadius, value);
  }

  // Default Sound Level
  static String get defaultSoundLevel => _prefs?.getString(_keyDefaultSoundLevel) ?? 'Loud';
  static Future<void> setDefaultSoundLevel(String value) async {
    await _prefs?.setString(_keyDefaultSoundLevel, value);
  }

  // Vibration Enabled
  static bool get vibrationEnabled => _prefs?.getBool(_keyVibrationEnabled) ?? true;
  static Future<void> setVibrationEnabled(bool value) async {
    await _prefs?.setBool(_keyVibrationEnabled, value);
  }

  // High Accuracy Mode
  static bool get highAccuracy => _prefs?.getBool(_keyHighAccuracy) ?? true;
  static Future<void> setHighAccuracy(bool value) async {
    await _prefs?.setBool(_keyHighAccuracy, value);
  }

  // Update Interval (in seconds)
  static int get updateInterval => _prefs?.getInt(_keyUpdateInterval) ?? 10;
  static Future<void> setUpdateInterval(int value) async {
    await _prefs?.setInt(_keyUpdateInterval, value);
  }

  /// Get accuracy in meters based on high accuracy setting
  static int get accuracyInMeters => highAccuracy ? 100 : 500;

  /// Get update interval in milliseconds
  static int get updateIntervalInMillis => updateInterval * 1000;
}
