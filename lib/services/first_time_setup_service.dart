import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service to track first-time setup and onboarding status
class FirstTimeSetupService {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _permissionsGrantedKey = 'permissions_granted';
  static const String _firstAlarmCreatedKey = 'first_alarm_created';
  static const String _tutorialShownKey = 'tutorial_shown';

  /// Check if user has completed onboarding
  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_onboardingCompleteKey) ?? false;
    debugPrint('📚 Onboarding completed: $completed');
    return completed;
  }

  /// Mark onboarding as complete
  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
    debugPrint('✅ Onboarding marked as complete');
  }

  /// Check if user has granted permissions
  static Future<bool> hasGrantedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionsGrantedKey) ?? false;
  }

  /// Mark permissions as granted
  static Future<void> markPermissionsGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsGrantedKey, true);
    debugPrint('✅ Permissions marked as granted');
  }

  /// Check if user has created their first alarm
  static Future<bool> hasCreatedFirstAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstAlarmCreatedKey) ?? false;
  }

  /// Mark first alarm as created
  static Future<void> markFirstAlarmCreated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstAlarmCreatedKey, true);
    debugPrint('✅ First alarm marked as created');
  }

  /// Check if tutorial has been shown
  static Future<bool> hasTutorialBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialShownKey) ?? false;
  }

  /// Mark tutorial as shown
  static Future<void> markTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialShownKey, true);
    debugPrint('✅ Tutorial marked as shown');
  }

  /// Check if this is a first-time user (needs full onboarding)
  static Future<bool> isFirstTimeUser() async {
    final onboardingComplete = await hasCompletedOnboarding();
    return !onboardingComplete;
  }

  /// Reset all onboarding flags (for testing)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, false);
    await prefs.setBool(_permissionsGrantedKey, false);
    await prefs.setBool(_firstAlarmCreatedKey, false);
    await prefs.setBool(_tutorialShownKey, false);
    debugPrint('🔄 Onboarding reset - user will see onboarding again');
  }

  /// Get onboarding status summary (for debugging)
  static Future<Map<String, bool>> getOnboardingStatus() async {
    return {
      'onboarding_complete': await hasCompletedOnboarding(),
      'permissions_granted': await hasGrantedPermissions(),
      'first_alarm_created': await hasCreatedFirstAlarm(),
      'tutorial_shown': await hasTutorialBeenShown(),
    };
  }
}
