import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/app_brand_logo.dart';
import 'auth_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
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
        // If we have a local refresh token, we can consider the user logged in.
        // If the network call below fails, we will retain this login state.
        isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

        try {
          // Attempt to validate/refresh token with backend
          final response = await AuthService.instance.refreshSessionToken();
          final user = response['user'];
          if (user != null) {
            onboardingCompleted =
                user['onboarding_completed'] ?? onboardingCompleted;
            await prefs.setBool('onboarding_completed', onboardingCompleted);
            if (user['last_sync_date'] != null) {
              await prefs.setString(
                'last_sync_timestamp',
                user['last_sync_date'],
              );
            }
          }
        } on AuthException catch (authError) {
          print("Splash token verification failed: $authError");
          // If the token is explicitly invalid, clear credentials and force login
          isLoggedIn = false;
          await AuthService.instance.signOut();
        } catch (networkError) {
          print(
            "Splash token refresh network error (offline mode): $networkError",
          );
          // Retain isLoggedIn = true and use local onboardingCompleted state since it's just a network/server failure
        }
      }
    } catch (e) {
      print("Splash initialization error: $e");
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
                      ? [
                          const Color(0xFF0C0D11),
                          const Color(0xFF0F1420),
                          const Color(0xFF141926),
                        ]
                      : [
                          const Color(0xFFE0F2F1),
                          const Color(0xFFE0F7FA),
                          const Color(0xFFE3F2FD),
                        ],
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
                  // Wide wordmark logo (white on transparent → dark plate)
                  const AppBrandLogo.hero(),
                  const SizedBox(height: 20),

                  // Tagline only — brand name is already in the logo art
                  Text(
                    "Optimize. Sync. Thrive.",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF556677),
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
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
