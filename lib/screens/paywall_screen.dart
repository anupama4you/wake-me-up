import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/tier.dart';
import '../services/tier_service.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

/// Paywall screen showing subscription tier options in tabs
class PaywallScreen extends StatefulWidget {
  final String? highlightedMessage; // Optional message to highlight why upgrade is needed
  final Tier? suggestedTier; // Optional tier to highlight

  const PaywallScreen({
    Key? key,
    this.highlightedMessage,
    this.suggestedTier,
  }) : super(key: key);

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with SingleTickerProviderStateMixin {
  Tier _currentTier = Tier.free;
  late TabController _tabController;
  final _subscriptionService = SubscriptionService();
  final _authService = AuthService();
  Offerings? _offerings;
  bool _isLoadingOfferings = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentTier();
    _loadOfferings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTier() async {
    final tier = await TierService.getCurrentTier();
    setState(() {
      _currentTier = tier;
    });

    // Set initial tab based on suggested tier or next tier
    final initialTier = widget.suggestedTier ?? _getNextTier(tier);
    _tabController.index = initialTier.index;
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await _subscriptionService.getOfferings();
      setState(() {
        _offerings = offerings;
        _isLoadingOfferings = false;
      });
    } catch (e) {
      setState(() {
        _offerings = null; // No offerings available
        _isLoadingOfferings = false;
      });
      debugPrint('⚠️ RevenueCat not available, using mock mode: $e');
    }
  }

  Tier _getNextTier(Tier current) {
    switch (current) {
      case Tier.free:
        return Tier.commuter;
      case Tier.commuter:
        return Tier.pro;
      case Tier.pro:
        return Tier.pro;
    }
  }

  Tier get _selectedTier => Tier.values[_tabController.index];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choose Your Plan',
          style: TextStyle(color: AppTheme.textOnPrimaryColor),
        ),
        backgroundColor: AppTheme.primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(Tier.free.icon),
                  const SizedBox(width: 4),
                  const Text('Free'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(Tier.commuter.icon),
                  const SizedBox(width: 4),
                  const Text('Commuter'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(Tier.pro.icon),
                  const SizedBox(width: 4),
                  const Text('Pro'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Highlighted message if provided
          if (widget.highlightedMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.warningColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.highlightedMessage!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTierTab(Tier.free),
                _buildTierTab(Tier.commuter),
                _buildTierTab(Tier.pro),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierTab(Tier tier) {
    final isCurrentTier = tier == _currentTier;
    final limits = TierLimits.fromTier(tier);
    final benefits = TierBenefit.getBenefits(tier);

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Large tier icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                tier.icon,
                style: const TextStyle(fontSize: 64),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Current tier badge
          if (isCurrentTier)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'CURRENT PLAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (isCurrentTier) const SizedBox(height: 16),

          // Tier name
          Text(
            tier.displayName,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Price - Shows localized currency from RevenueCat when available
          Text(
            _getPriceForTier(tier),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: tier == Tier.free ? AppTheme.accentGreen : AppTheme.primaryColor,
            ),
          ),

          const SizedBox(height: 4),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              tier.description,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),

          // Key limits card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildLimitRow(Icons.route, 'Trip Distance', limits.formattedTripDistance),
                const SizedBox(height: 16),
                _buildLimitRow(Icons.alarm, 'Active Alarms', limits.formattedAlarmLimit),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Benefits section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Features',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...benefits.map((benefit) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppTheme.accentGreen,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              benefit,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Action button
          if (tier != Tier.free)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isCurrentTier ? null : () => _selectPlan(tier),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        isCurrentTier
                            ? 'Current Plan'
                            : 'Select ${tier.displayName} Plan',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Payment integration coming soon!',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

          if (tier == Tier.free && !isCurrentTier)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _selectPlan(tier),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Switch to Free Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Terms and restore
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restore purchases - coming soon')),
                    );
                  },
                  child: const Text('Restore Purchases'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'By subscribing, you agree to our Terms of Service and Privacy Policy',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLimitRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Future<void> _selectPlan(Tier tier) async {
    debugPrint('🔐 _selectPlan called for tier: ${tier.displayName}');

    // Free tier - just downgrade (mock for now)
    if (tier == Tier.free) {
      debugPrint('✅ Free tier selected - no auth required');
      await _mockChangePlan(tier);
      return;
    }

    // Check if user is authenticated FIRST (required for paid tiers)
    debugPrint('🔍 Checking auth status: ${_authService.isSignedIn}');
    if (!_authService.isSignedIn) {
      debugPrint('❌ User NOT signed in - showing auth required dialog');
      final shouldSignIn = await _showAuthRequiredDialog();
      if (shouldSignIn != true) {
        debugPrint('⛔ User cancelled auth - aborting upgrade');
        return;
      }

      // Navigate to auth screen
      if (!mounted) return;
      debugPrint('📱 Navigating to AuthScreen...');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );

      // Check again if user signed in
      debugPrint('🔍 Re-checking auth after navigation: ${_authService.isSignedIn}');
      if (!_authService.isSignedIn) {
        debugPrint('⛔ User still not signed in - aborting upgrade');
        return;
      }
      debugPrint('✅ User signed in - proceeding with upgrade');
    } else {
      debugPrint('✅ User already signed in - proceeding with upgrade');
    }

    // Get the package for this tier
    final package = _getPackageForTier(tier);
    if (package == null) {
      // Fall back to mock upgrade if package not found
      await _mockChangePlan(tier);
      return;
    }

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Purchase the package
      final success = await _subscriptionService.purchasePackage(package);

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      if (success) {
        // Refresh current tier
        await _loadCurrentTier();

        // Show success dialog
        if (!mounted) return;
        _showSuccessDialog(tier);
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show error
      _showError(e.toString());
    }
  }

  /// Mock upgrade for testing (when RevenueCat is not configured)
  /// This is a fallback that only runs if RevenueCat products are unavailable
  Future<void> _mockChangePlan(Tier tier) async {
    debugPrint('⚠️ Using mock upgrade - RevenueCat package not found');

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Mock upgrade (fallback when RevenueCat is not available)
    await TierService.setTier(tier);

    // Wait a bit to simulate payment processing
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Close loading
    Navigator.pop(context);

    // Show success
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Text('${tier == Tier.free ? 'Plan Changed' : 'Test Mode'}'),
          ],
        ),
        content: Text(
          tier == Tier.free
              ? 'You are now on the ${tier.displayName} plan.'
              : 'TEST MODE: You are now on the ${tier.displayName} plan.\n\n'
                'This is a mock upgrade because RevenueCat products are not available. '
                'Check your RevenueCat dashboard configuration.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close paywall
            },
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  Package? _getPackageForTier(Tier tier) {
    if (_offerings == null || _offerings!.current == null) {
      return null;
    }

    final current = _offerings!.current!;
    final productId = _subscriptionService.getProductIdForTier(tier);

    // Try to find package by product ID
    for (final package in current.availablePackages) {
      if (package.storeProduct.identifier == productId) {
        return package;
      }
    }

    return null;
  }

  /// Get localized price string for a tier
  /// Returns the actual RevenueCat price if available, otherwise returns hardcoded price
  String _getPriceForTier(Tier tier) {
    if (tier == Tier.free) {
      return 'Free';
    }

    // Try to get real price from RevenueCat package
    final package = _getPackageForTier(tier);
    if (package != null) {
      // Return localized price string from store (e.g., "₹79.00", "€0.99", "$0.99")
      return package.storeProduct.priceString;
    }

    // Fall back to hardcoded price
    return tier.price;
  }

  Future<bool?> _showAuthRequiredDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 12),
            Text('Sign In Required'),
          ],
        ),
        content: const Text(
          'You need to sign in to purchase a subscription. '
          'This allows you to restore your subscription on other devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Tier tier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Text('Welcome to ${tier.displayName}!'),
          ],
        ),
        content: Text(
          'Your subscription is now active. Enjoy all the premium features!',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close paywall
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 12),
            Text('Purchase Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
