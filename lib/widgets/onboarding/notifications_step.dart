import 'package:flutter/material.dart';
import '../glass_card.dart';
import 'fade_slide_transition.dart';

class NotificationsStep extends StatefulWidget {
  final bool notifDaily;
  final bool notifHydration;
  final bool notifActivity;
  final bool notifSleep;
  final bool notifChallenges;
  final bool notifRewards;
  final bool notifAiTips;
  final ValueChanged<bool> onDailyChanged;
  final ValueChanged<bool> onHydrationChanged;
  final ValueChanged<bool> onActivityChanged;
  final ValueChanged<bool> onSleepChanged;
  final ValueChanged<bool> onChallengesChanged;
  final ValueChanged<bool> onRewardsChanged;
  final ValueChanged<bool> onAiTipsChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const NotificationsStep({
    super.key,
    required this.notifDaily,
    required this.notifHydration,
    required this.notifActivity,
    required this.notifSleep,
    required this.notifChallenges,
    required this.notifRewards,
    required this.notifAiTips,
    required this.onDailyChanged,
    required this.onHydrationChanged,
    required this.onActivityChanged,
    required this.onSleepChanged,
    required this.onChallengesChanged,
    required this.onRewardsChanged,
    required this.onAiTipsChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<NotificationsStep> createState() => _NotificationsStepState();
}

class _NotificationsStepState extends State<NotificationsStep> with SingleTickerProviderStateMixin {
  late AnimationController _bellController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _rotationAnimation = Tween<double>(begin: -0.10, end: 0.10).animate(
      CurvedAnimation(
        parent: _bellController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(
        parent: _bellController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _bellController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideTransition(
                    delay: Duration.zero,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _bellController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationAnimation.value,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: const Text(
                                "🔔",
                                style: TextStyle(fontSize: 60),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FadeSlideTransition(
                    delay: Duration(milliseconds: 150),
                    child: Text(
                      "Notifications",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 250),
                    child: Text(
                      "Stay motivated with smart wellness alerts",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600], 
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildNotifToggle("Daily Wellness Reminder", "Receive a summary of today's health metrics.", widget.notifDaily, widget.onDailyChanged, isDark, 350),
                        _buildNotifToggle("Hydration Alert", "Remind you to log water and reach your goals.", widget.notifHydration, widget.onHydrationChanged, isDark, 450),
                        _buildNotifToggle("Activity Summary", "Weekly logs of total distance and calories.", widget.notifActivity, widget.onActivityChanged, isDark, 550),
                        _buildNotifToggle("Sleep Schedule", "Gentle alerts when it's time to rest.", widget.notifSleep, widget.onSleepChanged, isDark, 650),
                        _buildNotifToggle("Challenge & Updates", "Compete with users in fun activities.", widget.notifChallenges, widget.onChallengesChanged, isDark, 750),
                        _buildNotifToggle("Rewards & Offers", "Earn achievements and premium badges.", widget.notifRewards, widget.onRewardsChanged, isDark, 850),
                        _buildNotifToggle("AI Wellness Tips", "Tailored feedback on health improvements.", widget.notifAiTips, widget.onAiTipsChanged, isDark, 950),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 1050),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                    onPressed: widget.onBack,
                    child: Text("Back", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      shadowColor: Colors.blueAccent.withOpacity(0.3),
                      elevation: 4,
                    ),
                    onPressed: widget.onNext,
                    child: const Text("Allow & Finish", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
    int delayMs,
  ) {
    return FadeSlideTransition(
      delay: Duration(milliseconds: delayMs),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.015),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          ),
        ),
        child: SwitchListTile(
          title: Text(
            title, 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            subtitle, 
            style: TextStyle(
              fontSize: 11, 
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.blueAccent,
          activeTrackColor: Colors.blueAccent.withOpacity(0.3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}
