import 'dart:convert';
import 'dart:io';
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
      
      // Load health connect status
      _hcConnected = prefs.getBool('healthSetupCompleted') ?? false;

      // Fetch latest profile from API
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
        final hcConnectedApi = permissions['health_connect_connected'] as bool? ?? false;
        
        final notifications = permissions['notifications'] ?? {};
        final aiTips = notifications['ai_tips'] as bool? ?? true;
        final rewards = notifications['rewards'] as bool? ?? false;
        final dailyReminder = notifications['daily_reminder'] as bool? ?? true;
        final sleepReminder = notifications['sleep_reminder'] as bool? ?? true;
        final activityReminder = notifications['activity_reminder'] as bool? ?? true;
        final challengeUpdates = notifications['challenge_updates'] as bool? ?? false;
        final hydrationReminder = notifications['hydration_reminder'] as bool? ?? true;

        if (hcConnectedApi != _hcConnected) {
          _hcConnected = hcConnectedApi;
          await prefs.setBool('healthSetupCompleted', hcConnectedApi);
        }

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

        // Also save profile data locally to cache
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

        setState(() {
          _name = auth['name'] ?? data['name'] ?? "User";
          _email = auth['email'] ?? data['email'] ?? "";
          _dob = profile['dob'] ?? "Not set";
          _gender = profile['gender'] ?? "Not set";
          _height = (profile['height'] ?? 0.0).toDouble();
          _weight = (profile['weight'] ?? 0.0).toDouble();
          _notifAiTips = notifications['ai_tips'] as bool? ?? true;
          _notifRewards = notifications['rewards'] as bool? ?? false;
          _notifDailyReminder = notifications['daily_reminder'] as bool? ?? true;
          _notifSleepReminder = notifications['sleep_reminder'] as bool? ?? true;
          _notifActivityReminder = notifications['activity_reminder'] as bool? ?? true;
          _notifChallengeUpdates = notifications['challenge_updates'] as bool? ?? false;
          _notifHydrationReminder = notifications['hydration_reminder'] as bool? ?? true;
          _isLoading = false;
        });
      } else {
        // Fallback to currently logged in Firebase user details
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          setState(() {
            _name = currentUser.displayName ?? "User";
            _email = currentUser.email ?? "";
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      setState(() {
        _isLoading = false;
      });
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
    if (bmi < 25.0) return "Normal Weight";
    if (bmi < 30.0) return "Overweight";
    return "Obese";
  }

  Color _getBMICategoryColor(double bmi) {
    if (bmi <= 0) return Colors.grey;
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.orange;
    return Colors.redAccent;
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _name);
    final heightController = TextEditingController(text: _height > 0 ? _height.toString() : "");
    final weightController = TextEditingController(text: _weight > 0 ? _weight.toString() : "");
    
    String selectedGender = (_gender == "Not set" || _gender.isEmpty) ? "Male" : _gender;
    DateTime selectedDob = (_dob == "Not set" || _dob.isEmpty) ? DateTime(1995, 1, 1) : (DateTime.tryParse(_dob) ?? DateTime(1995, 1, 1));
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Edit Profile",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Full Name"),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDob,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDob = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: "Date of Birth"),
                        child: Text(
                          "${selectedDob.year}-${selectedDob.month.toString().padLeft(2, '0')}-${selectedDob.day.toString().padLeft(2, '0')}",
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(labelText: "Gender"),
                      items: ["Male", "Female", "Non-binary", "Other"]
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedGender = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Height (cm)"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Weight (kg)"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Save", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        final dobStr = "${selectedDob.year}-${selectedDob.month.toString().padLeft(2, '0')}-${selectedDob.day.toString().padLeft(2, '0')}";
            
        final payload = {
          "name": nameController.text.trim(),
          "profile": {
            "dob": dobStr,
            "gender": selectedGender,
            "height": double.tryParse(heightController.text) ?? 0.0,
            "weight": double.tryParse(weightController.text) ?? 0.0,
          }
        };

        final updatedProfile = await ApiService.instance.updateUserProfile(payload);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', nameController.text.trim());
        await prefs.setString('onboarding_data', jsonEncode(updatedProfile));

        await _loadProfileData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🎉 Profile updated successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint("Error updating profile: $e");
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to update profile: $e"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _showThemeSelectionDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTheme = prefs.getString('theme_mode') ?? 'system';
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Choose Theme", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text("Light"),
              value: 'light',
              groupValue: currentTheme,
              onChanged: (val) => Navigator.pop(context, val),
            ),
            RadioListTile<String>(
              title: const Text("Dark"),
              value: 'dark',
              groupValue: currentTheme,
              onChanged: (val) => Navigator.pop(context, val),
            ),
            RadioListTile<String>(
              title: const Text("System Default"),
              value: 'system',
              groupValue: currentTheme,
              onChanged: (val) => Navigator.pop(context, val),
            ),
          ],
        ),
      ),
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
                backgroundColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text("Install Health Connect", style: TextStyle(fontWeight: FontWeight.bold)),
                content: const Text(
                  "Health Connect is not installed on this device. Would you like to download it from the Google Play Store to sync your fitness data?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Download", style: TextStyle(color: Colors.white)),
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

      final permissionGranted = await HealthService.instance.requestPermissions();
      if (permissionGranted) {
        await prefs.setBool('healthSetupCompleted', true);
        setState(() {
          _hcConnected = true;
        });
        
        try {
          await ApiService.instance.updateUserProfile({
            "permissions": {
              "health_connect_connected": true
            }
          });
        } catch (e) {
          debugPrint("Failed to sync Health Connect status with server: $e");
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🎉 Connected to Health Connect successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Permissions denied. Cannot connect to Health Connect."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      await prefs.setBool('healthSetupCompleted', false);
      setState(() {
        _hcConnected = false;
      });

      try {
        await ApiService.instance.updateUserProfile({
          "permissions": {
            "health_connect_connected": false
          }
        });
      } catch (e) {
        debugPrint("Failed to sync Health Connect status with server: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Health Connect integration disabled."),
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to sign out from Arcare?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out", style: TextStyle(color: Colors.white)),
          ),
        ],
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
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    final bmi = _calculateBMI();
    final bmiCategory = _getBMICategory(bmi);
    final bmiColor = _getBMICategoryColor(bmi);

    return Scaffold(
      body: Stack(
        children: [
          // Background Glows
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            width: 300,
            height: 300,
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

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Area
                  Text(
                    "Profile Settings ⚙️",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Profile Header glass card
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Avatar placeholder
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Colors.blueAccent, Colors.tealAccent],
                            ),
                            border: Border.all(
                              color: Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _name.isNotEmpty ? _name[0].toUpperCase() : "U",
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 24),
                          onPressed: _showEditProfileDialog,
                          tooltip: "Edit Profile",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Physical Parameters Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildParameterCard("Weight", _weight > 0 ? "${_weight.round()} kg" : "Not set", Colors.orange, isDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildParameterCard("Height", _height > 0 ? "${_height.round()} cm" : "Not set", Colors.blue, isDark),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // BMI Card
                  if (bmi > 0)
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: bmiColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.speed, color: bmiColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Body Mass Index (BMI)",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${bmi.toStringAsFixed(1)} - $bmiCategory",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // General Settings Header
                  Text(
                    "Settings Preferences",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Settings options
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildSettingRow(
                          icon: Icons.track_changes_rounded,
                          title: "Configure Health Goals",
                          subtitle: "Customize daily steps, water, sleep, calorie targets",
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GoalsConfigurationScreen(),
                              ),
                            ).then((_) {
                              _loadProfileData();
                            });
                          },
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        _buildSettingRow(
                          icon: Icons.health_and_safety_outlined,
                          title: "Health Connect Integration",
                          subtitle: _hcConnected ? "Connected successfully" : "Setup missing",
                          trailing: Switch(
                            value: _hcConnected,
                            onChanged: _toggleHealthConnect,
                            activeColor: Colors.tealAccent,
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        _buildSettingRow(
                          icon: Icons.notifications_none_outlined,
                          title: "Daily Reminders & Hydration",
                          subtitle: "Manage notification alerts",
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationSettingsScreen(),
                              ),
                            ).then((_) {
                              _loadProfileData();
                            });
                          },
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        _buildSettingRow(
                          icon: Icons.color_lens_outlined,
                          title: "Appearance Theme",
                          subtitle: "Switch light, dark or system theme",
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: _showThemeSelectionDialog,
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        _buildSettingRow(
                          icon: Icons.privacy_tip_outlined,
                          title: "Privacy & Consent Settings",
                          subtitle: "All permissions active",
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sign Out Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.redAccent.withOpacity(0.12) : Colors.red[50],
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      "Sign Out from Arcare",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 80), // Padding to clear bottom navigation bar
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterCard(String title, String value, Color color, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDark ? Colors.tealAccent : Colors.teal[800], size: 20),
            ),
            const SizedBox(width: 14),
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
            trailing,
          ],
        ),
      ),
    );
  }
}
