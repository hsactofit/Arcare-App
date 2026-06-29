import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/onboarding/welcome_step.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;

  // Background Animation Controllers
  late AnimationController _bgAnimationController;
  late Animation<double> _blobAnimation;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishWelcome();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic background mesh
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0C0D11) : const Color(0xFFF4F7FB),
            ),
          ),

          // Animated Blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _blobAnimation,
              builder: (context, child) {
                final value = _blobAnimation.value;
                return Stack(
                  children: [
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
                    Positioned(
                      bottom: -80 + (value * 80),
                      left: -120 + (value * 60),
                      width: 400 + (value * 40),
                      height: 400 + (value * 40),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              isDark ? Colors.purple.withOpacity(0.18) : Colors.pink.withOpacity(0.24),
                              Colors.purple.withOpacity(0.0),
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

          // 2. PageView Content
          SafeArea(
            child: Column(
              children: [
                // Top Segment Indicator dots
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: List.generate(_totalPages, (index) {
                      final isActive = index == _currentPage;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          margin: EdgeInsets.only(
                            right: index == _totalPages - 1 ? 0 : 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isActive
                                ? const Color(0xFF0F52BA)
                                : (isDark ? Colors.white24 : Colors.grey[300]),
                          ),
                        ),
                      );
                    }),
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
                      WelcomeStep(
                        imagePath: "assets/slide_1_onbording.png",
                        title: "Welcome to Your Wellness Journey",
                        description: "Track your daily health, activity, nutrition, and wellness records all in one place.",
                        actionLabel: "Next",
                        onAction: _nextPage,
                        isFirst: true,
                      ),
                      WelcomeStep(
                        imagePath: "assets/slide_2_onbording.png",
                        title: "Build Healthy Habits",
                        description: "Set personalized goals, monitor progress daily, and stay inspired to live a healthier life.",
                        actionLabel: "Next",
                        onAction: _nextPage,
                        onBack: _prevPage,
                      ),
                      WelcomeStep(
                        imagePath: "assets/slide_3_onbording.png",
                        title: "Your AI Wellness Companion",
                        description: "Receive personalized tips, metrics summary, and recommendations designed exactly for you.",
                        actionLabel: "Get Started",
                        onAction: _nextPage,
                        onBack: _prevPage,
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
