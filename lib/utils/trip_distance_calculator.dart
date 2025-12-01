import 'package:geolocator/geolocator.dart';
import '../models/tier.dart';

/// Utility to calculate trip distance and validate against tier limits
class TripDistanceCalculator {
  /// Calculate distance from current location to target location (in km)
  static double calculateDistanceKm({
    required double currentLat,
    required double currentLon,
    required double targetLat,
    required double targetLon,
  }) {
    final distanceMeters = Geolocator.distanceBetween(
      currentLat,
      currentLon,
      targetLat,
      targetLon,
    );
    return distanceMeters / 1000; // Convert to kilometers
  }

  /// Calculate distance from Position to coordinates (in km)
  static double calculateDistanceFromPosition({
    required Position currentPosition,
    required double targetLat,
    required double targetLon,
  }) {
    return calculateDistanceKm(
      currentLat: currentPosition.latitude,
      currentLon: currentPosition.longitude,
      targetLat: targetLat,
      targetLon: targetLon,
    );
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceKm.round()}km';
    }
  }

  /// Get required tier for a distance
  static Tier getRequiredTier(double distanceKm) {
    if (distanceKm <= 20) return Tier.free;
    if (distanceKm <= 50) return Tier.commuter;
    return Tier.pro;
  }

  /// Check if distance exceeds tier limits
  static bool exceedsTierLimit(double distanceKm, TierLimits limits) {
    if (limits.hasUnlimitedDistance) return false;
    return distanceKm > limits.maxTripDistanceKm;
  }

  /// Get tier upgrade message for distance
  static String getUpgradeMessage({
    required double distanceKm,
    required Tier currentTier,
  }) {
    final requiredTier = getRequiredTier(distanceKm);
    final currentLimits = TierLimits.fromTier(currentTier);

    if (requiredTier == currentTier || currentTier.index > requiredTier.index) {
      return ''; // No upgrade needed
    }

    return 'This location is ${formatDistance(distanceKm)} away. '
        'Your ${currentTier.displayName} plan allows up to ${currentLimits.formattedTripDistance}. '
        'Upgrade to ${requiredTier.displayName} (${requiredTier.price}) for longer trips.';
  }

  /// Get distance category for UI display
  static String getDistanceCategory(double distanceKm) {
    if (distanceKm <= 5) return 'Very close';
    if (distanceKm <= 20) return 'Short trip';
    if (distanceKm <= 50) return 'Medium trip';
    if (distanceKm <= 100) return 'Long trip';
    return 'Very long trip';
  }

  /// Get color indicator based on distance and tier
  static String getDistanceWarningLevel({
    required double distanceKm,
    required TierLimits limits,
  }) {
    if (limits.hasUnlimitedDistance) return 'none';

    final percentOfLimit = (distanceKm / limits.maxTripDistanceKm) * 100;

    if (percentOfLimit > 100) return 'error'; // Exceeds limit
    if (percentOfLimit > 80) return 'warning'; // Close to limit
    return 'ok'; // Within safe range
  }
}
