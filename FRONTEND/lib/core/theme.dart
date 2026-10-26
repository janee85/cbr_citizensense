import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors taken from the official City of Cabadbaran seal:
/// seal blue, rope gold, map greens, and the red stars.
class AppColors {
  static const navy = Color(0xFF0B3C8C);
  static const navyDark = Color(0xFF082B66);
  static const seal = Color(0xFF1590E6);
  static const gold = Color(0xFFF2C94C);
  static const forest = Color(0xFF2E8B3A);
  static const lime = Color(0xFF8DC63F);
  static const star = Color(0xFFE0312B);

  static const canvas = Color(0xFFF2F6FC);
  static const panel = Color(0xFFEAF2FD);
  static const ink = Color(0xFF14233C);
  static const muted = Color(0xFF6B7A90);
  static const line = Color(0xFFE0E8F3);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.forest,
    tertiary: AppColors.gold,
    error: AppColors.star,
    surface: Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: text,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.navy, 1.8),
      errorBorder: border(AppColors.star),
      focusedErrorBorder: border(AppColors.star, 1.8),
      labelStyle: const TextStyle(color: AppColors.muted),
      helperStyle: const TextStyle(color: AppColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.navy,
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
