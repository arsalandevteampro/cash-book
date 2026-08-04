import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Professional Green/Teal Neomorphic palette
  static const Color primarySeedColor = Color(0xFF006D5B); // Deep Teal
  static const Color accentColor = Color(0xFF00D084); // Emerald accent
  static const Color backgroundColor = Color(0xFFF8FAFC); // Off-white
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFFF5F5F); // Rose-red
  static const Color successColor = Color(0xFF10B981);

  static final TextTheme _appTextTheme = TextTheme(
    displayLarge: GoogleFonts.outfit(
      fontSize: 48,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
    ),
    displayMedium: GoogleFonts.outfit(
      fontSize: 38,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    displaySmall: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold),
    headlineMedium: GoogleFonts.outfit(
      fontSize: 22,
      fontWeight: FontWeight.bold,
    ),
    headlineSmall: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
    titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
    titleMedium: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
    titleSmall: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
    bodyLarge: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
    bodyMedium: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
    bodySmall: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500),
    labelLarge: GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    ),
    labelMedium: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
    labelSmall: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primarySeedColor,
      primary: primarySeedColor,
      secondary: accentColor,
      surface: surfaceColor,
      error: errorColor,
      onPrimary: Colors.white,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: backgroundColor,
    textTheme: _appTextTheme.apply(
      displayColor: const Color(0xFF1F2937),
      bodyColor: const Color(0xFF1F2937),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: const Color(0xFF1A1C1E),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: _appTextTheme.headlineSmall?.copyWith(
        color: const Color(0xFF1A1C1E),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(color: Colors.grey.withOpacity(0.08), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primarySeedColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: _appTextTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
      backgroundColor: primarySeedColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: const Color(0xFF006D5B),
      suffixIconColor: const Color(0xFF006D5B),
      labelStyle: const TextStyle(
        color: Color(0xFF475569),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF006D5B),
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.normal,
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF006D5B), width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF5F5F), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF5F5F), width: 2.0),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primarySeedColor,
      primary: primarySeedColor,
      secondary: accentColor,
      surface: const Color(0xFF1E1E1E),
      onSurface: Colors.white,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    textTheme: _appTextTheme.apply(
      displayColor: Colors.white,
      bodyColor: Colors.white.withValues(alpha: 0.9),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: _appTextTheme.headlineSmall?.copyWith(
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primarySeedColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: _appTextTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
      backgroundColor: primarySeedColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: const Color(0xFF00D084),
      suffixIconColor: const Color(0xFF00D084),
      labelStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF00D084),
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontWeight: FontWeight.normal,
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF00D084), width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF5F5F), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF5F5F), width: 2.0),
      ),
    ),
  );
}
