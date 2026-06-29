import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import 'auth_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Keep splash screen visible for at least 2.5 seconds for visual branding
    final startTime = DateTime.now();

    bool isLoggedIn = false;
    bool onboardingCompleted = false;

    try {
      final String? refreshToken = await AuthService.instance.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        // Attempt to validate/refresh token with backend
        final response = await AuthService.instance.refreshSessionToken();
        final user = response['user'];
        if (user != null) {
          isLoggedIn = true;
          onboardingCompleted = user['onboarding_completed'] ?? false;
        }
      }
    } catch (e) {
      print("Splash token verification failed: $e");
      // Clear credentials on token refresh validation failure
      await AuthService.instance.signOut();
    }

    final elapsed = DateTime.now().difference(startTime);
    final remainingDelay = const Duration(milliseconds: 2500) - elapsed;
    if (remainingDelay > Duration.zero) {
      await Future.delayed(remainingDelay);
    }

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();

    if (isLoggedIn) {
      if (onboardingCompleted) {
        // Logged in & completed onboarding -> Dashboard
        await prefs.setBool('onboarding_completed', true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainShell()),
        );
      } else {
        // Logged in but onboarding incomplete -> Profile details step (Page index 0 now)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(initialPage: 0),
          ),
        );
      }
    } else {
      final bool hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
      if (!hasSeenWelcome) {
        // First install -> show welcome screens
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      } else {
        // Already seen welcome -> Go to AuthScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Sleek Gradient Mesh Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: isDark
                      ? [const Color(0xFF0C0D11), const Color(0xFF0F1420), const Color(0xFF141926)]
                      : [const Color(0xFFE0F2F1), const Color(0xFFE0F7FA), const Color(0xFFE3F2FD)],
                ),
              ),
            ),
          ),

          // Glowing background blob decoration (Top Right)
          Positioned(
            top: -100,
            right: -100,
            width: 320,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(isDark ? 0.15 : 0.25),
                    Colors.blueAccent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Glowing background blob decoration (Bottom Left)
          Positioned(
            bottom: -80,
            left: -80,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.tealAccent.withOpacity(isDark ? 0.12 : 0.22),
                    Colors.tealAccent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Animated Center Branding Content
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo wrapped in elegant glassmorphic container
                  GlassCard(
                    padding: const EdgeInsets.all(22),
                    borderRadius: 28,
                    margin: EdgeInsets.zero,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.15),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/app_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Brand name with premium letter spacing
                  Text(
                    "arcahre wellness",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F52BA),
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sub-branding
                  Text(
                    "Optimize. Sync. Thrive.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : const Color(0xFF556677),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Minimalistic Circular Loading Indicator
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.blueAccent : const Color(0xFF0F52BA),
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Secured Compliant Footer indicator
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
                const SizedBox(width: 6),
                Text(
                  "SECURE HIPAA COMPLIANT PORTAL",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white30 : Colors.black38,
                    letterSpacing: 0.6,
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
