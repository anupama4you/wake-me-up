import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/tier.dart';

/// Service for handling RevenueCat subscriptions
/// Manages purchasing, restoring, and tracking subscription status
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // Stream controller for subscription updates
  final _subscriptionController = StreamController<Tier>.broadcast();
  Stream<Tier> get subscriptionStream => _subscriptionController.stream;

  Tier _currentTier = Tier.free;
  Tier get currentTier => _currentTier;

  /// Initialize RevenueCat SDK
  /// Call this once at app startup after Firebase Auth
  Future<void> initialize({
    required String apiKey,
    required String? userId,
  }) async {
    try {
      // Configure RevenueCat
      final configuration = PurchasesConfiguration(apiKey);

      if (userId != null) {
        configuration.appUserID = userId;
      }

      await Purchases.configure(configuration);

      // Enable debug logs in development
      await Purchases.setLogLevel(LogLevel.debug);

      // Listen to customer info updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);

      // Get initial subscription status
      await refreshSubscriptionStatus();
    } catch (e) {
      print('Failed to initialize RevenueCat: $e');
      rethrow;
    }
  }

  /// Refresh current subscription status from RevenueCat
  Future<Tier> refreshSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _currentTier = _determineCurrentTier(customerInfo);
      _subscriptionController.add(_currentTier);
      return _currentTier;
    } catch (e) {
      print('Failed to refresh subscription status: $e');
      return Tier.free;
    }
  }

  /// Get available subscription offerings
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('Failed to get offerings: $e');
      return null;
    }
  }

  /// Purchase a subscription package
  Future<bool> purchasePackage(Package package) async {
    try {
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;

      _currentTier = _determineCurrentTier(customerInfo);
      _subscriptionController.add(_currentTier);

      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        print('User cancelled purchase');
        return false;
      } else if (errorCode == PurchasesErrorCode.productAlreadyPurchasedError) {
        print('Product already purchased');
        await refreshSubscriptionStatus();
        return true;
      } else {
        print('Purchase failed: ${e.message}');
        throw 'Purchase failed: ${e.message}';
      }
    } catch (e) {
      print('Unexpected purchase error: $e');
      throw 'Purchase failed: $e';
    }
  }

  /// Restore previous purchases
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _currentTier = _determineCurrentTier(customerInfo);
      _subscriptionController.add(_currentTier);
      return true;
    } catch (e) {
      print('Failed to restore purchases: $e');
      throw 'Failed to restore purchases: $e';
    }
  }

  /// Get subscription management URL (for cancellation, etc.)
  Future<String?> getManagementURL() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.managementURL;
    } catch (e) {
      print('Failed to get management URL: $e');
      return null;
    }
  }

  /// Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get subscription expiration date
  Future<DateTime?> getExpirationDate() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();

      // Check for active entitlements
      if (customerInfo.entitlements.active.isNotEmpty) {
        final activeEntitlement = customerInfo.entitlements.active.values.first;
        return activeEntitlement.expirationDate;
      }

      return null;
    } catch (e) {
      print('Failed to get expiration date: $e');
      return null;
    }
  }

  /// Determine tier from customer info
  Tier _determineCurrentTier(CustomerInfo customerInfo) {
    // Check for active entitlements
    final entitlements = customerInfo.entitlements.active;

    if (entitlements.isEmpty) {
      return Tier.free;
    }

    // Check for Pro tier (highest)
    if (entitlements.containsKey('pro')) {
      return Tier.pro;
    }

    // Check for Commuter tier
    if (entitlements.containsKey('commuter')) {
      return Tier.commuter;
    }

    // Default to free if no recognized entitlement
    return Tier.free;
  }

  /// Handle customer info updates
  void _onCustomerInfoUpdate(CustomerInfo customerInfo) {
    _currentTier = _determineCurrentTier(customerInfo);
    _subscriptionController.add(_currentTier);
  }

  /// Clean up resources
  void dispose() {
    _subscriptionController.close();
  }

  /// Get product identifier for a tier
  String getProductIdForTier(Tier tier) {
    switch (tier) {
      case Tier.commuter:
        return 'wakemeup_commuter_monthly';
      case Tier.pro:
        return 'wakemeup_pro_monthly';
      default:
        return '';
    }
  }

  /// Get entitlement identifier for a tier
  String getEntitlementIdForTier(Tier tier) {
    switch (tier) {
      case Tier.commuter:
        return 'commuter';
      case Tier.pro:
        return 'pro';
      default:
        return '';
    }
  }
}
