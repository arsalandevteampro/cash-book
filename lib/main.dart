import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/transaction_service.dart';
import 'services/settings_service.dart';
import 'services/goals_service.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => TransactionService()),
        ChangeNotifierProvider(create: (ctx) => SettingsService()),
        ChangeNotifierProvider(create: (ctx) => GoalsService()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settingsService, child) {
          return MaterialApp(
            title: 'Cash Book',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _getThemeMode(settingsService.theme),
            home: const SplashScreen(),
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
