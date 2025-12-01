import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tier.dart';
import 'subscription_service.dart';

/// Service to manage user subscription tier and enforce limits
class TierService {
  static const String _tierKey = 'user_tier';
  static final _subscriptionService = SubscriptionService();

  /// Get current user tier from RevenueCat (with fallback to cached value)
  static Future<Tier> getCurrentTier() async {
    try {
      // Try to get tier from RevenueCat (source of truth)
      final tier = await _subscriptionService.refreshSubscriptionStatus();
      debugPrint('🎫 Current tier from RevenueCat: ${tier.name}');

      // Cache it locally for offline access
      await _cacheTier(tier);
      return tier;
    } catch (e) {
      // Fallback to cached tier if RevenueCat is unavailable
      debugPrint('⚠️ Failed to get tier from RevenueCat, using cached value: $e');
      return await _getCachedTier();
    }
  }

  /// Get cached tier (for offline access)
  static Future<Tier> _getCachedTier() async {
    final prefs = await SharedPreferences.getInstance();
    final tierIndex = prefs.getInt(_tierKey) ?? 0; // 0 = free
    final tier = Tier.values[tierIndex];
    debugPrint('🎫 Cached tier: ${tier.name} (index: $tierIndex)');
    return tier;
  }

  /// Cache tier locally
  static Future<void> _cacheTier(Tier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tierKey, tier.index);
  }

  /// Set user tier (DEPRECATED - use SubscriptionService.purchasePackage instead)
  /// Kept for backwards compatibility and testing
  @Deprecated('Use SubscriptionService.purchasePackage for real purchases')
  static Future<void> setTier(Tier tier) async {
    await _cacheTier(tier);
  }

  /// Get limits for current tier
  static Future<TierLimits> getTierLimits() async {
    final tier = await getCurrentTier();
    return TierLimits.fromTier(tier);
  }

  /// Check if user can create alarm at specified distance from current location
  /// Returns null if allowed, error message if not allowed
  static Future<String?> canCreateAlarmAtDistance(double distanceKm) async {
    final currentTier = await getCurrentTier();
    final limits = await getTierLimits();

    debugPrint('🎫 Checking distance limit: ${distanceKm.toStringAsFixed(1)}km');
    debugPrint('   Current tier: ${currentTier.displayName}');
    debugPrint('   Max distance: ${limits.formattedTripDistance}');

    if (limits.hasUnlimitedDistance) {
      debugPrint('   ✅ Unlimited distance (Pro tier)');
      return null; // Pro tier - unlimited distance
    }

    if (distanceKm > limits.maxTripDistanceKm) {
      final requiredTier = _getRequiredTierForDistance(distanceKm);

      debugPrint('   ❌ Distance exceeds limit! Required: ${requiredTier.displayName}');

      return 'This location is ${distanceKm.toStringAsFixed(1)}km away. '
          'Your ${currentTier.displayName} plan allows up to ${limits.formattedTripDistance}. '
          'Upgrade to ${requiredTier.displayName} (${requiredTier.price}) for longer trips.';
    }

    debugPrint('   ✅ Distance within limit');
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
