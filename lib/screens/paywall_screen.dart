import 'package:flutter/material.dart';
import '../models/tier.dart';
import '../services/tier_service.dart';
import '../theme/app_theme.dart';

/// Paywall screen showing subscription tier options
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

class _PaywallScreenState extends State<PaywallScreen> {
  Tier _currentTier = Tier.free;
  Tier? _selectedTier;

  @override
  void initState() {
    super.initState();
    _loadCurrentTier();
  }

  Future<void> _loadCurrentTier() async {
    final tier = await TierService.getCurrentTier();
    setState(() {
      _currentTier = tier;
      _selectedTier = widget.suggestedTier ?? _getNextTier(tier);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Plan'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Highlighted message if provided
            if (widget.highlightedMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.orange.withOpacity(0.1),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      widget.highlightedMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 32),
            ],

            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Choose Your Plan',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Unlock longer trips and more alarms',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Tier cards
            _buildTierCard(Tier.free),
            const SizedBox(height: 16),
            _buildTierCard(Tier.commuter),
            const SizedBox(height: 16),
            _buildTierCard(Tier.pro),

            const SizedBox(height: 32),

            // Action buttons
            if (_selectedTier != null && _selectedTier != Tier.free) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _mockUpgrade(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Upgrade to ${_selectedTier!.displayName} - ${_selectedTier!.price}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment integration coming soon!',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _mockUpgrade(),
                      child: const Text('Try it now (mock upgrade for testing)'),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Restore purchases / Terms
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  TextButton(
                    onPressed: () {
                      // TODO: Implement restore purchases
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
      ),
    );
  }

  Widget _buildTierCard(Tier tier) {
    final isCurrentTier = tier == _currentTier;
    final isSelected = tier == _selectedTier;
    final limits = TierLimits.fromTier(tier);
    final benefits = TierBenefit.getBenefits(tier);

    return GestureDetector(
      onTap: () {
        if (tier != Tier.free) {
          setState(() => _selectedTier = tier);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : isCurrentTier
                    ? Colors.green
                    : Colors.grey.withOpacity(0.3),
            width: isSelected || isCurrentTier ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with tier name and current badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      tier.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tier.displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (isCurrentTier)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'CURRENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Price
            Text(
              tier.price,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: tier == Tier.free ? Colors.green : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tier.description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Key limits
            _buildLimitRow(Icons.route, 'Trip Distance', limits.formattedTripDistance),
            const SizedBox(height: 8),
            _buildLimitRow(Icons.alarm, 'Active Alarms', limits.formattedAlarmLimit),
            const SizedBox(height: 8),
            _buildLimitRow(Icons.update, 'GPS Updates', '${limits.gpsUpdateIntervalSeconds}s'),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Benefits list
            ...benefits.map((benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benefit,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
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

  Future<void> _mockUpgrade() async {
    if (_selectedTier == null || _selectedTier == Tier.free) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Mock upgrade (replace with actual payment later)
    await TierService.mockUpgrade(_selectedTier!);

    // Wait a bit to simulate payment processing
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Close loading
    Navigator.pop(context);

    // Show success
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            const Text('Upgrade Successful!'),
          ],
        ),
        content: Text(
          'You are now on the ${_selectedTier!.displayName} plan!\n\n'
          'Note: This is a mock upgrade for testing. Real payment integration coming soon.',
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
}
