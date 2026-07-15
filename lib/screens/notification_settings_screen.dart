import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isLoading = true;

  // Preferences mapping
  bool _aiTips = true;
  bool _rewards = false;
  bool _dailyReminder = true;
  bool _sleepReminder = true;
  bool _activityReminder = true;
  bool _challengeUpdates = false;
  bool _hydrationReminder = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Attempt to load from API
      try {
        final profileData = await ApiService.instance.fetchUserProfile();
        final permissions = profileData['permissions'] ?? {};
        final notifications = permissions['notifications'] ?? {};

        setState(() {
          _aiTips = notifications['ai_tips'] as bool? ?? true;
          _rewards = notifications['rewards'] as bool? ?? false;
          _dailyReminder = notifications['daily_reminder'] as bool? ?? true;
          _sleepReminder = notifications['sleep_reminder'] as bool? ?? true;
          _activityReminder = notifications['activity_reminder'] as bool? ?? true;
          _challengeUpdates = notifications['challenge_updates'] as bool? ?? false;
          _hydrationReminder = notifications['hydration_reminder'] as bool? ?? true;
          _isLoading = false;
        });

        // Cache onboarding_data locally
        await prefs.setString('onboarding_data', jsonEncode(profileData));
        return;
      } catch (e) {
        debugPrint("Failed to fetch notification settings from API, loading fallback cache: $e");
      }

      // Local storage fallback
      final jsonStr = prefs.getString('onboarding_data');
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr);
        final permissions = data['permissions'] ?? {};
        final notifications = permissions['notifications'] ?? {};

        setState(() {
          _aiTips = notifications['ai_tips'] as bool? ?? true;
          _rewards = notifications['rewards'] as bool? ?? false;
          _dailyReminder = notifications['daily_reminder'] as bool? ?? true;
          _sleepReminder = notifications['sleep_reminder'] as bool? ?? true;
          _activityReminder = notifications['activity_reminder'] as bool? ?? true;
          _challengeUpdates = notifications['challenge_updates'] as bool? ?? false;
          _hydrationReminder = notifications['hydration_reminder'] as bool? ?? true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading notification settings: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSetting(String key, bool val) async {
    // Save current values to revert if API request fails
    final oldAiTips = _aiTips;
    final oldRewards = _rewards;
    final oldDaily = _dailyReminder;
    final oldSleep = _sleepReminder;
    final oldActivity = _activityReminder;
    final oldChallenges = _challengeUpdates;
    final oldHydration = _hydrationReminder;

    setState(() {
      if (key == 'ai_tips') _aiTips = val;
      if (key == 'rewards') _rewards = val;
      if (key == 'daily_reminder') _dailyReminder = val;
      if (key == 'sleep_reminder') _sleepReminder = val;
      if (key == 'activity_reminder') _activityReminder = val;
      if (key == 'challenge_updates') _challengeUpdates = val;
      if (key == 'hydration_reminder') _hydrationReminder = val;
    });

    try {
      final payload = {
        "permissions": {
          "notifications": {
            key: val
          }
        }
      };

      final updatedProfile = await ApiService.instance.updateUserProfile(payload);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('onboarding_data', jsonEncode(updatedProfile));
    } catch (e) {
      debugPrint("Failed to update notification setting on API: $e");
      // Revert state
      setState(() {
        _aiTips = oldAiTips;
        _rewards = oldRewards;
        _dailyReminder = oldDaily;
        _sleepReminder = oldSleep;
        _activityReminder = oldActivity;
        _challengeUpdates = oldChallenges;
        _hydrationReminder = oldHydration;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update settings: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notification Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          Positioned(
            top: -150,
            left: -150,
            width: 350,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
                    theme.colorScheme.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Configure which alerts you would like to receive. These settings are synchronized across your devices.",
                          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          "HEALTH & WELLNESS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _buildSwitchRow(
                                title: "AI Wellness Tips",
                                subtitle: "Personalized advice from your AI Wellness Buddy",
                                value: _aiTips,
                                onChanged: (val) => _updateSetting('ai_tips', val),
                              ),
                              const Divider(height: 1, color: Colors.white10),
                              _buildSwitchRow(
                                title: "Hydration Reminders",
                                subtitle: "Reminders to log and meet your daily water goal",
                                value: _hydrationReminder,
                                onChanged: (val) => _updateSetting('hydration_reminder', val),
                              ),
                              const Divider(height: 1, color: Colors.white10),
                              _buildSwitchRow(
                                title: "Sleep Schedule Alerts",
                                subtitle: "Helpful reminders to support consistent sleep",
                                value: _sleepReminder,
                                onChanged: (val) => _updateSetting('sleep_reminder', val),
                              ),
                              const Divider(height: 1, color: Colors.white10),
                              _buildSwitchRow(
                                title: "Activity Prompts",
                                subtitle: "Movement nudges if you remain inactive",
                                value: _activityReminder,
                                onChanged: (val) => _updateSetting('activity_reminder', val),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          "REWARDS & CHALLENGES",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _buildSwitchRow(
                                title: "Challenge Updates",
                                subtitle: "Leaderboard changes and completion status",
                                value: _challengeUpdates,
                                onChanged: (val) => _updateSetting('challenge_updates', val),
                              ),
                              const Divider(height: 1, color: Colors.white10),
                              _buildSwitchRow(
                                title: "Rewards & Milestone Announcements",
                                subtitle: "Unlock points, tiers, and exclusive badges",
                                value: _rewards,
                                onChanged: (val) => _updateSetting('rewards', val),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          "DAILY DIGEST",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: _buildSwitchRow(
                            title: "Daily Wellness Summary",
                            subtitle: "Morning briefing summarizing stats and goals",
                            value: _dailyReminder,
                            onChanged: (val) => _updateSetting('daily_reminder', val),
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.tealAccent,
          ),
        ],
      ),
    );
  }
}
