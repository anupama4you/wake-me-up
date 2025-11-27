import 'package:shared_preferences/shared_preferences.dart';
import '../models/tier.dart';

/// Service to manage user subscription tier and enforce limits
class TierService {
  static const String _tierKey = 'user_tier';

  /// Get current user tier (default: free)
  static Future<Tier> getCurrentTier() async {
    final prefs = await SharedPreferences.getInstance();
    final tierIndex = prefs.getInt(_tierKey) ?? 0; // 0 = free
    return Tier.values[tierIndex];
  }

  /// Set user tier (for testing/mocking upgrade)
  static Future<void> setTier(Tier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tierKey, tier.index);
  }

  /// Get limits for current tier
  static Future<TierLimits> getTierLimits() async {
    final tier = await getCurrentTier();
    return TierLimits.fromTier(tier);
  }

  /// Check if user can create alarm at specified distance from current location
  /// Returns null if allowed, error message if not allowed
  static Future<String?> canCreateAlarmAtDistance(double distanceKm) async {
    final limits = await getTierLimits();

    if (limits.hasUnlimitedDistance) {
      return null; // Pro tier - unlimited distance
    }

    if (distanceKm > limits.maxTripDistanceKm) {
      final currentTier = await getCurrentTier();
      final requiredTier = _getRequiredTierForDistance(distanceKm);

      return 'This location is ${distanceKm.toStringAsFixed(1)}km away. '
          'Your ${currentTier.displayName} plan allows up to ${limits.maxTripDistanceKm.toInt()}km. '
          'Upgrade to ${requiredTier.displayName} (${requiredTier.price}) for longer trips.';
    }

    return null; // Within limits
  }

  /// Check if user can activate another alarm
  /// Returns null if allowed, error message if not allowed
  static Future<String?> canActivateAlarm(int currentActiveCount) async {
    final limits = await getTierLimits();

    if (limits.hasUnlimitedAlarms) {
      return null; // Pro tier - unlimited alarms
    }

    if (currentActiveCount >= limits.maxActiveAlarms) {
      final currentTier = await getCurrentTier();

      return 'You have reached your limit of ${limits.maxActiveAlarms} active alarm${limits.maxActiveAlarms > 1 ? 's' : ''}. '
          'Upgrade to Commuter (${Tier.commuter.price}) for 5 alarms or Pro (${Tier.pro.price}) for unlimited alarms.';
    }

    return null; // Within limits
  }

  /// Get required tier for a specific distance
  static Tier _getRequiredTierForDistance(double distanceKm) {
    if (distanceKm <= 20) return Tier.free;
    if (distanceKm <= 50) return Tier.commuter;
    return Tier.pro;
  }

  /// Get GPS update interval for current tier
  static Future<int> getGpsUpdateInterval() async {
    final limits = await getTierLimits();
    return limits.gpsUpdateIntervalSeconds;
  }

  /// Check if a feature is available for current tier
  static Future<bool> hasFeature(String feature) async {
    final limits = await getTierLimits();
    return limits.hasFeature(feature);
  }

  /// Get upgrade suggestion based on current usage
  static Future<String?> getUpgradeSuggestion({
    double? plannedTripDistanceKm,
    int? desiredActiveAlarms,
  }) async {
    final currentTier = await getCurrentTier();

    // Already on Pro - no upgrade needed
    if (currentTier == Tier.pro) return null;

    final limits = await getTierLimits();

    // Check distance limit
    if (plannedTripDistanceKm != null && plannedTripDistanceKm > limits.maxTripDistanceKm) {
      final requiredTier = _getRequiredTierForDistance(plannedTripDistanceKm);
      return 'Upgrade to ${requiredTier.displayName} for trips up to ${TierLimits.fromTier(requiredTier).formattedTripDistance}';
    }

    // Check alarm count limit
    if (desiredActiveAlarms != null && !limits.hasUnlimitedAlarms && desiredActiveAlarms > limits.maxActiveAlarms) {
      if (currentTier == Tier.free) {
        return 'Upgrade to Commuter for up to 5 active alarms';
      } else {
        return 'Upgrade to Pro for unlimited alarms';
      }
    }

    return null;
  }

  /// Mock upgrade to tier (for testing - replace with actual payment integration later)
  static Future<bool> mockUpgrade(Tier targetTier) async {
    await setTier(targetTier);
    return true;
  }

  /// Reset to free tier (for testing)
  static Future<void> resetToFree() async {
    await setTier(Tier.free);
  }
}
