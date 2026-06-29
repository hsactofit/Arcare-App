import 'package:flutter/material.dart';
import '../glass_card.dart';
import 'fade_slide_transition.dart';

class GoalsStep extends StatelessWidget {
  final List<String> selectedGoals;
  final void Function(String goal) onGoalToggled;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const GoalsStep({
    super.key,
    required this.selectedGoals,
    required this.onGoalToggled,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Map<String, String>> goals = [
      {'title': 'Lose Weight', 'icon': '📉'},
      {'title': 'Gain Weight', 'icon': '📈'},
      {'title': 'Stay Active', 'icon': '🏃'},
      {'title': 'Improve Sleep', 'icon': '🌙'},
      {'title': 'Build Muscle', 'icon': '💪'},
      {'title': 'Eat Healthier', 'icon': '🍎'},
      {'title': 'Reduce Stress', 'icon': '🧘'},
      {'title': 'Increase Steps', 'icon': '🚶'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideTransition(
                    delay: Duration.zero,
                    child: Column(
                      children: [
                        const Text(
                          "Select Your Goals",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Select one or more targets to personalize wellness suggestions",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: goals.length,
                      itemBuilder: (context, idx) {
                        final goal = goals[idx];
                        final title = goal['title']!;
                        final isSelected = selectedGoals.contains(title);
                        final itemDelay = Duration(milliseconds: 100 + (idx * 40));

                        return FadeSlideTransition(
                          delay: itemDelay,
                          child: GestureDetector(
                            onTap: () => onGoalToggled(title),
                            child: AnimatedScale(
                              scale: isSelected ? 1.03 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Colors.blueAccent.withOpacity(0.15)
                                      : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected 
                                        ? Colors.blueAccent 
                                        : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06)),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(goal['icon']!, style: const TextStyle(fontSize: 28)),
                                    const SizedBox(height: 8),
                                    Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected 
                                            ? Colors.blueAccent 
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 500),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: onBack,
                    child: const Text("Back"),
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
                    ),
                    onPressed: selectedGoals.isEmpty 
                        ? null 
                        : onNext,
                    child: const Text("Next", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
