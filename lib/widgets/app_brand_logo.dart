import 'package:flutter/material.dart';

/// Brand wordmark (`logo_2.png`): wide aspect ratio, white text, transparent bg.
/// Renders on a dark plate so the mark stays readable in light and dark themes.
class AppBrandLogo extends StatelessWidget {
  /// Overall height of the logo plate (width is derived from aspect ratio).
  final double height;

  /// Max width cap so very wide logos don't overflow small screens.
  final double? maxWidth;

  /// Corner radius of the dark plate behind the logo.
  final double borderRadius;

  /// Extra padding inside the plate around the image.
  final EdgeInsetsGeometry padding;

  /// Show a soft brand glow / border (splash, hero).
  final bool elevated;

  const AppBrandLogo({
    super.key,
    this.height = 72,
    this.maxWidth,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.elevated = false,
  });

  /// Compact mark for app bars / signup headers.
  const AppBrandLogo.compact({super.key})
      : height = 52,
        maxWidth = 200,
        borderRadius = 14,
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        elevated = false;

  /// Large hero mark for splash.
  const AppBrandLogo.hero({super.key})
      : height = 108,
        maxWidth = 360,
        borderRadius = 24,
        padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        elevated = true;

  static const String assetPath = 'assets/logo_2.png';

  /// Intrinsic wordmark ratio ~ 2.6:1 (width:height) for logo_2.
  static const double aspectRatio = 2.6;

  @override
  Widget build(BuildContext context) {
    final plateHeight = height;
    final plateWidth = (plateHeight * aspectRatio).clamp(
      plateHeight,
      maxWidth ?? double.infinity,
    );

    return Container(
      width: plateWidth,
      height: plateHeight,
      padding: padding,
      decoration: BoxDecoration(
        // Dark plate so white logo text is always visible
        color: const Color(0xFF0B0B10),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: elevated
              ? Colors.white.withOpacity(0.10)
              : Colors.white.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.18),
                  blurRadius: 22,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF16161C),
            const Color(0xFF0B0B10),
            const Color(0xFF121218),
          ],
        ),
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const Center(
          child: Text(
            'Medifit',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}
