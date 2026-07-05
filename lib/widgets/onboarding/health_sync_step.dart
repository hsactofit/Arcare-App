import 'package:flutter/material.dart';
import '../glass_card.dart';
import 'fade_slide_transition.dart';

class HealthSyncStep extends StatefulWidget {
  final bool isSyncing;
  final VoidCallback onConnect;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const HealthSyncStep({
    super.key,
    required this.isSyncing,
    required this.onConnect,
    required this.onSkip,
    required this.onBack,
  });

  @override
  State<HealthSyncStep> createState() => _HealthSyncStepState();
}

class _HealthSyncStepState extends State<HealthSyncStep> with SingleTickerProviderStateMixin {
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
                        child: Image.asset(
                          'assets/health_sync.png',
                          width: 80,
                          height: 80,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const FadeSlideTransition(
                      delay: Duration(milliseconds: 150),
                      child: Text(
                        "Sync Health Records",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 300),
                      child: Text(
                        "Wellness Sync securely aggregates data from Google Health Connect & Apple HealthKit to populate your activity totals automatically.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Core types info
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 450),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: const Column(
                          children: [
                            _PermissionItem(icon: "🚶", label: "Daily Steps & Distance", delayMs: 550),
                            SizedBox(height: 10),
                            _PermissionItem(icon: "🔥", label: "Calories & Exercise time", delayMs: 650),
                            SizedBox(height: 10),
                            _PermissionItem(icon: "🌙", label: "Sleep Duration", delayMs: 750),
                            SizedBox(height: 10),
                            _PermissionItem(icon: "💓", label: "Heart Rate Pulse", delayMs: 850),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              FadeSlideTransition(
                delay: const Duration(milliseconds: 950),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    shadowColor: Colors.blueAccent.withOpacity(0.3),
                    elevation: 4,
                  ),
                  onPressed: widget.isSyncing ? null : widget.onConnect,
                  child: widget.isSyncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Connect Health Services", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideTransition(
                delay: const Duration(milliseconds: 1050),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: widget.onBack,
                        child: Text("Back", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: widget.onSkip,
                        child: const Text("Skip for now", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final String icon;
  final String label;
  final int delayMs;

  const _PermissionItem({
    required this.icon,
    required this.label,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    return FadeSlideTransition(
      delay: Duration(milliseconds: delayMs),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
