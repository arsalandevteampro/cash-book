import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final List<Widget> onboardingPages = [
      _buildPage(
        context: context,
        imageAsset: 'assets/images/onboarding1.png',
        title: 'Welcome to Cash Book',
        subtitle: 'The simplest way to track your income and expenses, helping you manage your money with ease.',
      ),
      _buildPage(
        context: context,
        imageAsset: 'assets/images/onboarding2.png',
        title: 'Effortless Tracking',
        subtitle: 'Quickly add transactions and see a clear overview of your financial health at a glance.',
      ),
      _buildPage(
        context: context,
        imageAsset: 'assets/images/onboarding3.png',
        title: 'Gain Financial Insight',
        subtitle: 'Understand your spending habits with visual summaries and take control of your budget.',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: PageView( 
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: onboardingPages,
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(onboardingPages.length, (index) => _buildDot(index, context)),
                    ),
                    const Spacer(),
                    if (_currentPage == onboardingPages.length - 1)
                      ElevatedButton(
                        onPressed: _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Get Started'),
                      )
                    else
                      ElevatedButton(
                         onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Next'),
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text('Skip', style: TextStyle(color: colorScheme.primary)),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required BuildContext context,
    required String imageAsset,
    required String title,
    required String subtitle,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Use icons instead of images
    IconData icon;
    if (imageAsset.contains('onboarding1')) {
      icon = Icons.account_balance_wallet;
    } else if (imageAsset.contains('onboarding2')) {
      icon = Icons.trending_up;
    } else {
      icon = Icons.analytics;
    }
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 100,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 5),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Theme.of(context).colorScheme.primary : Colors.grey,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
