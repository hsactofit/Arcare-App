import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/health_service.dart';
import '../widgets/onboarding/profile_step.dart';
import '../widgets/onboarding/goals_step.dart';
import '../widgets/onboarding/health_sync_step.dart';
import '../widgets/onboarding/notifications_step.dart';
import '../widgets/onboarding/sync_progress_step.dart';
import 'auth_screen.dart';
import 'main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  final int initialPage;
  const OnboardingScreen({super.key, this.initialPage = 0});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late int _currentPage;
  final int _totalPages = 5;

  // Form keys for validation
  final _profileFormKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // State Variables
  String _gender = 'Female';
  final List<String> _selectedGoals = [];
  bool _healthConnected = false;

  // Notifications State
  bool _notifDaily = true;
  bool _notifHydration = true;
  bool _notifActivity = true;
  bool _notifSleep = true;
  bool _notifChallenges = false;
  bool _notifRewards = false;
  bool _notifAiTips = true;

  // Sync state
  double _syncProgress = 0.0;
  String _syncStatusText = 'Initializing secure container...';
  bool _isSyncing = false;

  // Background Animation Controllers
  late AnimationController _bgAnimationController;
  late Animation<double> _blobAnimation;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _blobAnimation = CurvedAnimation(
      parent: _bgAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _pageController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() async {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }


  // Handle goals grid toggle
  void _toggleGoal(String goal) {
    setState(() {
      if (_selectedGoals.contains(goal)) {
        _selectedGoals.remove(goal);
      } else {
        _selectedGoals.add(goal);
      }
    });
  }

  // Request Health Connect Permission
  Future<void> _connectHealth() async {
    setState(() => _isSyncing = true);
    final success = await HealthService.instance.requestPermissions();
    if (!mounted) return;
    setState(() {
      _healthConnected = success;
      _isSyncing = false;
    });
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Health Services successfully connected!"),
          backgroundColor: Colors.green,
        ),
      );
      _nextPage();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to grant health permissions. Skip or try again."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Syncing simulation and saving JSON payload
  Future<void> _startSyncAndFinish() async {
    _nextPage();
    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
    });

    final List<String> statuses = [
      'Establishing secure local environment...',
      'Syncing daily activity counts...',
      'Reading heart rate frequencies...',
      'Parsing nutrition baseline metrics...',
      'Syncing user profile with backend server...',
      'Preparing your personalized dashboard...',
    ];

    for (int i = 0; i < statuses.length; i++) {
      if (!mounted) return;
      setState(() {
        _syncStatusText = statuses[i];
        _syncProgress = (i + 1) / statuses.length;
      });
      await Future.delayed(const Duration(milliseconds: 600));
    }

    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email') ?? '';
    final userName = prefs.getString('user_name') ?? '';
    final userProvider = prefs.getString('user_provider') ?? 'email';

    // Prepare JSON payload
    final Map<String, dynamic> onboardingData = {
      'onboarding_completed': true,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'auth': {
        'provider': userProvider,
        'name': userName,
        'email': userEmail,
      },
      'profile': {
        'dob': _dobController.text.trim(),
        'gender': _gender,
        'height': double.tryParse(_heightController.text),
        'weight': double.tryParse(_weightController.text),
      },
      'goals': _selectedGoals,
      'permissions': {
        'health_connect_connected': _healthConnected,
        'notifications': {
          'daily_reminder': _notifDaily,
          'hydration_reminder': _notifHydration,
          'activity_reminder': _notifActivity,
          'sleep_reminder': _notifSleep,
          'challenge_updates': _notifChallenges,
          'rewards': _notifRewards,
          'ai_tips': _notifAiTips,
        }
      }
    };

    try {
      // Sync with FastAPI server
      await AuthService.instance.submitOnboarding(onboardingData);

      // Save locally to SharedPreferences
      await prefs.setString('onboarding_data', jsonEncode(onboardingData));
      await prefs.setBool('onboarding_completed', true);
      await prefs.setBool('health_sync_enabled', _healthConnected);

      if (!mounted) return;
      
      // Redirect to MainShell (the main app screen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to submit onboarding to server: ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic Mesh Background
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0C0D11) : const Color(0xFFF4F7FB),
            ),
          ),
          // Animated Glow Blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _blobAnimation,
              builder: (context, child) {
                final value = _blobAnimation.value;
                return Stack(
                  children: [
                    // Top-Right Blue/Cyan Blob
                    Positioned(
                      top: -120 + (value * 60),
                      right: -120 + (value * 80),
                      width: 380 + (value * 40),
                      height: 380 + (value * 40),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              isDark ? Colors.blue.withOpacity(0.22) : Colors.cyan.withOpacity(0.35),
                              Colors.blue.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom-Left Purple/Pink Blob
                    Positioned(
                      bottom: -80 + (value * 80),
                      left: -120 + (value * 60),
                      width: 420 - (value * 30),
                      height: 420 - (value * 30),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              isDark ? Colors.purple.withOpacity(0.16) : Colors.pink.withOpacity(0.28),
                              Colors.purple.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Moving Amber Center-Right Blob
                    Positioned(
                      top: 180 + (value * 120),
                      right: -50 - (value * 100),
                      width: 320 + (value * 50),
                      height: 320 + (value * 50),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              isDark ? Colors.teal.withOpacity(0.12) : Colors.amber.withOpacity(0.24),
                              Colors.teal.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Floating Glass Sphere 1 (Top Left)
                    Positioned(
                      top: 100 + (value * 60),
                      left: 30 + (value * 40),
                      width: 50,
                      height: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.65),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Floating Glass Sphere 2 (Bottom Right)
                    Positioned(
                      bottom: 120 - (value * 80),
                      right: 40 - (value * 50),
                      width: 70,
                      height: 70,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.4),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.60),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Floating Glass Sphere 3 (Center Left - Purple/Pink tinted)
                    Positioned(
                      top: 320 - (value * 50),
                      left: -20 + (value * 30),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.withOpacity(isDark ? 0.08 : 0.20),
                              Colors.pink.withOpacity(isDark ? 0.05 : 0.12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Floating Glass Sphere 4 (Bottom Left)
                    Positioned(
                      bottom: 220 + (value * 40),
                      left: 100 + (value * 30),
                      width: 30,
                      height: 30,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. Main Wizard View
          SafeArea(
            child: Column(
              children: [
                // Floating Frosted-Glass Header
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.035) : Colors.black.withOpacity(0.015),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text("✨", style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            "WellnessConnect",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      // Segmented Sliding Indicator
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_totalPages, (index) {
                          final isActive = index == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 6,
                            width: isActive ? 18 : 6,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.blueAccent : (isDark ? Colors.white24 : Colors.black12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      ProfileStep(
                        formKey: _profileFormKey,
                        dobController: _dobController,
                        heightController: _heightController,
                        weightController: _weightController,
                        gender: _gender,
                        onGenderChanged: (val) {
                          if (val != null) setState(() => _gender = val);
                        },
                        onBack: _prevPage,
                        onNext: _nextPage,
                      ),
                      GoalsStep(
                        selectedGoals: _selectedGoals,
                        onGoalToggled: _toggleGoal,
                        onBack: _prevPage,
                        onNext: _nextPage,
                      ),
                      HealthSyncStep(
                        isSyncing: _isSyncing,
                        onConnect: _connectHealth,
                        onSkip: () {
                          setState(() => _healthConnected = false);
                          _nextPage();
                        },
                        onBack: _prevPage,
                      ),
                      NotificationsStep(
                        notifDaily: _notifDaily,
                        notifHydration: _notifHydration,
                        notifActivity: _notifActivity,
                        notifSleep: _notifSleep,
                        notifChallenges: _notifChallenges,
                        notifRewards: _notifRewards,
                        notifAiTips: _notifAiTips,
                        onDailyChanged: (v) => setState(() => _notifDaily = v),
                        onHydrationChanged: (v) => setState(() => _notifHydration = v),
                        onActivityChanged: (v) => setState(() => _notifActivity = v),
                        onSleepChanged: (v) => setState(() => _notifSleep = v),
                        onChallengesChanged: (v) => setState(() => _notifChallenges = v),
                        onRewardsChanged: (v) => setState(() => _notifRewards = v),
                        onAiTipsChanged: (v) => setState(() => _notifAiTips = v),
                        onBack: _prevPage,
                        onNext: _startSyncAndFinish,
                      ),
                      SyncProgressStep(
                        progress: _syncProgress,
                        statusText: _syncStatusText,
                      ),
                    ],
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
