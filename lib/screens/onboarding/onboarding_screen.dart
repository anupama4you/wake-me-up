import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/first_time_setup_service.dart';
import '../paywall_screen.dart';
import 'permission_request_screen.dart';

/// Onboarding carousel screen shown to first-time users
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.airline_seat_recline_extra,
      title: 'Never Miss Your Stop',
      description:
          'Traveling by bus or train? Fall asleep worry-free!\n\nWe\'ll wake you up when you reach your destination.',
      color: AppTheme.accentGreen,
    ),
    OnboardingPage(
      icon: Icons.location_on_rounded,
      title: 'Location-Based Alarms',
      description:
          'Set alarms for places, not times.\n\nWe\'ll alert you when you arrive at your chosen location!',
      color: AppTheme.primaryColor,
    ),
    OnboardingPage(
      icon: Icons.phone_android_rounded,
      title: 'Works in Background',
      description:
          'Our smart tracking works even when your phone is locked.\n\nLow battery usage with intelligent tracking.',
      color: Colors.orange,
    ),
    OnboardingPage(
      icon: Icons.workspace_premium,
      title: 'Choose Your Plan',
      description:
          'Start free with 1 alarm and 20km trips.\n\nUpgrade anytime for unlimited alarms and longer journeys!',
      color: Colors.amber.shade700,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _navigateToNext() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last page - show plans or continue
      await _handleGetStarted();
    }
  }

  Future<void> _handleGetStarted() async {
    // Mark onboarding as seen
    await FirstTimeSetupService.markOnboardingComplete();

    if (!mounted) return;

    // Navigate to permission request screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const PermissionRequestScreen(),
      ),
    );
  }

  void _skipOnboarding() async {
    await FirstTimeSetupService.markOnboardingComplete();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const PermissionRequestScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skipOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPageContent(_pages[index]);
                },
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildPageIndicator(index == _currentPage),
                ),
              ),
            ),

            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon/Illustration
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: page.color,
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryColor,
              height: 1.6,
            ),
          ),

          // Special content for last page (plan comparison)
          if (_currentPage == _pages.length - 1) ...[
            const SizedBox(height: 32),
            _buildPlanHighlights(),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanHighlights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          _buildPlanFeature('Free', '1 alarm, 20km trips'),
          const Divider(height: 24),
          _buildPlanFeature('Commuter', '5 alarms, 50km trips'),
          const Divider(height: 24),
          _buildPlanFeature('Pro', 'Unlimited everything', isPro: true),
        ],
      ),
    );
  }

  Widget _buildPlanFeature(String name, String features, {bool isPro = false}) {
    return Row(
      children: [
        Icon(
          isPro ? Icons.star : Icons.check_circle,
          color: isPro ? Colors.amber.shade700 : AppTheme.accentGreen,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPro ? Colors.amber.shade700 : AppTheme.textPrimaryColor,
                ),
              ),
              Text(
                features,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Data model for onboarding page
class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
