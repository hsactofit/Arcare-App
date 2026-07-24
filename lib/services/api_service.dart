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

  /// Helper to make authenticated POST requests with automatic token refresh.
  Future<http.Response> _post(String path, {Object? body}) async {
    final token = await AuthService.instance.getAccessToken();
    final uri = Uri.parse('$baseUrl$path');

    var response = await http.post(uri,
        headers: await _getHeaders(token: token),
        body: body != null ? jsonEncode(body) : null);

    if (response.statusCode == 401) {
      await AuthService.instance.refreshSessionToken();
      final newToken = await AuthService.instance.getAccessToken();
      response = await http.post(uri,
          headers: await _getHeaders(token: newToken),
          body: body != null ? jsonEncode(body) : null);
    }
    return response;
  }

  /// Helper to make authenticated PUT requests with automatic token refresh.
  Future<http.Response> _put(String path, {Object? body}) async {
    final token = await AuthService.instance.getAccessToken();
    final uri = Uri.parse('$baseUrl$path');

    var response = await http.put(uri,
        headers: await _getHeaders(token: token),
        body: body != null ? jsonEncode(body) : null);

    if (response.statusCode == 401) {
      await AuthService.instance.refreshSessionToken();
      final newToken = await AuthService.instance.getAccessToken();
      response = await http.put(uri,
          headers: await _getHeaders(token: newToken),
          body: body != null ? jsonEncode(body) : null);
    }
    return response;
  }

  /// Helper to make authenticated DELETE requests with automatic token refresh.
  Future<http.Response> _delete(String path) async {
    final token = await AuthService.instance.getAccessToken();
    final uri = Uri.parse('$baseUrl$path');

    var response =
        await http.delete(uri, headers: await _getHeaders(token: token));

    if (response.statusCode == 401) {
      await AuthService.instance.refreshSessionToken();
      final newToken = await AuthService.instance.getAccessToken();
      response =
          await http.delete(uri, headers: await _getHeaders(token: newToken));
    }
    return response;
  }

  /// Fetch the signed-in user's email (onboarding data → prefs → Firebase).
  Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonStr = prefs.getString('onboarding_data');
    if (jsonStr != null) {
      try {
        final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
        final email = onboarding['auth']?['email']?.toString().trim();
        if (email != null && email.isNotEmpty) {
          return email;
        }
      } catch (_) {}
    }

    final storedEmail = prefs.getString('user_email')?.trim();
    if (storedEmail != null && storedEmail.isNotEmpty) {
      return storedEmail;
    }

    final firebaseEmail = AuthService.instance.currentUser?.email?.trim();
    if (firebaseEmail != null && firebaseEmail.isNotEmpty) {
      return firebaseEmail;
    }

    throw Exception('User email not found. Please sign in again.');
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

  // ── Hydration / Water API ──────────────────────────────────────

  /// GET /api/water/logs/{email}
  Future<Map<String, dynamic>> fetchWaterLogs(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/water/logs/$encodedEmail');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw Exception('Unexpected water logs response format');
    }
    throw Exception(
        "Failed to load water logs: ${response.statusCode} - ${response.body}");
  }

  /// POST /api/water/log/{email}
  /// body: { amount: int, timestamp?: ISO date-time }
  Future<Map<String, dynamic>> addWaterLog(
      String email, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _post('/api/water/log/$encodedEmail', body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw Exception('Unexpected add water log response format');
    }
    throw Exception(
        "Failed to add water log: ${response.statusCode} - ${response.body}");
  }

  /// PUT /api/water/log/{logId}
  Future<Map<String, dynamic>> updateWaterLog(
      int logId, Map<String, dynamic> body) async {
    final response = await _put('/api/water/log/$logId', body: body);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw Exception('Unexpected update water log response format');
    }
    throw Exception(
        "Failed to update water log: ${response.statusCode} - ${response.body}");
  }

  /// DELETE /api/water/log/{logId}
  Future<void> deleteWaterLog(int logId) async {
    final response = await _delete('/api/water/log/$logId');

    if (response.statusCode != 200) {
      throw Exception(
          "Failed to delete water log: ${response.statusCode} - ${response.body}");
    }
  }

  /// GET /api/water/graph/{email}?period=
  /// period: day | week | month
  Future<Map<String, dynamic>> fetchWaterGraph(
      String email, String period) async {
    final encodedEmail = Uri.encodeComponent(email);
    final periodParam = switch (period.toLowerCase()) {
      'days' || 'daily' => 'day',
      'weeks' || 'weekly' => 'week',
      'months' || 'monthly' => 'month',
      _ => period.toLowerCase(),
    };

    final response = await _get(
      '/api/water/graph/$encodedEmail',
      queryParams: {'period': periodParam},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List) {
        return {'period': periodParam, 'data': decoded};
      }
      throw Exception('Unexpected water graph response format');
    }
    throw Exception(
        "Failed to load water graph: ${response.statusCode} - ${response.body}");
  }

  // ── Nutrition API ──────────────────────────────────────────────

  /// GET /api/nutrition/logs/{email}
  Future<Map<String, dynamic>> fetchNutritionLogs(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/nutrition/logs/$encodedEmail');

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to load nutrition logs: ${response.statusCode} - ${response.body}");
    }
  }

  /// POST /api/nutrition/log/{email}
  Future<Map<String, dynamic>> addNutritionLog(
      String email, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _post('/api/nutrition/log/$encodedEmail', body: body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to add nutrition log: ${response.statusCode} - ${response.body}");
    }
  }

  /// PUT /api/nutrition/log/{logId}
  Future<Map<String, dynamic>> updateNutritionLog(
      int logId, Map<String, dynamic> body) async {
    final response = await _put('/api/nutrition/log/$logId', body: body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to update nutrition log: ${response.statusCode} - ${response.body}");
    }
  }

  /// DELETE /api/nutrition/log/{logId}
  Future<void> deleteNutritionLog(int logId) async {
    final response = await _delete('/api/nutrition/log/$logId');

    if (response.statusCode != 200) {
      throw Exception(
          "Failed to delete nutrition log: ${response.statusCode} - ${response.body}");
    }
  }

  /// GET /api/nutrition/graph/{email}?period=
  /// period: day | week | month
  Future<Map<String, dynamic>> fetchNutritionGraph(
      String email, String period) async {
    final encodedEmail = Uri.encodeComponent(email);
    // Normalize period aliases the backend might accept
    final periodParam = switch (period.toLowerCase()) {
      'days' || 'daily' => 'day',
      'weeks' || 'weekly' => 'week',
      'months' || 'monthly' => 'month',
      _ => period.toLowerCase(),
    };

    final response = await _get(
      '/api/nutrition/graph/$encodedEmail',
      queryParams: {'period': periodParam},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      // Unexpected list-only payload
      if (decoded is List) {
        return {'period': periodParam, 'data': decoded};
      }
      throw Exception('Unexpected nutrition graph response format');
    } else {
      throw Exception(
          "Failed to load nutrition graph: ${response.statusCode} - ${response.body}");
    }
  }

  /// GET /api/profile
  Future<Map<String, dynamic>> fetchUserProfile() async {
    final response = await _get('/api/profile');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception("Failed to load user profile: ${response.statusCode}");
    }
  }

  /// PUT /api/profile
  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> body) async {
    final response = await _put('/api/profile', body: body);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception("Failed to update user profile: ${response.statusCode}");
    }
  }

  /// POST /api/dashboard/sync/{email}
  Future<Map<String, dynamic>> syncDashboard(String email, List<Map<String, dynamic>> dailyRecords) async {
    final response = await _post('/api/dashboard/sync/${Uri.encodeComponent(email)}', body: dailyRecords);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception("Failed to sync dashboard: ${response.statusCode} - ${response.body}");
    }
  }

  /// GET /api/dashboard/{email}
  Future<Map<String, dynamic>> getDashboard(String email) async {
    final response = await _get('/api/dashboard/${Uri.encodeComponent(email)}');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception("Failed to get dashboard: ${response.statusCode} - ${response.body}");
    }
  }

  // ── SOS & Emergency API ────────────────────────────────────────

  /// GET /api/sos/{email} — full SOS setup (contacts + emergency numbers)
  Future<Map<String, dynamic>> getSos(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/sos/$encodedEmail');

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to load SOS data: ${response.statusCode} - ${response.body}");
    }
  }

  /// GET /api/sos/contacts/{email}
  Future<Map<String, dynamic>> listSosContacts(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/sos/contacts/$encodedEmail');

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to list SOS contacts: ${response.statusCode} - ${response.body}");
    }
  }

  /// POST /api/sos/contacts/{email}
  Future<Map<String, dynamic>> createSosContact(
      String email, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _post('/api/sos/contacts/$encodedEmail', body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to create SOS contact: ${response.statusCode} - ${response.body}");
    }
  }

  /// PUT /api/sos/contacts/{contactId}
  Future<Map<String, dynamic>> updateSosContact(
      int contactId, Map<String, dynamic> body) async {
    final response = await _put('/api/sos/contacts/$contactId', body: body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to update SOS contact: ${response.statusCode} - ${response.body}");
    }
  }

  /// DELETE /api/sos/contacts/{contactId}
  Future<void> deleteSosContact(int contactId) async {
    final response = await _delete('/api/sos/contacts/$contactId');

    if (response.statusCode != 200) {
      throw Exception(
          "Failed to delete SOS contact: ${response.statusCode} - ${response.body}");
    }
  }

  /// GET /api/sos/emergency/{email}
  Future<Map<String, dynamic>> getEmergencyNumbers(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/sos/emergency/$encodedEmail');

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to load emergency numbers: ${response.statusCode} - ${response.body}");
    }
  }

  /// PUT /api/sos/emergency/{email}
  Future<Map<String, dynamic>> updateEmergencyNumbers(
      String email, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _put('/api/sos/emergency/$encodedEmail', body: body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to update emergency numbers: ${response.statusCode} - ${response.body}");
    }
  }

  /// DELETE /api/sos/emergency/{email} — reset to defaults (112 / 102 / 101)
  Future<Map<String, dynamic>> resetEmergencyNumbers(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _delete('/api/sos/emergency/$encodedEmail');

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to reset emergency numbers: ${response.statusCode} - ${response.body}");
    }
  }

  /// POST /api/sos/trigger/{email}
  Future<Map<String, dynamic>> triggerSos(
    String email, {
    double? latitude,
    double? longitude,
  }) async {
    final encodedEmail = Uri.encodeComponent(email);
    final body = <String, dynamic>{
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    final response =
        await _post('/api/sos/trigger/$encodedEmail', body: body);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception(
          "Failed to trigger SOS: ${response.statusCode} - ${response.body}");
    }
  }

  // ── Workout Plans API ──────────────────────────────────────────

  /// GET /api/workout/{email}
  Future<Map<String, dynamic>> listWorkoutPlans(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/workout/$encodedEmail');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to list workout plans: ${response.statusCode} - ${response.body}");
  }

  /// POST /api/workout/{email}
  Future<Map<String, dynamic>> createWorkoutPlan(
      String email, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _post('/api/workout/$encodedEmail', body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to create workout plan: ${response.statusCode} - ${response.body}");
  }

  /// POST /api/workout/generate/{email}
  Future<Map<String, dynamic>> generateWorkoutPlan(
      String email, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _post('/api/workout/generate/$encodedEmail', body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to generate workout plan: ${response.statusCode} - ${response.body}");
  }

  /// GET /api/workout/{email}/day/{onDate}
  Future<Map<String, dynamic>?> getWorkoutForDay(
      String email, String onDate) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/workout/$encodedEmail/day/$onDate');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    if (response.statusCode == 404) return null;
    throw Exception(
        "Failed to load workout for day: ${response.statusCode} - ${response.body}");
  }

  /// GET /api/workout/{email}/{planId}
  Future<Map<String, dynamic>> getWorkoutPlan(
      String email, int planId) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/workout/$encodedEmail/$planId');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to load workout plan: ${response.statusCode} - ${response.body}");
  }

  /// PUT /api/workout/{email}/{planId}
  Future<Map<String, dynamic>> updateWorkoutPlan(
      String email, int planId, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _put('/api/workout/$encodedEmail/$planId', body: body);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to update workout plan: ${response.statusCode} - ${response.body}");
  }

  /// DELETE /api/workout/{email}/{planId}
  Future<void> deleteWorkoutPlan(String email, int planId) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _delete('/api/workout/$encodedEmail/$planId');
    if (response.statusCode != 200) {
      throw Exception(
          "Failed to delete workout plan: ${response.statusCode} - ${response.body}");
    }
  }

  // ── Nutrition Plans API ────────────────────────────────────────

  /// GET /api/nutrition-plan/{email}
  Future<Map<String, dynamic>> listNutritionPlans(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/nutrition-plan/$encodedEmail');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to list nutrition plans: ${response.statusCode} - ${response.body}");
  }

  /// POST /api/nutrition-plan/{email}
  Future<Map<String, dynamic>> createNutritionPlan(
      String email, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _post('/api/nutrition-plan/$encodedEmail', body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to create nutrition plan: ${response.statusCode} - ${response.body}");
  }

  /// POST /api/nutrition-plan/generate/{email}
  Future<Map<String, dynamic>> generateNutritionPlan(
      String email, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _post('/api/nutrition-plan/generate/$encodedEmail', body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to generate nutrition plan: ${response.statusCode} - ${response.body}");
  }

  /// GET /api/nutrition-plan/{email}/day/{onDate}
  Future<Map<String, dynamic>?> getNutritionForDay(
      String email, String onDate) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _get('/api/nutrition-plan/$encodedEmail/day/$onDate');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    if (response.statusCode == 404) return null;
    throw Exception(
        "Failed to load nutrition for day: ${response.statusCode} - ${response.body}");
  }

  /// GET /api/nutrition-plan/{email}/{planId}
  Future<Map<String, dynamic>> getNutritionPlan(
      String email, int planId) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get('/api/nutrition-plan/$encodedEmail/$planId');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to load nutrition plan: ${response.statusCode} - ${response.body}");
  }

  /// PUT /api/nutrition-plan/{email}/{planId}
  Future<Map<String, dynamic>> updateNutritionPlan(
      String email, int planId, Map<String, dynamic> body) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _put('/api/nutrition-plan/$encodedEmail/$planId', body: body);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to update nutrition plan: ${response.statusCode} - ${response.body}");
  }

  /// DELETE /api/nutrition-plan/{email}/{planId}
  Future<void> deleteNutritionPlan(String email, int planId) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _delete('/api/nutrition-plan/$encodedEmail/$planId');
    if (response.statusCode != 200) {
      throw Exception(
          "Failed to delete nutrition plan: ${response.statusCode} - ${response.body}");
    }
  }

  // ─── Health Chatbot ───────────────────────────────────────────────────────

  /// POST /api/chatbot/{email}
  ///
  /// Sends a message to the health coach. Pass [conversationId] to continue a
  /// thread, or set [newConversation] to start a fresh one.
  Future<Map<String, dynamic>> sendChatMessage({
    required String email,
    required String message,
    int? conversationId,
    bool newConversation = false,
  }) async {
    final encodedEmail = Uri.encodeComponent(email);
    final body = <String, dynamic>{
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
      if (newConversation) 'new_conversation': true,
    };
    final response = await _post('/api/chatbot/$encodedEmail', body: body);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Chat failed: ${response.statusCode} - ${response.body}");
  }

  /// GET /api/chatbot/{email}/conversations
  Future<Map<String, dynamic>> listChatConversations(
    String email, {
    int limit = 20,
  }) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get(
      '/api/chatbot/$encodedEmail/conversations',
      queryParams: {'limit': limit.toString()},
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to list conversations: ${response.statusCode} - ${response.body}");
  }

  /// GET /api/chatbot/{email}/conversations/{conversationId}
  Future<Map<String, dynamic>> getChatHistory(
    String email,
    int conversationId, {
    int limit = 100,
  }) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _get(
      '/api/chatbot/$encodedEmail/conversations/$conversationId',
      queryParams: {'limit': limit.toString()},
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception(
        "Failed to load chat history: ${response.statusCode} - ${response.body}");
  }

  /// DELETE /api/chatbot/{email}/conversations/{conversationId}
  Future<void> deleteChatConversation(String email, int conversationId) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _delete(
        '/api/chatbot/$encodedEmail/conversations/$conversationId');
    if (response.statusCode != 200) {
      throw Exception(
          "Failed to delete conversation: ${response.statusCode} - ${response.body}");
    }
  }

  /// DELETE /api/chatbot/{email}/conversations
  Future<void> clearAllChatConversations(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final response =
        await _delete('/api/chatbot/$encodedEmail/conversations');
    if (response.statusCode != 200) {
      throw Exception(
          "Failed to clear conversations: ${response.statusCode} - ${response.body}");
    }
  }
}
