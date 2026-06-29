import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../glass_card.dart';
import 'fade_slide_transition.dart';

class SignupStep extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final void Function(String provider) onSocialAuth;
  final void Function(bool isLogin) onEmailSubmit;

  const SignupStep({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.onSocialAuth,
    required this.onEmailSubmit,
  });

  @override
  State<SignupStep> createState() => _SignupStepState();
}

class _SignupStepState extends State<SignupStep> {
  bool _isLogin = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top App Title & Logo Area (Varies based on mode)
            if (_isLogin) ...[
              FadeSlideTransition(
                delay: Duration.zero,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(
                              isDark ? 0.1 : 0.2,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
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
                    const SizedBox(height: 16),
                    Text(
                      "arcahre wellness",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F52BA),
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey[300]
                            : const Color(0xFF556677),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              FadeSlideTransition(
                delay: Duration.zero,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/app_logo.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "arcahre wellness",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F52BA),
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Glassmorphic Form Card
            GlassCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 28.0,
              ),
              margin: EdgeInsets.zero,
              child: Form(
                key: widget.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isLogin) ...[
                      FadeSlideTransition(
                        delay: Duration.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Start your journey to optimized wellness today.",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],

                    // Full Name (Only for signup)
                    if (!_isLogin) ...[
                      FadeSlideTransition(
                        delay: const Duration(milliseconds: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel("FULL NAME"),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: widget.nameController,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: _mockupInputDecoration(
                                "Alex Rivers",
                                isDark,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? "Please enter your name"
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Address
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel("EMAIL ADDRESS"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: widget.emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: _mockupInputDecoration(
                              _isLogin
                                  ? "alex@vitality.pro"
                                  : "alex@vitalitypro.com",
                              isDark,
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? "Please enter a valid email"
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel(
                            "PASSWORD",
                            trailing: _isLogin
                                ? GestureDetector(
                                    onTap: () => _showForgotPasswordDialog(context),
                                    child: const Text(
                                      "Forgot Password?",
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: widget.passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: _mockupInputDecoration(
                              "••••••••",
                              isDark,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.black38,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? "Password must be at least 6 characters"
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Terms Checkbox (Only for signup)
                    if (!_isLogin) ...[
                      FadeSlideTransition(
                        delay: const Duration(milliseconds: 400),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _agreedToTerms,
                                activeColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.black38,
                                ),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => _agreedToTerms = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                    height: 1.3,
                                  ),
                                  children: const [
                                    TextSpan(text: "I agree to the "),
                                    TextSpan(
                                      text: "Terms of Service",
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: " and "),
                                    TextSpan(
                                      text: "Privacy Policy",
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: "."),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Sign In / Get Started Button
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 500),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F52BA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                          shadowColor: const Color(0xFF0F52BA).withOpacity(0.3),
                        ),
                        onPressed: () {
                          if (!_isLogin && !_agreedToTerms) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please agree to the Terms of Service & Privacy Policy",
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          if (widget.formKey.currentState!.validate()) {
                            widget.onEmailSubmit(_isLogin);
                          }
                        },
                        child: Text(
                          _isLogin ? "Sign In" : "Get Started",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Social Login Section
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 600),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey[300],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  _isLogin
                                      ? "OR CONTINUE WITH"
                                      : "OR SIGN UP WITH",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white30
                                        : Colors.grey[400],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Google & Apple in horizontal row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? Colors.white.withOpacity(0.03)
                                        : Colors.white,
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.grey[300]!,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: () =>
                                      widget.onSocialAuth('Google'),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        "assets/google.png",
                                        width: 18,
                                        height: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        "Google",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? Colors.white.withOpacity(0.03)
                                        : Colors.white,
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.grey[300]!,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: () => widget.onSocialAuth('Apple'),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        "assets/apple.png",
                                        width: 25,
                                        height: 25,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Apple",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggle Link
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 700),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            widget.formKey.currentState?.reset();
                          });
                        },
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                text: _isLogin
                                    ? "Don't have an account? "
                                    : "Already have an account? ",
                              ),
                              TextSpan(
                                text: _isLogin ? "Sign Up" : "Log In",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
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
            ),
            const SizedBox(height: 24),

            // Mockup Footer Information
            FadeSlideTransition(
              delay: const Duration(milliseconds: 800),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isLogin
                            ? Icons.verified_user_outlined
                            : Icons.copyright_outlined,
                        size: 14,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isLogin
                            ? "SECURE, HIPAA COMPLIANT PORTAL"
                            : "2026 arcahre wellness. Secure HIPAA compliant registration.",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white30 : Colors.black38,
                          letterSpacing: _isLogin ? 0.5 : 0.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String labelText, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          labelText,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final TextEditingController recoveryEmailController = TextEditingController(text: widget.emailController.text);
    final TextEditingController otpController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();

    int currentStep = 0; 
    bool isDialogLoading = false;
    String errorMessage = '';
    String resetToken = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                margin: EdgeInsets.zero,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentStep == 0
                                ? "Reset Password"
                                : currentStep == 1
                                    ? "Verify OTP"
                                    : currentStep == 2
                                        ? "New Password"
                                        : "Success!",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (currentStep < 3 && !isDialogLoading)
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              color: isDark ? Colors.white54 : Colors.black54,
                              onPressed: () {
                                recoveryEmailController.dispose();
                                otpController.dispose();
                                newPasswordController.dispose();
                                Navigator.of(context).pop();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (errorMessage.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (currentStep == 0) ...[
                        Text(
                          "Enter your registered email address to receive a 6-digit OTP code.",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: recoveryEmailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: _mockupInputDecoration("alex@vitality.pro", isDark),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F52BA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isDialogLoading
                              ? null
                              : () async {
                                  final email = recoveryEmailController.text.trim();
                                  if (email.isEmpty || !email.contains('@')) {
                                    setDialogState(() {
                                      errorMessage = 'Please enter a valid email address.';
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    isDialogLoading = true;
                                    errorMessage = '';
                                  });
                                  try {
                                    await AuthService.instance.forgotPassword(email);
                                    setDialogState(() {
                                      currentStep = 1;
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      errorMessage = e.toString().replaceAll('Exception: ', '');
                                    });
                                  } finally {
                                    setDialogState(() {
                                      isDialogLoading = false;
                                    });
                                  }
                                },
                          child: isDialogLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text("Send OTP", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ] else if (currentStep == 1) ...[
                        Text(
                          "Enter the 6-digit code. Check your server logs/console for the OTP code.",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: 8.0,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          decoration: _mockupInputDecoration("••••••", isDark),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                ),
                                onPressed: isDialogLoading
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          currentStep = 0;
                                          errorMessage = '';
                                        });
                                      },
                                child: Text("Back", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F52BA),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: isDialogLoading
                                    ? null
                                    : () async {
                                        final otp = otpController.text.trim();
                                        if (otp.length != 6) {
                                          setDialogState(() {
                                            errorMessage = 'Please enter the 6-digit OTP code.';
                                          });
                                          return;
                                        }
                                        setDialogState(() {
                                          isDialogLoading = true;
                                          errorMessage = '';
                                        });
                                        try {
                                          final token = await AuthService.instance.verifyOtp(
                                            recoveryEmailController.text.trim(),
                                            otp,
                                          );
                                          setDialogState(() {
                                            resetToken = token;
                                            currentStep = 2;
                                          });
                                        } catch (e) {
                                          setDialogState(() {
                                            errorMessage = e.toString().replaceAll('Exception: ', '');
                                          });
                                        } finally {
                                          setDialogState(() {
                                            isDialogLoading = false;
                                          });
                                        }
                                      },
                                child: isDialogLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text("Verify OTP", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ] else if (currentStep == 2) ...[
                        Text(
                          "Enter a new password for your account (minimum 6 characters).",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: true,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: _mockupInputDecoration("New password", isDark),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F52BA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isDialogLoading
                              ? null
                              : () async {
                                  final newPass = newPasswordController.text.trim();
                                  if (newPass.length < 6) {
                                    setDialogState(() {
                                      errorMessage = 'Password must be at least 6 characters.';
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    isDialogLoading = true;
                                    errorMessage = '';
                                  });
                                  try {
                                    await AuthService.instance.resetPassword(resetToken, newPass);
                                    setDialogState(() {
                                      currentStep = 3;
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      errorMessage = e.toString().replaceAll('Exception: ', '');
                                    });
                                  } finally {
                                    setDialogState(() {
                                      isDialogLoading = false;
                                    });
                                  }
                                },
                          child: isDialogLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text("Reset Password", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ] else if (currentStep == 3) ...[
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.greenAccent,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Your password has been successfully reset. You can now log in with your new credentials.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[200] : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            recoveryEmailController.dispose();
                            otpController.dispose();
                            newPasswordController.dispose();
                            Navigator.of(context).pop();
                          },
                          child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _mockupInputDecoration(
    String hintText,
    bool isDark, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? Colors.white30 : Colors.black38,
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark
          ? const Color(0xFF1E1E26).withOpacity(0.5)
          : Colors.white.withOpacity(0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey[300]!,
          width: 1.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey[300]!,
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
      ),
    );
  }
}
