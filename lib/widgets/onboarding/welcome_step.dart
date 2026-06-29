import 'package:flutter/material.dart';
import '../glass_card.dart';
import 'fade_slide_transition.dart';

class WelcomeStep extends StatefulWidget {
  final String? emoji;
  final String? imagePath;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onBack;
  final bool isFirst;

  const WelcomeStep({
    super.key,
    this.emoji,
    this.imagePath,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.onBack,
    this.isFirst = false,
  });

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                child: Column(
                  children: [
                    FadeSlideTransition(
                      delay: Duration.zero,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: widget.imagePath != null
                            ? Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark 
                                        ? Colors.white.withOpacity(0.08) 
                                        : Colors.black.withOpacity(0.04),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark 
                                          ? Colors.black.withOpacity(0.4) 
                                          : Colors.blueAccent.withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Image.asset(
                                  widget.imagePath!,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Text(
                                widget.emoji ?? "🌟",
                                style: const TextStyle(fontSize: 84),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 150),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 300),
                      child: Text(
                        widget.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideTransition(
                delay: const Duration(milliseconds: 450),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    shadowColor: Colors.blueAccent.withOpacity(0.3),
                    elevation: 4,
                  ),
                  onPressed: widget.onAction,
                  child: Text(
                    widget.actionLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (!widget.isFirst && widget.onBack != null) ...[
                const SizedBox(height: 12),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 550),
                  child: TextButton(
                    onPressed: widget.onBack,
                    child: Text(
                      "Back",
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
