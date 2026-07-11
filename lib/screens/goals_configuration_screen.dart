import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';

class GoalsConfigurationScreen extends StatefulWidget {
  const GoalsConfigurationScreen({super.key});

  @override
  State<GoalsConfigurationScreen> createState() => _GoalsConfigurationScreenState();
}

class _GoalsConfigurationScreenState extends State<GoalsConfigurationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobController;
  late Animation<double> _blobAnimation;

  double _stepGoal = 10000.0;
  double _waterGoal = 2500.0;
  double _calorieGoal = 600.0;
  double _exerciseGoal = 60.0;
  double _sleepGoal = 8.0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();

    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _blobAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blobController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stepGoal = prefs.getDouble('goal_steps') ?? 10000.0;
      _waterGoal = prefs.getDouble('goal_water') ?? 2500.0;
      _calorieGoal = prefs.getDouble('goal_calories') ?? 600.0;
      _exerciseGoal = prefs.getDouble('goal_exercise') ?? 60.0;
      _sleepGoal = prefs.getDouble('goal_sleep') ?? 8.0;
      _isLoading = false;
    });
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('goal_steps', _stepGoal);
    await prefs.setDouble('goal_water', _waterGoal);
    await prefs.setDouble('goal_calories', _calorieGoal);
    await prefs.setDouble('goal_exercise', _exerciseGoal);
    await prefs.setDouble('goal_sleep', _sleepGoal);

    // Sync custom goals to FastAPI backend server
    try {
      final jsonStr = prefs.getString('onboarding_data');
      if (jsonStr != null) {
        final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
        final email = onboarding['auth']?['email'];
        if (email != null) {
          final token = await AuthService.instance.getAccessToken();
          final syncUrl = '${AuthService.apiBaseUrl}/api/goals/update/${Uri.encodeComponent(email)}';
          
          final response = await http.post(
            Uri.parse(syncUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'step_goal': _stepGoal,
              'sleep_goal': _sleepGoal,
              'water_goal': _waterGoal,
              'calorie_goal': _calorieGoal,
              'exercise_goal': _exerciseGoal,
            }),
          );

          // Debug log the goals update API response
          debugPrint("================ GOALS UPDATE API RESPONSE ================");
          debugPrint("Status Code: ${response.statusCode}");
          debugPrint("Response Body: ${response.body}");
          debugPrint("===========================================================");
        }
      }
    } catch (e) {
      debugPrint("Error syncing custom goals to backend server: $e");
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Goals saved successfully!"),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Premium Glow Background
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _blobAnimation,
              builder: (context, child) {
                final value = _blobAnimation.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -100 + (value * 50),
                      right: -100 + (value * 80),
                      width: 320,
                      height: 320,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.blue.withOpacity(isDark ? 0.12 : 0.08),
                              Colors.blue.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50 + (value * 60),
                      left: -80 + (value * 40),
                      width: 300,
                      height: 300,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.teal.withOpacity(isDark ? 0.10 : 0.06),
                              Colors.teal.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. Main content scroll view
          SafeArea(
            child: Column(
              children: [
                // Premium custom app bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Set Wellness Goals 🎯",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          "Configure daily health targets below. Your custom goals directly update the Wellness Meter calculations and recommendations.",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Steps Goal Slider Card
                        _buildGoalSliderCard(
                          title: "Daily Step Goal 👣",
                          value: _stepGoal,
                          min: 3000,
                          max: 20000,
                          divisions: 34,
                          unit: "steps",
                          color: const Color(0xFF2EE5A3),
                          isDark: isDark,
                          onChanged: (val) {
                            setState(() {
                              _stepGoal = (val / 500).round() * 500.0;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Sleep Goal Slider Card
                        _buildGoalSliderCard(
                          title: "Sleep Duration Goal 🌙",
                          value: _sleepGoal,
                          min: 4,
                          max: 12,
                          divisions: 16,
                          unit: "hours",
                          color: const Color(0xFF8F6BFF),
                          isDark: isDark,
                          onChanged: (val) {
                            setState(() {
                              _sleepGoal = (val * 2).round() / 2.0;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Water Goal Slider Card
                        _buildGoalSliderCard(
                          title: "Water Hydration Goal 💧",
                          value: _waterGoal,
                          min: 1000,
                          max: 5000,
                          divisions: 16,
                          unit: "ml",
                          color: const Color(0xFF2ECAE5),
                          isDark: isDark,
                          onChanged: (val) {
                            setState(() {
                              _waterGoal = (val / 250).round() * 250.0;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Calories Goal Slider Card
                        _buildGoalSliderCard(
                          title: "Active Calories Target 🔥",
                          value: _calorieGoal,
                          min: 200,
                          max: 2000,
                          divisions: 36,
                          unit: "kcal",
                          color: const Color(0xFFFF6D55),
                          isDark: isDark,
                          onChanged: (val) {
                            setState(() {
                              _calorieGoal = (val / 50).round() * 50.0;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Exercise Goal Slider Card
                        _buildGoalSliderCard(
                          title: "Exercise Duration Target ⏱️",
                          value: _exerciseGoal,
                          min: 10,
                          max: 180,
                          divisions: 34,
                          unit: "mins",
                          color: Colors.amber,
                          isDark: isDark,
                          onChanged: (val) {
                            setState(() {
                              _exerciseGoal = (val / 5).round() * 5.0;
                            });
                          },
                        ),
                        const SizedBox(height: 32),

                        // Save Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _saveGoals,
                          child: const Text(
                            "Save Changes",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSliderCard({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required Color color,
    required bool isDark,
    required ValueChanged<double> onChanged,
  }) {
    final titleColor = isDark ? Colors.white70 : Colors.black87;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              Text(
                "${value.round()} $unit",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.12),
              thumbColor: color,
              overlayColor: color.withOpacity(0.15),
              trackHeight: 4,
              valueIndicatorColor: color,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
