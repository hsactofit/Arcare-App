import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/onboarding/signup_step.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _signupFormKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSigningIn = false;
  String _authProvider = '';

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handle email login/signup submission
  Future<void> _handleEmailAuth(bool isLogin) async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isSigningIn = true);
    try {
      if (isLogin) {
        final res = await AuthService.instance.loginWithEmail(email, password);
        final backendUser = res['user'];
        final bool isCompleted = backendUser['onboarding_completed'] ?? false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', backendUser['email'] ?? email);
        await prefs.setString('user_name', backendUser['name'] ?? '');
        await prefs.setString('user_provider', 'email');

        if (isCompleted) {
          final permissions = backendUser['permissions'] ?? {};
          final bool healthSyncEnabled = permissions['health_connect_connected'] ?? false;
          await prefs.setBool('health_sync_enabled', healthSyncEnabled);

          // Save onboarding completed in SharedPreferences
          await prefs.setString('onboarding_data', jsonEncode({
            'onboarding_completed': true,
            'completed_at': backendUser['completed_at'] ?? DateTime.now().toUtc().toIso8601String(),
            'auth': {
              'provider': 'email',
              'name': backendUser['name'] ?? '',
              'email': backendUser['email'] ?? email,
            },
            'profile': backendUser['profile'] ?? {},
            'goals': backendUser['goals'] ?? [],
            'permissions': backendUser['permissions'] ?? {},
          }));
          await prefs.setBool('onboarding_completed', true);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainShell()),
          );
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen(initialPage: 0)),
          );
        }
      } else {
        final res = await AuthService.instance.signUpWithEmail(name, email, password);
        final backendUser = res['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        await prefs.setString('user_name', name);
        await prefs.setString('user_provider', 'email');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen(initialPage: 0)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Authentication failed: ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  // Handle Social Login (Google & Apple)
  Future<void> _selectSocialAuth(String provider) async {
    setState(() => _isSigningIn = true);
    try {
      final user = provider == 'Google'
          ? await AuthService.instance.signInWithGoogle()
          : await AuthService.instance.signInWithApple();

      if (user != null) {
        // Authenticate with Fast API
        final idToken = await user.getIdToken();
        if (idToken == null) throw Exception("Could not fetch ID token");

        final res = await AuthService.instance.socialLoginBackend(
          provider,
          idToken,
          name: user.displayName,
        );

        final backendUser = res['user'];
        final bool isCompleted = backendUser['onboarding_completed'] ?? false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', backendUser['email'] ?? user.email ?? '');
        await prefs.setString('user_name', backendUser['name'] ?? user.displayName ?? '');
        await prefs.setString('user_provider', provider.toLowerCase());

        if (isCompleted) {
          final permissions = backendUser['permissions'] ?? {};
          final bool healthSyncEnabled = permissions['health_connect_connected'] ?? false;
          await prefs.setBool('health_sync_enabled', healthSyncEnabled);

          // Save onboarding completed in SharedPreferences
          await prefs.setString('onboarding_data', jsonEncode({
            'onboarding_completed': true,
            'completed_at': backendUser['completed_at'] ?? DateTime.now().toUtc().toIso8601String(),
            'auth': {
              'provider': provider.toLowerCase(),
              'name': backendUser['name'] ?? user.displayName ?? '',
              'email': backendUser['email'] ?? user.email ?? '',
            },
            'profile': backendUser['profile'] ?? {},
            'goals': backendUser['goals'] ?? [],
            'permissions': backendUser['permissions'] ?? {},
          }));
          await prefs.setBool('onboarding_completed', true);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainShell()),
          );
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen(initialPage: 0)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$provider authentication was cancelled."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to authenticate with $provider: ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
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

          // 2. Auth view content
          SafeArea(
            child: SignupStep(
              formKey: _signupFormKey,
              nameController: _nameController,
              emailController: _emailController,
              passwordController: _passwordController,
              onSocialAuth: _selectSocialAuth,
              onEmailSubmit: _handleEmailAuth,
            ),
          ),

          // 3. Loading Blur Overlay
          if (_isSigningIn)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      alignment: Alignment.center,
                      color: Colors.black.withOpacity(0.15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? Colors.blueAccent : const Color(0xFF0F52BA),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Signing in securely...",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
