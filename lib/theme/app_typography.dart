import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Medifit wellness typography scale.
///
/// Uses Plus Jakarta Sans — a modern rounded geometric face that reads cleanly
/// on morph/glass UI in both light and dark modes.
class AppTypography {
  AppTypography._();

  static String get fontFamily => GoogleFonts.plusJakartaSans().fontFamily!;

  /// Full Material 3 [TextTheme] for the given brightness.
  static TextTheme textTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? Colors.white : const Color(0xFF0F1419);
    final secondary =
        isDark ? Colors.white.withOpacity(0.72) : const Color(0xFF4A5568);
    final muted =
        isDark ? Colors.white.withOpacity(0.52) : const Color(0xFF718096);

    TextStyle base({
      double size = 14,
      FontWeight weight = FontWeight.w500,
      double height = 1.4,
      double letterSpacing = 0,
      Color? color,
    }) {
      return GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? primary,
      );
    }

    return TextTheme(
      // Display — rare, large hero numbers
      displayLarge: base(
        size: 40,
        weight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -1.2,
      ),
      displayMedium: base(
        size: 34,
        weight: FontWeight.w800,
        height: 1.18,
        letterSpacing: -1.0,
      ),
      displaySmall: base(
        size: 28,
        weight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.8,
      ),

      // Headlines — screen titles
      headlineLarge: base(
        size: 26,
        weight: FontWeight.w800,
        height: 1.22,
        letterSpacing: -0.7,
      ),
      headlineMedium: base(
        size: 22,
        weight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.5,
      ),
      headlineSmall: base(
        size: 20,
        weight: FontWeight.w700,
        height: 1.28,
        letterSpacing: -0.4,
      ),

      // Titles — cards & sections
      titleLarge: base(
        size: 18,
        weight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
      ),
      titleMedium: base(
        size: 16,
        weight: FontWeight.w700,
        height: 1.35,
        letterSpacing: -0.2,
      ),
      titleSmall: base(
        size: 14,
        weight: FontWeight.w700,
        height: 1.35,
        letterSpacing: -0.1,
      ),

      // Body
      bodyLarge: base(
        size: 16,
        weight: FontWeight.w500,
        height: 1.5,
        color: secondary,
      ),
      bodyMedium: base(
        size: 14,
        weight: FontWeight.w500,
        height: 1.45,
        color: secondary,
      ),
      bodySmall: base(
        size: 12.5,
        weight: FontWeight.w500,
        height: 1.4,
        color: muted,
      ),

      // Labels — chips, tabs, buttons, section headers
      labelLarge: base(
        size: 14,
        weight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0.1,
      ),
      labelMedium: base(
        size: 12,
        weight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0.2,
      ),
      labelSmall: base(
        size: 10.5,
        weight: FontWeight.w800,
        height: 1.2,
        letterSpacing: 0.6,
        color: muted,
      ),
    );
  }

  /// Uppercase section label (e.g. "ACTIVE GOALS", "TODAY'S PLANS").
  static TextStyle sectionLabel(Color color) {
    return GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.9,
      height: 1.2,
      color: color,
    );
  }

  /// Large metric numbers on dashboard cards.
  static TextStyle metricValue({
    required Color color,
    double size = 28,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: 1.1,
      color: color,
    );
  }

  /// Compact caption under metrics / cards.
  static TextStyle caption(Color color) {
    return GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.35,
      letterSpacing: 0.05,
      color: color,
    );
  }
}
