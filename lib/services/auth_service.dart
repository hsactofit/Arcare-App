import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Gets the currently authenticated user, if any.
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Google Sign-In & Firebase Auth (google_sign_in 7.0.0+ compatible)
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-in flow (v7.0.0+ uses authenticate())
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate();
      if (googleUser == null) {
        // User cancelled the sign-in flow
        return null;
      }

      // Obtain auth details (tokens)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a credential for Firebase (v7.0.0+ only requires idToken)
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Authenticate with Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (e) {
      print("Google Authentication error: $e");
      rethrow;
    }
  }

  /// Apple Sign-In & Firebase Auth
  Future<User?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final sha256Nonce = _sha256ofString(rawNonce);

      // Request Apple ID Authorization
      final appleIdCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256Nonce,
      );

      // Create Firebase credential
      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleIdCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Authenticate with Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      // Apple only returns name metadata on the first signup.
      // If it exists, let's update the Firebase user profile display name.
      if (user != null) {
        String? displayName;
        if (appleIdCredential.givenName != null) {
          displayName = appleIdCredential.givenName;
          if (appleIdCredential.familyName != null) {
            displayName = "$displayName ${appleIdCredential.familyName}";
          }
        }
        if (displayName != null &&
            (user.displayName == null || user.displayName!.isEmpty)) {
          await user.updateDisplayName(displayName);
          await user.reload();
        }
      }

      return _auth.currentUser;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User cancelled the sign-in flow
        return null;
      }
      rethrow;
    } catch (e) {
      print("Apple Authentication error: $e");
      rethrow;
    }
  }

  // JWT tokens cache keys
  static const String _accessTokenKey = 'jwt_access_token';
  static const String _refreshTokenKey = 'jwt_refresh_token';

  // Getters for tokens
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  // Base API URL
  static const String apiBaseUrl = 'http://api.prabhash.site';

  // Signup API
  Future<Map<String, dynamic>> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          'provider': 'email',
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        if (accessToken != null && refreshToken != null) {
          await _saveTokens(accessToken, refreshToken);
        }
        return data;
      } else {
        final errorMsg = _extractErrorMessage(data);
        throw AuthException(errorMsg);
      }
    } catch (e) {
      print("SignUp API error: $e");
      rethrow;
    }
  }

  // Login API
  Future<Map<String, dynamic>> loginWithEmail(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        if (accessToken != null && refreshToken != null) {
          await _saveTokens(accessToken, refreshToken);
        }
        return data;
      } else {
        final errorMsg = _extractErrorMessage(data);
        throw AuthException(errorMsg);
      }
    } catch (e) {
      print("Login API error: $e");
      rethrow;
    }
  }

  // Refresh Tokens / Validate Session API
  Future<Map<String, dynamic>> refreshSessionToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        throw AuthException("No refresh token found");
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final accessToken = data['access_token'];
        final newRefreshToken = data['refresh_token'];
        if (accessToken != null && newRefreshToken != null) {
          await _saveTokens(accessToken, newRefreshToken);
        }
        return data;
      } else {
        await _clearTokens();
        final errorMsg = _extractErrorMessage(data);
        throw AuthException(errorMsg);
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      print("Token Refresh API connection error: $e");
      // Do NOT clear tokens on network/connection errors to preserve persistence
      rethrow;
    }
  }

  // Request OTP for password recovery
  Future<String> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['message'] ?? 'OTP sent to email';
      } else {
        final errorMsg = _extractErrorMessage(data);
        throw Exception(errorMsg);
      }
    } catch (e) {
      print("Forgot Password API error: $e");
      rethrow;
    }
  }

  // Verify OTP code to obtain Reset Token
  Future<String> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final resetToken = data['reset_token'];
        if (resetToken == null) {
          throw Exception("Reset token not found in response");
        }
        return resetToken;
      } else {
        final errorMsg = _extractErrorMessage(data);
        throw Exception(errorMsg);
      }
    } catch (e) {
      print("Verify OTP API error: $e");
      rethrow;
    }
  }

  // Reset Password using reset token
  Future<String> resetPassword(String resetToken, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reset_token': resetToken,
          'new_password': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['message'] ?? 'Password reset successful';
      } else {
        final errorMsg = _extractErrorMessage(data);
        throw Exception(errorMsg);
      }
    } catch (e) {
      print("Reset Password API error: $e");
      rethrow;
    }
  }

  // Social Auth API backend linking
  Future<Map<String, dynamic>> socialLoginBackend(
    String provider,
    String token, {
    String? name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/social-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': provider.toLowerCase(),
          'token': token,
          'name': name,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        if (accessToken != null && refreshToken != null) {
          await _saveTokens(accessToken, refreshToken);
        }
        return data;
      } else {
        final errorMsg = _extractErrorMessage(data);
        throw AuthException(errorMsg);
      }
    } catch (e) {
      print("Social Login API error: $e");
      rethrow;
    }
  }

  // Submit Onboarding API
  Future<void> submitOnboarding(Map<String, dynamic> payload) async {
    try {
      final token = await getAccessToken();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/onboarding'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final data = jsonDecode(response.body);
        throw Exception(_extractErrorMessage(data));
      }
    } catch (e) {
      print("Submit onboarding API error: $e");
      rethrow;
    }
  }

  // Helper to extract error message from API response (specifically FastAPI ValidationError)
  String _extractErrorMessage(dynamic data) {
    if (data is Map) {
      if (data['detail'] != null) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final firstErr = detail[0];
          if (firstErr is Map && firstErr['msg'] != null) {
            return firstErr['msg'].toString();
          }
        }
      }
      if (data['message'] != null) {
        return data['message'].toString();
      }
    }
    return 'An unknown server error occurred.';
  }

  /// Sign out from Firebase, Google Sign-In, and clear backend tokens
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      print("Error disconnecting Google Sign-In: $e");
    }
    await _clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed');
    await prefs.remove('onboarding_data');
    await prefs.remove('healthSetupCompleted');
    await prefs.remove('healthConnectRequested');
  }

  /// Helper to generate a random cryptographically secure string (nonce)
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Helper to hash a string using SHA-256
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
