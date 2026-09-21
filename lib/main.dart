import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';

import 'features/app_config/presentation/screens/testing_gate_screen.dart';
import 'screens/splash_screen.dart';
import 'services/transaction_service.dart';
import 'services/settings_service.dart';
import 'services/goals_service.dart';
import 'services/app_lock_service.dart';
import 'services/database_service.dart';
import 'widgets/app_lock_wrapper.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  await DatabaseService.initialize();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  // Initialize MobileAds asynchronously in background to avoid blocking cold start
  unawaited(_initMobileAds());
  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _initMobileAds() async {
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Google Mobile Ads initialization failed: $e");
  }
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return provider_pkg.MultiProvider(
      providers: [
        provider_pkg.ChangeNotifierProvider(create: (ctx) => TransactionService()),
        provider_pkg.ChangeNotifierProvider(create: (ctx) => SettingsService()),
        provider_pkg.ChangeNotifierProvider(create: (ctx) => GoalsService()),
        provider_pkg.ChangeNotifierProvider(create: (ctx) => AppLockService()),
      ],
      child: provider_pkg.Consumer<SettingsService>(
        builder: (context, settingsService, child) {
          return MaterialApp(
            title: 'Cash Book',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _getThemeMode(settingsService.theme),
            builder: (context, childWidget) {
              return GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                behavior: HitTestBehavior.translucent,
                child: AppLockWrapper(
                  child: childWidget ?? const SizedBox.shrink(),
                ),
              );
            },
            home: const TestingGateScreen(child: SplashScreen()),
            navigatorObservers: [UnfocusNavigatorObserver()],
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

/// NavigatorObserver that unfocuses primary focus on any route push, pop, or replace,
/// preventing automatic focus restoration when navigating between screens.
class UnfocusNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FocusManager.instance.primaryFocus?.unfocus();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FocusManager.instance.primaryFocus?.unfocus();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    FocusManager.instance.primaryFocus?.unfocus();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
