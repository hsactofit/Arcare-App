import 'package:flutter/material.dart';
import '../glass_card.dart';
import 'fade_slide_transition.dart';

class SyncProgressStep extends StatefulWidget {
  final double progress;
  final String statusText;

  const SyncProgressStep({
    super.key,
    required this.progress,
    required this.statusText,
  });

  @override
  State<SyncProgressStep> createState() => _SyncProgressStepState();
}

class _SyncProgressStepState extends State<SyncProgressStep> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: FadeSlideTransition(
                  delay: Duration.zero,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glassmorphic glowing backdrop
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(isDark ? 0.18 : 0.12),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: widget.progress,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            color: Colors.blueAccent,
                            backgroundColor: isDark 
                                ? Colors.white.withOpacity(0.08) 
                                : Colors.black.withOpacity(0.05),
                          ),
                        ),
                        Text(
                          "${(widget.progress * 100).round()}%",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const FadeSlideTransition(
                delay: Duration(milliseconds: 150),
                child: Text(
                  "Personalizing Experience",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideTransition(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  widget.statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
