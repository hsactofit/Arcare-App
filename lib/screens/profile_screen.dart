import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';
import '../services/auth_service.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../main.dart';
import 'welcome_screen.dart';
import 'goals_configuration_screen.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _accent = Color(0xFFFF6D55);
  static const Color _mint = Color(0xFF2EE5A3);
  static const Color _violet = Color(0xFF8F6BFF);
  static const Color _sky = Color(0xFF5B8CFF);

  String _name = "User";
  String _email = "";
  String _dob = "Not set";
  String _gender = "Not set";
  double _height = 0.0;
  double _weight = 0.0;
  bool _hcConnected = false;
  bool _isLoading = true;

  bool _notifAiTips = true;
  bool _notifRewards = false;
  bool _notifDailyReminder = true;
  bool _notifSleepReminder = true;
  bool _notifActivityReminder = true;
  bool _notifChallengeUpdates = false;
  bool _notifHydrationReminder = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _hcConnected = prefs.getBool('healthSetupCompleted') ?? false;

      try {
        final profileData = await ApiService.instance.fetchUserProfile();
        final name = profileData['name'] ?? "User";
        final email = profileData['email'] ?? "";

        final profile = profileData['profile'] ?? {};
        final dob = profile['dob'] ?? "Not set";
        final gender = profile['gender'] ?? "Not set";
        final height = (profile['height'] ?? 0.0).toDouble();
        final weight = (profile['weight'] ?? 0.0).toDouble();

        final permissions = profileData['permissions'] ?? {};
        final hcConnectedApi =
            permissions['health_connect_connected'] as bool? ?? false;

        final notifications = permissions['notifications'] ?? {};
        final aiTips = notifications['ai_tips'] as bool? ?? true;
        final rewards = notifications['rewards'] as bool? ?? false;
        final dailyReminder = notifications['daily_reminder'] as bool? ?? true;
        final sleepReminder = notifications['sleep_reminder'] as bool? ?? true;
        final activityReminder =
            notifications['activity_reminder'] as bool? ?? true;
        final challengeUpdates =
            notifications['challenge_updates'] as bool? ?? false;
        final hydrationReminder =
            notifications['hydration_reminder'] as bool? ?? true;

        if (hcConnectedApi != _hcConnected) {
          _hcConnected = hcConnectedApi;
          await prefs.setBool('healthSetupCompleted', hcConnectedApi);
        }

        if (!mounted) return;
        setState(() {
          _name = name;
          _email = email;
          _dob = dob;
          _gender = gender;
          _height = height;
          _weight = weight;

          _notifAiTips = aiTips;
          _notifRewards = rewards;
          _notifDailyReminder = dailyReminder;
          _notifSleepReminder = sleepReminder;
          _notifActivityReminder = activityReminder;
          _notifChallengeUpdates = challengeUpdates;
          _notifHydrationReminder = hydrationReminder;

          _isLoading = false;
        });

        await prefs.setString('user_name', name);
        await prefs.setString('onboarding_data', jsonEncode(profileData));
        return;
      } catch (apiError) {
        debugPrint("API Profile load failed, falling back to local: $apiError");
      }

      final jsonStr = prefs.getString('onboarding_data');
      if (jsonStr != null) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        final profile = data['profile'] ?? {};
        final auth = data['auth'] ?? {};
        final permissions = data['permissions'] ?? {};
        final notifications = permissions['notifications'] ?? {};

        if (!mounted) return;
        setState(() {
          _name = auth['name'] ?? data['name'] ?? "User";
          _email = auth['email'] ?? data['email'] ?? "";
          _dob = profile['dob'] ?? "Not set";
          _gender = profile['gender'] ?? "Not set";
          _height = (profile['height'] ?? 0.0).toDouble();
          _weight = (profile['weight'] ?? 0.0).toDouble();
          _notifAiTips = notifications['ai_tips'] as bool? ?? true;
          _notifRewards = notifications['rewards'] as bool? ?? false;
          _notifDailyReminder =
              notifications['daily_reminder'] as bool? ?? true;
          _notifSleepReminder =
              notifications['sleep_reminder'] as bool? ?? true;
          _notifActivityReminder =
              notifications['activity_reminder'] as bool? ?? true;
          _notifChallengeUpdates =
              notifications['challenge_updates'] as bool? ?? false;
          _notifHydrationReminder =
              notifications['hydration_reminder'] as bool? ?? true;
          _isLoading = false;
        });
      } else {
        final currentUser = AuthService.instance.currentUser;
        if (!mounted) return;
        if (currentUser != null) {
          setState(() {
            _name = currentUser.displayName ?? "User";
            _email = currentUser.email ?? "";
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateBMI() {
    if (_height <= 0 || _weight <= 0) return 0.0;
    final heightInMeters = _height / 100.0;
    return _weight / (heightInMeters * heightInMeters);
  }

  String _getBMICategory(double bmi) {
    if (bmi <= 0) return "Unknown";
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25.0) return "Normal";
    if (bmi < 30.0) return "Overweight";
    return "Obese";
  }

  Color _getBMICategoryColor(double bmi) {
    if (bmi <= 0) return Colors.grey;
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25.0) return _mint;
    if (bmi < 30.0) return Colors.orange;
    return Colors.redAccent;
  }

  String _formatDobDisplay(String dob) {
    if (dob == "Not set" || dob.isEmpty) return "Not set";
    final d = DateTime.tryParse(dob);
    if (d == null) return dob;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  int? _ageFromDob(String dob) {
    final d = DateTime.tryParse(dob);
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
      age--;
    }
    return age;
  }

  String _themeModeLabel() {
    switch (themeNotifier.value) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> _showEditProfileDialog() async {
    final selectedGender = (_gender == "Not set" || _gender.isEmpty)
        ? "Male"
        : _gender;
    final selectedDob = (_dob == "Not set" || _dob.isEmpty)
        ? DateTime(1995, 1, 1)
        : (DateTime.tryParse(_dob) ?? DateTime(1995, 1, 1));

    // Controllers live inside the sheet widget so they are disposed only
    // after the route is fully unmounted (avoids dispose-during-animation crash).
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return _EditProfileSheet(
          initialName: _name,
          initialHeight: _height,
          initialWeight: _weight,
          initialGender: selectedGender,
          initialDob: selectedDob,
        );
      },
    );

    if (result == null) return; // cancelled / dismissed

    setState(() => _isLoading = true);
    try {
      final payload = {
        "name": result['name'] as String,
        "profile": {
          "dob": result['dob'] as String,
          "gender": result['gender'] as String,
          "height": result['height'] as double,
          "weight": result['weight'] as double,
        },
      };

      final updatedProfile =
          await ApiService.instance.updateUserProfile(payload);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', result['name'] as String);
      await prefs.setString('onboarding_data', jsonEncode(updatedProfile));

      await _loadProfileData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Profile updated successfully"),
            backgroundColor: _mint,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update profile: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showThemeSelectionDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTheme = prefs.getString('theme_mode') ?? 'system';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF16161C).withOpacity(0.94)
                    : Colors.white.withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.10)
                      : Colors.white.withOpacity(0.7),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose how Medifit looks on this device',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _themeOption(
                    isDark: isDark,
                    icon: Icons.light_mode_rounded,
                    title: 'Light',
                    subtitle: 'Bright, airy interface',
                    selected: currentTheme == 'light',
                    onTap: () => Navigator.pop(ctx, 'light'),
                  ),
                  const SizedBox(height: 10),
                  _themeOption(
                    isDark: isDark,
                    icon: Icons.dark_mode_rounded,
                    title: 'Dark',
                    subtitle: 'Easy on the eyes at night',
                    selected: currentTheme == 'dark',
                    onTap: () => Navigator.pop(ctx, 'dark'),
                  ),
                  const SizedBox(height: 10),
                  _themeOption(
                    isDark: isDark,
                    icon: Icons.settings_suggest_rounded,
                    title: 'System',
                    subtitle: 'Match device setting',
                    selected: currentTheme == 'system',
                    onTap: () => Navigator.pop(ctx, 'system'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await prefs.setString('theme_mode', selected);
      setState(() {
        if (selected == 'light') {
          themeNotifier.value = ThemeMode.light;
        } else if (selected == 'dark') {
          themeNotifier.value = ThemeMode.dark;
        } else {
          themeNotifier.value = ThemeMode.system;
        }
      });
    }
  }

  Future<void> _toggleHealthConnect(bool enable) async {
    final prefs = await SharedPreferences.getInstance();

    if (enable) {
      if (Platform.isAndroid) {
        final status = await HealthService.instance.getAndroidSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          if (!mounted) return;
          final download = await showDialog<bool>(
            context: context,
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AlertDialog(
                backgroundColor: isDark
                    ? const Color(0xFF1E1E26)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Install Health Connect",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                content: const Text(
                  "Health Connect is not installed on this device. Would you like to download it from the Google Play Store to sync your fitness data?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mint,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Download"),
                  ),
                ],
              );
            },
          );

          if (download == true) {
            await HealthService.instance.installHealthConnect();
          }
          return;
        }
      }

      final permissionGranted = await HealthService.instance
          .requestPermissions();
      if (permissionGranted) {
        await prefs.setBool('healthSetupCompleted', true);
        setState(() => _hcConnected = true);

        try {
          await ApiService.instance.updateUserProfile({
            "permissions": {"health_connect_connected": true},
          });
        } catch (e) {
          debugPrint("Failed to sync Health Connect status with server: $e");
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Connected to Health Connect successfully"),
              backgroundColor: _mint,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Permissions denied. Cannot connect to Health Connect.",
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      await prefs.setBool('healthSetupCompleted', false);
      setState(() => _hcConnected = false);

      try {
        await ApiService.instance.updateUserProfile({
          "permissions": {"health_connect_connected": false},
        });
      } catch (e) {
        debugPrint("Failed to sync Health Connect status with server: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Health Connect integration disabled."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF16161C).withOpacity(0.92)
                    : Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withOpacity(0.12),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sign out?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can sign back in anytime with the same account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _morphButton(
                          label: 'Cancel',
                          isDark: isDark,
                          onTap: () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _morphButton(
                          label: 'Sign Out',
                          isDark: isDark,
                          filled: true,
                          fillColor: Colors.redAccent,
                          onTap: () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondary = isDark ? Colors.white60 : Colors.black54;

    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: isDark
                    ? const Color(0xFF0F0F12)
                    : const Color(0xFFF6F8FC),
              ),
            ),
            const Center(child: CircularProgressIndicator(color: _accent)),
          ],
        ),
      );
    }

    final bmi = _calculateBMI();
    final bmiCategory = _getBMICategory(bmi);
    final bmiColor = _getBMICategoryColor(bmi);
    final age = _ageFromDob(_dob);

    return Scaffold(
      body: Stack(
        children: [
          // Morph background
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accent.withOpacity(isDark ? 0.22 : 0.14),
                    _accent.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 220,
            left: -100,
            width: 280,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _violet.withOpacity(isDark ? 0.18 : 0.10),
                    _violet.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            width: 240,
            height: 240,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _sky.withOpacity(isDark ? 0.14 : 0.08),
                    _sky.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              color: _accent,
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profile',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Your health identity & preferences',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _morphIconButton(
                          icon: Icons.refresh_rounded,
                          isDark: isDark,
                          onTap: _loadProfileData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Hero identity card
                    _buildIdentityHero(isDark, textColor, secondary, age),
                    const SizedBox(height: 16),

                    // Metrics row
                    Row(
                      children: [
                        Expanded(
                          child: _statTile(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.monitor_weight_outlined,
                            color: const Color(0xFFFFB03A),
                            label: 'WEIGHT',
                            value: _weight > 0
                                ? '${_weight % 1 == 0 ? _weight.round() : _weight.toStringAsFixed(1)}'
                                : '—',
                            unit: _weight > 0 ? 'kg' : '',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statTile(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.height_rounded,
                            color: _sky,
                            label: 'HEIGHT',
                            value: _height > 0
                                ? '${_height % 1 == 0 ? _height.round() : _height.toStringAsFixed(1)}'
                                : '—',
                            unit: _height > 0 ? 'cm' : '',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statTile(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.speed_rounded,
                            color: bmiColor,
                            label: 'BMI',
                            value: bmi > 0 ? bmi.toStringAsFixed(1) : '—',
                            unit: bmi > 0 ? bmiCategory : '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Personal details
                    _sectionLabel('PERSONAL DETAILS', theme),
                    const SizedBox(height: 10),
                    GlassCard(
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      borderRadius: 20,
                      child: Column(
                        children: [
                          _infoRow(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.cake_outlined,
                            color: _accent,
                            title: 'Date of birth',
                            value: _formatDobDisplay(_dob),
                          ),
                          _divider(isDark),
                          _infoRow(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.wc_rounded,
                            color: _violet,
                            title: 'Gender',
                            value: _gender,
                          ),
                          _divider(isDark),
                          _infoRow(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.mail_outline_rounded,
                            color: _sky,
                            title: 'Email',
                            value: _email.isEmpty ? 'Not set' : _email,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Health
                    _sectionLabel('HEALTH', theme),
                    const SizedBox(height: 10),
                    GlassCard(
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      borderRadius: 20,
                      child: Column(
                        children: [
                          _settingTile(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.track_changes_rounded,
                            color: _accent,
                            title: 'Health goals',
                            subtitle: 'Steps, water, sleep & calorie targets',
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: secondary,
                              size: 22,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const GoalsConfigurationScreen(),
                                ),
                              ).then((_) => _loadProfileData());
                            },
                          ),
                          _divider(isDark),
                          _settingTile(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.health_and_safety_outlined,
                            color: _mint,
                            title: 'Health Connect',
                            subtitle: _hcConnected
                                ? 'Connected · auto-syncing data'
                                : 'Not connected · tap switch to set up',
                            trailing: Switch.adaptive(
                              value: _hcConnected,
                              onChanged: _toggleHealthConnect,
                              activeColor: _mint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Preferences
                    _sectionLabel('PREFERENCES', theme),
                    const SizedBox(height: 10),
                    GlassCard(
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      borderRadius: 20,
                      child: Column(
                        children: [
                          _settingTile(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.notifications_none_rounded,
                            color: const Color(0xFFFFB03A),
                            title: 'Notifications',
                            subtitle: _notificationSummary(),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: secondary,
                              size: 22,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationSettingsScreen(),
                                ),
                              ).then((_) => _loadProfileData());
                            },
                          ),
                          _divider(isDark),
                          _settingTile(
                            isDark: isDark,
                            textColor: textColor,
                            secondary: secondary,
                            icon: Icons.palette_outlined,
                            color: _violet,
                            title: 'Appearance',
                            subtitle: 'Theme · ${_themeModeLabel()}',
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: secondary,
                              size: 22,
                            ),
                            onTap: _showThemeSelectionDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Sign out
                    _morphButton(
                      label: 'Sign out',
                      isDark: isDark,
                      filled: false,
                      outlineColor: Colors.redAccent,
                      textColorOverride: Colors.redAccent,
                      icon: Icons.logout_rounded,
                      onTap: _handleSignOut,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Medifit Wellness · #Wellness360',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: secondary.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _notificationSummary() {
    final enabled = [
      if (_notifDailyReminder) 'daily',
      if (_notifHydrationReminder) 'hydration',
      if (_notifSleepReminder) 'sleep',
      if (_notifActivityReminder) 'activity',
      if (_notifAiTips) 'AI tips',
      if (_notifChallengeUpdates) 'challenges',
      if (_notifRewards) 'rewards',
    ];
    if (enabled.isEmpty) return 'All alerts off';
    if (enabled.length <= 2) return enabled.join(' · ');
    return '${enabled.length} alerts on';
  }

  Widget _buildIdentityHero(
    bool isDark,
    Color textColor,
    Color? secondary,
    int? age,
  ) {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'U';

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      borderRadius: 26,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _accent.withOpacity(isDark ? 0.18 : 0.12),
              _violet.withOpacity(isDark ? 0.10 : 0.06),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar with morph ring
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accent, _violet, _sky],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF16161C) : Colors.white,
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: _accent,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email.isEmpty ? 'No email on file' : _email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: secondary,
                        ),
                      ),
                      if (age != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: _mint.withOpacity(0.14),
                          ),
                          child: Text(
                            '$age yrs · $_gender',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _mint,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showEditProfileDialog,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [_accent, Color(0xFFFF8A70)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Edit profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required bool isDark,
    required Color textColor,
    required Color? secondary,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String unit,
  }) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withOpacity(0.14),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: secondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: textColor,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.85,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.05),
    );
  }

  Widget _infoRow({
    required bool isDark,
    required Color textColor,
    required Color? secondary,
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: color.withOpacity(0.12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required bool isDark,
    required Color textColor,
    required Color? secondary,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: color.withOpacity(0.12),
                  border: Border.all(color: color.withOpacity(0.18)),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.15,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: secondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _morphIconButton({
    required IconData icon,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _morphButton({
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool filled = false,
    Color? fillColor,
    Color? outlineColor,
    Color? textColorOverride,
    IconData? icon,
  }) {
    final color = fillColor ?? _accent;
    final borderColor =
        outlineColor ??
        (isDark
            ? Colors.white.withOpacity(0.10)
            : Colors.black.withOpacity(0.06));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: filled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.95), color],
                  )
                : null,
            color: filled
                ? null
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03)),
            border: Border.all(
              color: filled ? color.withOpacity(0.3) : borderColor,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color:
                      textColorOverride ??
                      (filled
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87)),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color:
                      textColorOverride ??
                      (filled
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? _accent.withOpacity(isDark ? 0.16 : 0.10)
                : (isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03)),
            border: Border.all(
              color: selected
                  ? _accent.withOpacity(0.5)
                  : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05)),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: selected
                      ? _accent.withOpacity(0.18)
                      : (isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.04)),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? _accent
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? _accent
                    : (isDark ? Colors.white30 : Colors.black26),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _morphField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
      ),
    );
  }

  Widget _morphTapField({
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _morphDropdown({
    required bool isDark,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.wc_rounded, size: 20),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
      ),
      items: items
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Owns [TextEditingController]s for the edit-profile sheet so they are only
/// disposed after the route is fully unmounted (safe on cancel / swipe-dismiss).
class _EditProfileSheet extends StatefulWidget {
  final String initialName;
  final double initialHeight;
  final double initialWeight;
  final String initialGender;
  final DateTime initialDob;

  const _EditProfileSheet({
    required this.initialName,
    required this.initialHeight,
    required this.initialWeight,
    required this.initialGender,
    required this.initialDob,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  static const Color _accent = Color(0xFFFF6D55);

  late final TextEditingController _nameController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late String _selectedGender;
  late DateTime _selectedDob;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _heightController = TextEditingController(
      text: widget.initialHeight > 0
          ? widget.initialHeight.toStringAsFixed(
              widget.initialHeight == widget.initialHeight.roundToDouble()
                  ? 0
                  : 1,
            )
          : '',
    );
    _weightController = TextEditingController(
      text: widget.initialWeight > 0
          ? widget.initialWeight.toStringAsFixed(
              widget.initialWeight == widget.initialWeight.roundToDouble()
                  ? 0
                  : 1,
            )
          : '',
    );
    _selectedGender = widget.initialGender;
    _selectedDob = widget.initialDob;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onSave() {
    Navigator.pop(context, <String, dynamic>{
      'name': _nameController.text.trim(),
      'dob':
          '${_selectedDob.year}-${_selectedDob.month.toString().padLeft(2, '0')}-${_selectedDob.day.toString().padLeft(2, '0')}',
      'gender': _selectedGender,
      'height': double.tryParse(_heightController.text) ?? 0.0,
      'weight': double.tryParse(_weightController.text) ?? 0.0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF16161C).withOpacity(0.94)
                  : Colors.white.withOpacity(0.96),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white.withOpacity(0.7),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Update how you show up in Medifit',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _field(
                    controller: _nameController,
                    label: 'Full name',
                    icon: Icons.person_outline_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDob,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDob = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: _deco(
                        isDark: isDark,
                        label: 'Date of birth',
                        icon: Icons.cake_outlined,
                      ),
                      child: Text(
                        '${_selectedDob.year}-${_selectedDob.month.toString().padLeft(2, '0')}-${_selectedDob.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: _deco(
                      isDark: isDark,
                      label: 'Gender',
                      icon: Icons.wc_rounded,
                    ),
                    items: const [
                      'Male',
                      'Female',
                      'Non-binary',
                      'Other',
                    ]
                        .map((g) =>
                            DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGender = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _heightController,
                          label: 'Height (cm)',
                          icon: Icons.height_rounded,
                          isDark: isDark,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _weightController,
                          label: 'Weight (kg)',
                          icon: Icons.monitor_weight_outlined,
                          isDark: isDark,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _button(
                          label: 'Cancel',
                          isDark: isDark,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _button(
                          label: 'Save',
                          isDark: isDark,
                          filled: true,
                          onTap: _onSave,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _deco({
    required bool isDark,
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: _deco(isDark: isDark, label: label, icon: icon),
    );
  }

  Widget _button({
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: filled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF8A70), _accent],
                  )
                : null,
            color: filled
                ? null
                : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
            border: Border.all(
              color: filled
                  ? _accent.withOpacity(0.3)
                  : (isDark
                      ? Colors.white.withOpacity(0.10)
                      : Colors.black.withOpacity(0.06)),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: filled
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
