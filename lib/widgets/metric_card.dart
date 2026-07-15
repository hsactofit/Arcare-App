import 'package:flutter/material.dart';
import 'glass_card.dart';

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);

    double minY = data.reduce((a, b) => a < b ? a : b);
    double maxY = data.reduce((a, b) => a > b ? a : b);
    if (maxY == minY) {
      maxY += 1.0;
    }

    double normalize(double val) {
      final ratio = (val - minY) / (maxY - minY);
      return size.height - (ratio * size.height * 0.6 + size.height * 0.2);
    }

    path.moveTo(0, normalize(data[0]));

    for (int i = 0; i < data.length - 1; i++) {
      final x1 = i * stepX;
      final y1 = normalize(data[i]);
      final x2 = (i + 1) * stepX;
      final y2 = normalize(data[i + 1]);

      final cx1 = x1 + stepX / 2;
      final cy1 = y1;
      final cx2 = x2 - stepX / 2;
      final cy2 = y2;

      path.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String icon;
  final Color color;
  final double? progress;
  final String subtitle;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.progress,
    required this.subtitle,
    this.onTap,
  });

  List<double> _getMockDataForType() {
    final cleanValue = value.trim();
    if (cleanValue == "--" ||
        cleanValue == "--/--" ||
        cleanValue == "0" ||
        cleanValue == "0.0" ||
        cleanValue.startsWith("0h") ||
        cleanValue.startsWith("0.0 hrs") ||
        cleanValue.isEmpty) {
      return [1.0, 1.0];
    }

    final cleanTitle = title.toLowerCase();
    if (cleanTitle.contains("step")) {
      return [4200, 5100, 4800, 6900, 5800, 7200, 8432];
    } else if (cleanTitle.contains("cal") || cleanTitle.contains("energy")) {
      return [1400, 1750, 1500, 2100, 1800, 1950, 2180];
    } else if (cleanTitle.contains("water")) {
      return [1.0, 1.8, 1.2, 2.0, 1.5, 2.4, 1.6];
    } else if (cleanTitle.contains("sleep")) {
      return [6.2, 7.5, 6.8, 8.0, 7.0, 7.4, 7.2];
    } else if (cleanTitle.contains("heart")) {
      return [68, 75, 70, 72, 69, 74, 72];
    } else {
      return [10, 30, 25, 45, 35, 55, 40];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mockDataset = _getMockDataForType();

    final card = GlassCard(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Circular Icon Left, Goal/Subtitle Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: icon.startsWith('assets/')
                      ? Image.asset(
                          icon,
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Text('•', style: TextStyle(fontSize: 16)),
                        )
                      : Text(
                          icon,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              Expanded(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Middle Row: Large Value + Unit label
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Bottom Container: Bezier Sparkline
          SizedBox(
            height: 28,
            width: double.infinity,
            child: CustomPaint(
              painter: SparklinePainter(mockDataset, color),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: card,
        ),
      );
    }
    return card;
  }
}
