import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConcentricRingData {
  final double value; // 0.0 to 1.0
  final Color color;
  final String label;

  const ConcentricRingData({
    required this.value,
    required this.color,
    required this.label,
  });
}

class ConcentricRingsChart extends StatefulWidget {
  final List<ConcentricRingData> rings;
  final double strokeWidth;
  final double ringSpacing;
  final double height;
  final double width;

  const ConcentricRingsChart({
    super.key,
    required this.rings,
    this.strokeWidth = 8.0,
    this.ringSpacing = 5.5,
    this.height = 140.0,
    this.width = 140.0,
  });

  @override
  State<ConcentricRingsChart> createState() => _ConcentricRingsChartState();
}

class _ConcentricRingsChartState extends State<ConcentricRingsChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ConcentricRingsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart animation smoothly if rings data changes
    if (_hasDataChanged(oldWidget.rings, widget.rings)) {
      _controller.reset();
      _controller.forward();
    }
  }

  bool _hasDataChanged(List<ConcentricRingData> oldList, List<ConcentricRingData> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].value != newList[i].value || oldList[i].color != newList[i].color) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final animatedRings = widget.rings.map((ring) {
          return ConcentricRingData(
            value: ring.value * _animation.value,
            color: ring.color,
            label: ring.label,
          );
        }).toList();

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: CustomPaint(
            painter: ConcentricRingsPainter(
              rings: animatedRings,
              strokeWidth: widget.strokeWidth,
              ringSpacing: widget.ringSpacing,
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }
}

class ConcentricRingsPainter extends CustomPainter {
  final List<ConcentricRingData> rings;
  final double strokeWidth;
  final double ringSpacing;
  final bool isDark;
  
  // Angle at which the rings end (3 o'clock / 0 degrees)
  final double endAngle = 0.0;
  
  // The sweep angle covering exactly 270 degrees (leaving a 90-degree/quarter gap at the bottom-right)
  final double maxSweepAngle = 270 * math.pi / 180;

  ConcentricRingsPainter({
    required this.rings,
    required this.strokeWidth,
    required this.ringSpacing,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The circle is centered vertically and horizontally within the height
    final double circleSize = size.height;
    final center = Offset(circleSize / 2, circleSize / 2);

    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      
      // Calculate radius of this concentric ring (from outer to inner)
      final radius = (circleSize / 2) - (i * (strokeWidth + ringSpacing)) - (strokeWidth / 2);
      if (radius <= 0) continue;

      final rect = Rect.fromCircle(center: center, radius: radius);

      // Track Paint (Faded background arc)
      final trackPaint = Paint()
        ..color = ring.color.withValues(alpha: 0.13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Draw background track
      canvas.drawArc(
        rect,
        endAngle - maxSweepAngle,
        maxSweepAngle,
        false,
        trackPaint,
      );

      // Progress Paint (Colored active arc)
      final double progressValue = ring.value.clamp(0.0, 1.0);
      if (progressValue > 0) {
        final progressPaint = Paint()
          ..color = ring.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        final sweepAngle = progressValue * maxSweepAngle;

        // Draw progress arc sweeping counter-clockwise from endAngle
        canvas.drawArc(
          rect,
          endAngle,
          -sweepAngle,
          false,
          progressPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ConcentricRingsPainter oldDelegate) {
    return oldDelegate.rings != oldDelegate.rings ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.ringSpacing != ringSpacing ||
        oldDelegate.isDark != isDark;
  }
}
