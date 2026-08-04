import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
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
  await DatabaseService.initialize();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  runApp(const ProviderScope(child: MyApp()));
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
              return AppLockWrapper(
                child: childWidget ?? const SizedBox.shrink(),
              );
            },
            home: const TestingGateScreen(child: SplashScreen()),
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
