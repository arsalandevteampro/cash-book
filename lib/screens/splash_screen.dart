import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'home_screen.dart';
import 'onboarding_screen.dart';
import '../services/transaction_service.dart';
import '../services/settings_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Wait a bit to show splash screen
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // Initialize services after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final transactionService = Provider.of<TransactionService>(context, listen: false);
          final settingsService = Provider.of<SettingsService>(context, listen: false);

          // Initialize services
          await Future.wait([
            transactionService.initialize(),
            settingsService.initialize(),
          ]);

          // Check onboarding status
          final prefs = await SharedPreferences.getInstance();
          final bool onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

          if (mounted) {
            if (onboardingComplete) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              );
            }
          }
        });
      }
    } catch (e) {
      // Handle initialization errors
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
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
