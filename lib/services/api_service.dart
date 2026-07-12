import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import '../screens/challenges_screen.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  static const String baseUrl = AuthService.apiBaseUrl;

  /// Helper to get authorization headers.
  Future<Map<String, String>> _getHeaders({String? token}) async {
    final t = token ?? await AuthService.instance.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  /// Helper to make authenticated GET requests with automatic token refresh.
  Future<http.Response> _get(String path, {Map<String, String>? queryParams}) async {
    final token = await AuthService.instance.getAccessToken();
    Uri uri = Uri.parse('$baseUrl$path');
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }

    var response = await http.get(uri, headers: await _getHeaders(token: token));

    if (response.statusCode == 401) {
      await AuthService.instance.refreshSessionToken();
      final newToken = await AuthService.instance.getAccessToken();
      response = await http.get(uri, headers: await _getHeaders(token: newToken));
    }
    return response;
  }

  /// Fetch user's email from onboarding state.
  Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('onboarding_data');
    if (jsonStr != null) {
      try {
        final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
        final email = onboarding['auth']?['email'];
        if (email != null) {
          return email;
        }
      } catch (_) {}
    }
    return "testuser@arcar.com";
  }

  /// GET /api/health/data/{email} (Trends Data)
  Future<List<Map<String, dynamic>>> fetchTrends(String email, String period) async {
    final periodParam = period.toLowerCase() == 'daily'
        ? 'days'
        : period.toLowerCase() == 'weekly'
            ? 'weeks'
            : 'month';

    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get(
      '/api/health/data/$encodedEmail',
      queryParams: {'period': periodParam},
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      throw Exception("Failed to load trends data: ${response.statusCode}");
    }
  }

  /// GET /api/health/trends/{email} (Health Trends Data)
  Future<Map<String, dynamic>> fetchProgressTrends(String email, String period) async {
    final periodParam = period.toLowerCase(); // 'daily', 'weekly', 'monthly'
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get(
      '/api/health/trends/$encodedEmail',
      queryParams: {'period': periodParam},
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception("Failed to load progress trends: ${response.statusCode}");
    }
  }

  /// GET /api/health/graph/{email} (Graph data)
  Future<Map<String, dynamic>> fetchGraphData({
    required String email,
    required String metric,
    required String period,
    required String title,
  }) async {
    final encodedEmail = Uri.encodeComponent(email);
    
    // Normalize metric Param
    String metricParam = metric.toLowerCase();
    if (metricParam == 'fitness') {
      metricParam = 'workouts';
    }

    const allowedMetrics = [
      'steps', 'calories', 'sleep', 'sleep_duration_hours',
      'water', 'water_intake_ml', 'workouts', 'workouts_count',
      'heart_rate', 'heart_rate_bpm'
    ];

    if (!allowedMetrics.contains(metricParam)) {
      final titleLower = title.toLowerCase();
      if (titleLower.contains('step')) {
        metricParam = 'steps';
      } else if (titleLower.contains('water') || titleLower.contains('hydrat')) {
        metricParam = 'water';
      } else if (titleLower.contains('sleep')) {
        metricParam = 'sleep';
      } else if (titleLower.contains('calor') || titleLower.contains('burn')) {
        metricParam = 'calories';
      } else if (titleLower.contains('workout') || titleLower.contains('gym') || titleLower.contains('exercis')) {
        metricParam = 'workouts';
      } else if (titleLower.contains('heart') || titleLower.contains('pulse')) {
        metricParam = 'heart_rate';
      } else {
        metricParam = 'steps';
      }
    }

    final response = await _get(
      '/api/health/graph/$encodedEmail',
      queryParams: {
        'metric': metricParam,
        'period': period,
      },
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception("Failed to load graph data: ${response.statusCode}");
    }
  }

  /// GET /api/challenges (Active & Joined challenges)
  Future<List<Challenge>> fetchActiveChallenges() async {
    final response = await _get('/api/challenges');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      final parsed = list.map((item) => Challenge.fromJson(item)).toList();
      return parsed.where((c) => c.isJoined).toList();
    } else {
      throw Exception("Failed to fetch challenges: ${response.statusCode}");
    }
  }
}
