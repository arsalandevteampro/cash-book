import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'home_screen.dart';
import 'onboarding_screen.dart';
import '../services/transaction_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_loading_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.05;
  String _statusMessage = 'Starting Cash Book...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final transactionService = Provider.of<TransactionService>(
        context,
        listen: false,
      );
      final settingsService = Provider.of<SettingsService>(
        context,
        listen: false,
      );

      // 1. Initial boot tick (15%)
      if (mounted) {
        setState(() {
          _progress = 0.15;
          _statusMessage = 'Connecting database...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));

      // 2. Initialize transaction service (50%)
      await transactionService.initialize();
      if (mounted) {
        setState(() {
          _progress = 0.50;
          _statusMessage = 'Loading transaction ledger...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. Initialize settings service (80%)
      await settingsService.initialize();
      if (mounted) {
        setState(() {
          _progress = 0.80;
          _statusMessage = 'Synchronizing preferences...';
        });
      }

      // 4. Check onboarding status (95%)
      final prefs = await SharedPreferences.getInstance();
      final bool onboardingComplete =
          prefs.getBool('onboarding_complete') ?? false;

      // 5. Final 100% complete
      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusMessage = 'Ready!';
        });
      }
      await Future.delayed(const Duration(milliseconds: 250)); // Brief hold at 100%

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, animation, secondaryAnimation) =>
                onboardingComplete ? const HomeScreen() : const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      }
    } catch (e) {
      // Handle initialization errors gracefully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize app: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLoadingView(
      progress: _progress,
      message: _statusMessage,
    );
  }
}
