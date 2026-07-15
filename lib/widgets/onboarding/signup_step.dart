import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../app_brand_logo.dart';
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
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.passwordController.addListener(_onPasswordChanged);
    _passwordFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_onPasswordChanged);
    _passwordFocusNode.removeListener(_onFocusChanged);
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _hasMinLength => widget.passwordController.text.length >= 8;
  bool get _hasUppercase =>
      widget.passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase =>
      widget.passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber =>
      widget.passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar => widget.passwordController.text.contains(
    RegExp(r'[!@#\$%^&*(),.?":{}|<>]'),
  );

  int get _strengthScore {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasNumber) score++;
    if (_hasSpecialChar) score++;
    return score;
  }

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
                    // Wide white wordmark on dark plate (transparent-safe)
                    const AppBrandLogo(
                      height: 92,
                      maxWidth: 320,
                      borderRadius: 20,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      elevated: true,
                    ),
                    const SizedBox(height: 16),
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
                child: Column(
                  children: [
                    const AppBrandLogo.compact(),
                    const SizedBox(height: 10),
                    Text(
                      "Create your account",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey[300]
                            : const Color(0xFF556677),
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
                                    onTap: () =>
                                        _showForgotPasswordDialog(context),
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
                            focusNode: _passwordFocusNode,
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
                            validator: (v) {
                              if (_isLogin) {
                                return (v == null || v.isEmpty)
                                    ? "Please enter your password"
                                    : null;
                              }
                              if (v == null || v.isEmpty) {
                                return "Please enter a password";
                              }
                              if (v.length < 8) {
                                return "Password must be at least 8 characters";
                              }
                              if (!v.contains(RegExp(r'[A-Z]'))) {
                                return "Must contain at least one uppercase letter";
                              }
                              if (!v.contains(RegExp(r'[a-z]'))) {
                                return "Must contain at least one lowercase letter";
                              }
                              if (!v.contains(RegExp(r'[0-9]'))) {
                                return "Must contain at least one number";
                              }
                              if (!v.contains(
                                RegExp(r'[!@#\$%^&*(),.?":{}|<>]'),
                              )) {
                                return "Must contain at least one special character";
                              }
                              return null;
                            },
                          ),
                          _buildPasswordIndicator(isDark),
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
                            : "2026 Medifit Wellness. Secure HIPAA compliant registration.",
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

    final TextEditingController recoveryEmailController = TextEditingController(
      text: widget.emailController.text,
    );
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
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
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
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: _mockupInputDecoration(
                            "alex@vitality.pro",
                            isDark,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F52BA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isDialogLoading
                              ? null
                              : () async {
                                  final email = recoveryEmailController.text
                                      .trim();
                                  if (email.isEmpty || !email.contains('@')) {
                                    setDialogState(() {
                                      errorMessage =
                                          'Please enter a valid email address.';
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    isDialogLoading = true;
                                    errorMessage = '';
                                  });
                                  try {
                                    await AuthService.instance.forgotPassword(
                                      email,
                                    );
                                    setDialogState(() {
                                      currentStep = 1;
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      errorMessage = e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      );
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Send OTP",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                onPressed: isDialogLoading
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          currentStep = 0;
                                          errorMessage = '';
                                        });
                                      },
                                child: Text(
                                  "Back",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F52BA),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: isDialogLoading
                                    ? null
                                    : () async {
                                        final otp = otpController.text.trim();
                                        if (otp.length != 6) {
                                          setDialogState(() {
                                            errorMessage =
                                                'Please enter the 6-digit OTP code.';
                                          });
                                          return;
                                        }
                                        setDialogState(() {
                                          isDialogLoading = true;
                                          errorMessage = '';
                                        });
                                        try {
                                          final token = await AuthService
                                              .instance
                                              .verifyOtp(
                                                recoveryEmailController.text
                                                    .trim(),
                                                otp,
                                              );
                                          setDialogState(() {
                                            resetToken = token;
                                            currentStep = 2;
                                          });
                                        } catch (e) {
                                          setDialogState(() {
                                            errorMessage = e
                                                .toString()
                                                .replaceAll('Exception: ', '');
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
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Verify OTP",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: _mockupInputDecoration(
                            "New password",
                            isDark,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F52BA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isDialogLoading
                              ? null
                              : () async {
                                  final newPass = newPasswordController.text
                                      .trim();
                                  if (newPass.length < 6) {
                                    setDialogState(() {
                                      errorMessage =
                                          'Password must be at least 6 characters.';
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    isDialogLoading = true;
                                    errorMessage = '';
                                  });
                                  try {
                                    await AuthService.instance.resetPassword(
                                      resetToken,
                                      newPass,
                                    );
                                    setDialogState(() {
                                      currentStep = 3;
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      errorMessage = e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      );
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Reset Password",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            recoveryEmailController.dispose();
                            otpController.dispose();
                            newPasswordController.dispose();
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            "Done",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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

  Widget _buildPasswordIndicator(bool isDark) {
    final isFocused = _passwordFocusNode.hasFocus;

    if (widget.passwordController.text.isEmpty && !isFocused) {
      return const SizedBox.shrink();
    }

    final score = _strengthScore;
    Color strengthColor;
    String strengthText;

    if (score <= 2) {
      strengthColor = Colors.redAccent;
      strengthText = "Weak Security";
    } else if (score <= 4) {
      strengthColor = Colors.amber;
      strengthText = "Medium Strength";
    } else {
      strengthColor = Colors.greenAccent;
      strengthText = "Strong Password";
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.02)
              : Colors.black.withOpacity(0.015),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row with rating & status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      score == 5
                          ? Icons.verified_user
                          : Icons.gpp_maybe_outlined,
                      size: 15,
                      color: strengthColor,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "PASSWORD ADVISOR",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: strengthColor,
                  ),
                  child: Text(strengthText),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Segmented Progress Bar (5 bars)
            Row(
              children: List.generate(5, (index) {
                final isLit = index < score;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : 4,
                      right: index == 4 ? 0 : 4,
                    ),
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isLit
                          ? strengthColor
                          : (isDark ? Colors.white10 : Colors.black12),
                      boxShadow: isLit
                          ? [
                              BoxShadow(
                                color: strengthColor.withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Grid of requirements (2 columns for clean layout)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildRequirementRow(
                        "8+ Characters",
                        _hasMinLength,
                        Icons.straighten,
                        isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildRequirementRow(
                        "Uppercase Letter",
                        _hasUppercase,
                        Icons.title,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildRequirementRow(
                        "Lowercase Letter",
                        _hasLowercase,
                        Icons.text_fields,
                        isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildRequirementRow(
                        "Numeric Digit",
                        _hasNumber,
                        Icons.numbers,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildRequirementRow(
                        "Special Symbol",
                        _hasSpecialChar,
                        Icons.alternate_email,
                        isDark,
                      ),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementRow(
    String label,
    bool isMet,
    IconData icon,
    bool isDark,
  ) {
    final activeColor = isMet
        ? Colors.greenAccent
        : (isDark ? Colors.white30 : Colors.black38);
    final textStyle = TextStyle(
      fontSize: 11,
      fontWeight: isMet ? FontWeight.bold : FontWeight.w500,
      color: isMet
          ? (isDark ? Colors.white : Colors.black87)
          : (isDark ? Colors.white30 : Colors.black38),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMet
                ? Colors.greenAccent.withOpacity(isDark ? 0.15 : 0.2)
                : Colors.transparent,
            border: Border.all(
              color: isMet
                  ? Colors.greenAccent.withOpacity(0.5)
                  : (isDark ? Colors.white10 : Colors.black12),
              width: 1.0,
            ),
          ),
          child: Icon(icon, size: 13, color: activeColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: textStyle,
            child: Text(label),
          ),
        ),
      ],
    );
  }
}
