import 'dart:math';
import 'package:flutter/material.dart';

// Bubble Particle Model
class BubbleParticle {
  double x; // Percentage (0.0 to 1.0)
  double y; // Percentage (0.0 to 1.0)
  double radius;
  double speed;

  BubbleParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
  });
}

// Custom Wave Painter with Overlapping Sine Wave Paths & Bubbles
class WavePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 representing height
  final double wavePhase; // Phase shift for rippling horizontal motion
  final List<BubbleParticle> bubbles;
  final bool isDark;

  WavePainter({
    required this.progress,
    required this.wavePhase,
    required this.bubbles,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double waterHeight = size.height * progress;
    final double yBase = size.height - waterHeight;

    if (progress <= 0.0) return;

    // Gradient definitions
    final waveGrad1 = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF42A5F5).withOpacity(0.55),
        const Color(0xFF1E88E5).withOpacity(0.85),
      ],
    );

    final waveGrad2 = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF64B5F6).withOpacity(0.7),
        const Color(0xFF1565C0).withOpacity(0.95),
      ],
    );

    final paint1 = Paint()
      ..shader = waveGrad1.createShader(Rect.fromLTWH(0, yBase - 15, size.width, waterHeight + 15))
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..shader = waveGrad2.createShader(Rect.fromLTWH(0, yBase - 15, size.width, waterHeight + 15))
      ..style = PaintingStyle.fill;

    // Draw first wave (Back wave)
    final path1 = Path();
    path1.moveTo(0, yBase);
    for (double x = 0; x <= size.width; x++) {
      // Sine wave formula: amplitude * sin(frequency * x + phase) + yBase
      final double y = 8.0 * sin((2 * pi / size.width) * x + wavePhase) + yBase;
      path1.lineTo(x, y.clamp(0.0, size.height));
    }
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Draw rising bubbles (Under the back wave and above the front wave for layered depth)
    final bubblePaint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.35 : 0.45)
      ..style = PaintingStyle.fill;

    final bubbleGlowPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var bubble in bubbles) {
      // Check if bubble is below the actual water level
      final double bubblePixelY = bubble.y * size.height;
      final double waveYAtBubbleX = 8.0 * sin((2 * pi / size.width) * (bubble.x * size.width) + wavePhase) + yBase;

      if (bubblePixelY > waveYAtBubbleX) {
        final double bubblePixelX = bubble.x * size.width;
        canvas.drawCircle(Offset(bubblePixelX, bubblePixelY), bubble.radius, bubblePaint);
        canvas.drawCircle(Offset(bubblePixelX, bubblePixelY), bubble.radius + 1.5, bubbleGlowPaint);
      }
    }

    // Draw second wave (Front wave, slightly offset phase/amplitude for 3D depth)
    final path2 = Path();
    path2.moveTo(0, yBase);
    for (double x = 0; x <= size.width; x++) {
      final double y = 6.0 * sin((3.5 * pi / size.width) * x - wavePhase + pi / 3.0) + yBase;
      path2.lineTo(x, y.clamp(0.0, size.height));
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return true;
  }
}
