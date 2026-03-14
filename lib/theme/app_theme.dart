import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primarySeedColor = Color(0xFF006B5D); // A modern teal

  static final TextTheme _appTextTheme = TextTheme(
    displayLarge: GoogleFonts.oswald(fontSize: 57, fontWeight: FontWeight.bold),
    displayMedium: GoogleFonts.oswald(fontSize: 45, fontWeight: FontWeight.bold),
    displaySmall: GoogleFonts.oswald(fontSize: 36, fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w600),
    headlineMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w500),
    titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
    titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
    bodyLarge: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.normal),
    bodyMedium: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.normal),
    bodySmall: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.normal),
    labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
    labelMedium: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
    labelSmall: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primarySeedColor,
      brightness: Brightness.light,
    ),
    textTheme: _appTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: _appTextTheme.headlineSmall?.copyWith(color: Colors.black),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: _appTextTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: CircleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.grey.shade100,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primarySeedColor,
      brightness: Brightness.dark,
    ),
    textTheme: _appTextTheme,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      titleTextStyle: _appTextTheme.headlineSmall,
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: _appTextTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: CircleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
    ),
  );
}
