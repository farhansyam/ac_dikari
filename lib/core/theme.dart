import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF005DA6);
  static const Color primaryContainer = Color(0xFF1F76C9);
  static const Color primaryFixed = Color(0xFFD3E3FF);
  static const Color secondary = Color(0xFF006E08);
  static const Color secondaryContainer = Color(0xFF71FC62);
  static const Color onSecondaryContainer = Color(0xFF007309);
  static const Color surface = Color(0xFFF7F9FC);
  static const Color surfaceContainer = Color(0xFFECEEF1);
  static const Color surfaceContainerLow = Color(0xFFF2F4F7);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHighest = Color(0xFFE0E3E6);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF414755);
  static const Color outlineVariant = Color(0xFFC1C6D7);
  static const Color error = Color(0xFFBA1A1A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        error: error,
      ),
      scaffoldBackgroundColor: surface,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
            color: onSurface, fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.plusJakartaSans(
            color: onSurface, fontWeight: FontWeight.w800),
        displaySmall: GoogleFonts.plusJakartaSans(
            color: onSurface, fontWeight: FontWeight.w800),
        headlineLarge: GoogleFonts.plusJakartaSans(
            color: onSurface, fontWeight: FontWeight.w800),
        headlineMedium: GoogleFonts.plusJakartaSans(
            color: onSurface, fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.plusJakartaSans(
            color: onSurface, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.plusJakartaSans(
            color: onSurface, fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.plusJakartaSans(
            color: onSurface, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.plusJakartaSans(
            color: onSurface, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(
            color: onSurface, fontWeight: FontWeight.normal),
        bodyMedium: GoogleFonts.inter(
            color: onSurface, fontWeight: FontWeight.normal),
        bodySmall: GoogleFonts.inter(
            color: onSurface, fontWeight: FontWeight.normal),
        labelLarge: GoogleFonts.inter(
            color: onSurface, fontWeight: FontWeight.w500),
        labelMedium: GoogleFonts.inter(
            color: onSurface, fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.inter(
            color: onSurface, fontWeight: FontWeight.w500),
      ),
    );
  }
}
