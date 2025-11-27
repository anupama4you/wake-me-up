/// Subscription tier levels
enum Tier {
  free,
  commuter,
  pro,
}

/// Extension to get tier display names and descriptions
extension TierExtension on Tier {
  String get displayName {
    switch (this) {
      case Tier.free:
        return 'Free';
      case Tier.commuter:
        return 'Commuter';
      case Tier.pro:
        return 'Pro';
    }
  }

  String get description {
    switch (this) {
      case Tier.free:
        return 'Perfect for short trips';
      case Tier.commuter:
        return 'For daily commuters';
      case Tier.pro:
        return 'Unlimited everything';
    }
  }

  String get price {
    switch (this) {
      case Tier.free:
        return 'Free';
      case Tier.commuter:
        return '\$4.99/month';
      case Tier.pro:
        return '\$9.99/month';
    }
  }

  String get icon {
    switch (this) {
      case Tier.free:
        return '🆓';
      case Tier.commuter:
        return '🚆';
      case Tier.pro:
        return '⭐';
    }
  }
}

/// Tier limits and features
class TierLimits {
  final double maxTripDistanceKm; // Max distance from current location (in km)
  final int maxActiveAlarms; // Max number of active alarms (0 = unlimited)
  final int gpsUpdateIntervalSeconds; // GPS polling frequency
  final Set<String> features; // Enabled features

  const TierLimits({
    required this.maxTripDistanceKm,
    required this.maxActiveAlarms,
    required this.gpsUpdateIntervalSeconds,
    required this.features,
  });

  /// Get tier limits based on tier level
  factory TierLimits.fromTier(Tier tier) {
    switch (tier) {
      case Tier.free:
        return const TierLimits(
          maxTripDistanceKm: 20, // 20km max trip distance
          maxActiveAlarms: 1, // 1 active alarm
          gpsUpdateIntervalSeconds: 30, // Update every 30 seconds
          features: {
            'basic_ringtones',
            'standard_accuracy',
          },
        );

      case Tier.commuter:
        return const TierLimits(
          maxTripDistanceKm: 50, // 50km max trip distance
          maxActiveAlarms: 5, // 5 active alarms
          gpsUpdateIntervalSeconds: 15, // Update every 15 seconds
          features: {
            'basic_ringtones',
            'custom_ringtones',
            'high_accuracy',
            'higher_update_frequency',
          },
        );

      case Tier.pro:
        return const TierLimits(
          maxTripDistanceKm: double.infinity, // Unlimited trip distance
          maxActiveAlarms: 0, // Unlimited alarms (0 = unlimited)
          gpsUpdateIntervalSeconds: 15, // Update every 15 seconds
          features: {
            'basic_ringtones',
            'custom_ringtones',
            'high_accuracy',
            'higher_update_frequency',
            'multi_leg_routes',
            'cloud_backup',
            'cloud_sync',
            'early_access',
            'priority_support',
          },
        );
    }
  }

  /// Check if unlimited alarms are allowed
  bool get hasUnlimitedAlarms => maxActiveAlarms == 0;

  /// Check if unlimited trip distance is allowed
  bool get hasUnlimitedDistance => maxTripDistanceKm.isInfinite;

  /// Check if a specific feature is enabled
  bool hasFeature(String feature) => features.contains(feature);

  /// Format trip distance for display
  String get formattedTripDistance {
    if (hasUnlimitedDistance) return 'Unlimited';
    return '${maxTripDistanceKm.toInt()}km';
  }

  /// Format active alarms limit for display
  String get formattedAlarmLimit {
    if (hasUnlimitedAlarms) return 'Unlimited';
    return maxActiveAlarms.toString();
  }
}

/// Tier benefits for display in paywall
class TierBenefit {
  final Tier tier;
  final List<String> benefits;

  const TierBenefit({
    required this.tier,
    required this.benefits,
  });

  static const allBenefits = [
    TierBenefit(
      tier: Tier.free,
      benefits: [
        'Up to 20km trip distance',
        '1 active alarm',
        'Basic ringtones',
        'Standard location updates (30s)',
      ],
    ),
    TierBenefit(
      tier: Tier.commuter,
      benefits: [
        'Up to 50km trip distance',
        '5 active alarms',
        'Custom ringtones',
        'Higher location update frequency (15s)',
        'High accuracy GPS',
      ],
    ),
    TierBenefit(
      tier: Tier.pro,
      benefits: [
        'Unlimited trip distance',
        'Unlimited active alarms',
        'All Commuter features',
        'Multi-leg routes (coming soon)',
        'Cloud backup & sync (coming soon)',
        'Early access to new features',
        'Priority support',
      ],
    ),
  ];

  static List<String> getBenefits(Tier tier) {
    return allBenefits.firstWhere((b) => b.tier == tier).benefits;
  }
}
