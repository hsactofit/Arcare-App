import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/concentric_rings_chart.dart';
import '../widgets/medical/medical_records_section.dart';
import '../widgets/medical/medical_consent_sheet.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'onboarding_screen.dart';
import 'water_logging_screen.dart';
import 'metric_detail_screen.dart';
import 'gym_checkin_screen.dart';
import 'challenges_screen.dart';
import 'nutrition_logging_screen.dart';
import '../widgets/water/wave_painter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _waterWaveController;
  final List<BubbleParticle> _waterBubbles = [];
  final Random _random = Random();

  HealthConnectSdkStatus? _sdkStatus;
  bool _isConnected = false;
  bool _isSyncing = false;
  HealthData _healthData = HealthData();
  DateTime? _lastSynced;
  String _userName = "User";

  // Custom goals
  double _stepGoal = 10000.0;
  double _waterGoal = 2500.0;
  double _calorieGoal = 600.0;
  double _exerciseGoal = 60.0;
  double _sleepGoal = 8.0;

  // Onboarding & Setup States
  bool _healthSetupCompleted = false;
  bool _healthConnectRequested = false;
  bool _showGuide = false;
  bool _dismissedSetupCard = false;

  // Server-synced states
  int? _serverWellnessScore;
  String? _serverDailySummary;
  List<String> _serverRecommendations = [];
  int? _activeSubscore;
  int? _sleepSubscore;
  int? _nutritionSubscore;
  int? _mindfulnessSubscore;
  Future<List<Map<String, dynamic>>>? _dailyRecordsFuture;

  // Gym Check-in tracking fields
  bool _gymCheckedIn = false;
  String? _gymName;
  String? _gymPlace;
  DateTime? _gymCheckInTime;
  Timer? _gymTimer;
  Duration _gymElapsed = Duration.zero;
  bool _gymDoneToday = false;

  // User email & active challenges
  String _userEmail = "";
  List<Challenge> _activeChallenges = [];

  // Custom API metrics
  double? _apiCaloriesValue;
  double? _apiCaloriesTarget;
  String? _apiCaloriesStatus;

  double? _apiSleepValue;
  double? _apiSleepTarget;
  String? _apiSleepStatus;

  double? _apiHeartRateValue;
  double? _apiHeartRateTarget;
  String? _apiHeartRateStatus;

  ScrollController? _activeGoalsScrollController;
  Timer? _activeGoalsScrollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSetupState();
    _loadGymState();
    _dailyRecordsFuture = HealthService.instance.fetchDailyHealthDataForPeriod(
      days: 7,
    );
    _checkStatusAndSync();

    _waterWaveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    for (int i = 0; i < 15; i++) {
      _waterBubbles.add(
        BubbleParticle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          radius: 1.5 + _random.nextDouble() * 3.0,
          speed: 0.002 + _random.nextDouble() * 0.003,
        ),
      );
    }
    _waterWaveController.addListener(_updateWaterBubbles);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gymTimer?.cancel();
    _activeGoalsScrollTimer?.cancel();
    _activeGoalsScrollController?.dispose();
    _waterWaveController.removeListener(_updateWaterBubbles);
    _waterWaveController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("App resumed: fetching fresh dashboard metrics");
      _fetchRealData(forceSync: true);
    }
  }

  void _updateWaterBubbles() {
    if (!mounted) return;
    final progress = (_healthData.waterIntake / _waterGoal).clamp(0.0, 1.0);
    setState(() {
      for (var bubble in _waterBubbles) {
        bubble.y -= bubble.speed;
        bubble.x +=
            sin(_waterWaveController.value * 2 * pi + bubble.y * 10) * 0.002;

        final double waterTopY = 1.0 - progress;
        if (bubble.y < waterTopY || bubble.x < 0 || bubble.x > 1) {
          bubble.y = 1.0;
          bubble.x = _random.nextDouble();
        }
      }
    });
  }

  Future<void> _loadGymState() async {
    final prefs = await SharedPreferences.getInstance();
    final isCheckedIn = prefs.getBool('gym_checked_in') ?? false;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final gymDoneTodayDate = prefs.getString('gym_done_today_date');
    final gymDoneToday = gymDoneTodayDate == todayStr;

    setState(() {
      _gymCheckedIn = isCheckedIn;
      _gymDoneToday = gymDoneToday;
      if (isCheckedIn) {
        _gymName = prefs.getString('gym_name');
        _gymPlace = prefs.getString('gym_place');
        final timeStr = prefs.getString('gym_check_in_time');
        _gymCheckInTime = timeStr != null ? DateTime.tryParse(timeStr) : null;
      } else {
        _gymName = null;
        _gymPlace = null;
        _gymCheckInTime = null;
        _gymElapsed = Duration.zero;
      }
    });

    if (isCheckedIn) {
      _startGymTimer();
    } else {
      _gymTimer?.cancel();
    }
    _updateAutoScrollState();
  }

  void _startGymTimer() {
    _gymTimer?.cancel();
    if (_gymCheckInTime == null) return;
    _gymTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _gymElapsed = DateTime.now().difference(_gymCheckInTime!);
      });
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  void _updateAutoScrollState() {
    if (!mounted) return;

    final hasActiveGymChallenge = _activeChallenges.any(
      (c) =>
          c.metricType == 'workouts' ||
          c.title.toLowerCase().contains('gym') ||
          c.title.toLowerCase().contains('workout'),
    );

    final isGymCompletedToday = _activeChallenges.any(
      (c) =>
          (c.metricType == 'workouts' ||
              c.title.toLowerCase().contains('gym') ||
              c.title.toLowerCase().contains('workout')) &&
          c.completedToday,
    );

    bool showGymCheckinCard = false;
    if (_gymCheckedIn) {
      showGymCheckinCard = true;
    } else if (!isGymCompletedToday && hasActiveGymChallenge) {
      showGymCheckinCard = true;
    }

    final otherChallengesCount = _activeChallenges.where((c) {
      final isGym =
          c.metricType == 'workouts' ||
          c.title.toLowerCase().contains('gym') ||
          c.title.toLowerCase().contains('workout');
      if (isGym && isGymCompletedToday) {
        return false;
      }
      return true;
    }).length;

    final totalItems = (showGymCheckinCard ? 1 : 0) + otherChallengesCount;
    _startActiveGoalsAutoScroll(totalItems);
  }

  void _startActiveGoalsAutoScroll(int itemCount) {
    _activeGoalsScrollTimer?.cancel();
    if (itemCount <= 1) {
      _activeGoalsScrollController?.dispose();
      _activeGoalsScrollController = null;
      return;
    }

    _activeGoalsScrollController ??= ScrollController();

    _activeGoalsScrollTimer = Timer.periodic(const Duration(seconds: 4), (
      timer,
    ) {
      if (!mounted ||
          _activeGoalsScrollController == null ||
          !_activeGoalsScrollController!.hasClients) {
        return;
      }

      final maxScroll = _activeGoalsScrollController!.position.maxScrollExtent;
      final currentScroll = _activeGoalsScrollController!.position.pixels;

      if (maxScroll <= 0) return;

      double targetScroll =
          currentScroll +
          182.0; // scroll by roughly one card width (170 card width + 12 spacing)
      if (currentScroll >= maxScroll - 5.0) {
        targetScroll = 0.0; // jump back to start
      }

      _activeGoalsScrollController!.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _fetchActiveChallenges() async {
    try {
      final active = await ApiService.instance.fetchActiveChallenges();
      setState(() {
        _activeChallenges = active;
      });
      _updateAutoScrollState();
    } catch (e) {
      debugPrint("Error fetching active challenges for dashboard: $e");
    }
  }

  Future<void> _loadSetupState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _healthSetupCompleted = prefs.getBool('healthSetupCompleted') ?? false;
      _healthConnectRequested =
          prefs.getBool('healthConnectRequested') ?? false;
      _dismissedSetupCard = prefs.getBool('dismissedSetupCard') ?? false;
      _userName = prefs.getString('user_name') ?? "User";

      // Load custom goals configuration
      _stepGoal = prefs.getDouble('goal_steps') ?? 10000.0;
      _waterGoal = prefs.getDouble('goal_water') ?? 2500.0;
      _calorieGoal = prefs.getDouble('goal_calories') ?? 600.0;
      _exerciseGoal = prefs.getDouble('goal_exercise') ?? 60.0;
      _sleepGoal = prefs.getDouble('goal_sleep') ?? 8.0;
    });
  }

  Future<void> _setDismissedSetupCard(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dismissedSetupCard', val);
    setState(() {
      _dismissedSetupCard = val;
    });
  }

  Future<void> _setSetupCompleted(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('healthSetupCompleted', val);
    setState(() {
      _healthSetupCompleted = val;
    });
  }

  Future<void> _setConnectRequested(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('healthConnectRequested', val);
    setState(() {
      _healthConnectRequested = val;
    });
  }

  void refreshData() {
    if (mounted) {
      _checkStatusAndSync();
      _fetchActiveChallenges();
      _loadGymState();
    }
  }

  bool get _hasHealthData {
    return _healthData.steps > 0 ||
        _healthData.activeCalories > 0 ||
        _healthData.sleepDuration > 0 ||
        _healthData.distance > 0;
  }

  int get _wellnessScore {
    if (_serverWellnessScore != null) return _serverWellnessScore!;
    double score = 40.0; // base score
    if (_healthData.steps > 0) {
      score += (_healthData.steps / _stepGoal) * 20.0;
    }
    if (_healthData.sleepDuration > 0) {
      score += (_healthData.sleepDuration / _sleepGoal) * 20.0;
    }
    if (_healthData.waterIntake > 0) {
      score += (_healthData.waterIntake / _waterGoal) * 20.0;
    }
    return score.clamp(0, 100).round();
  }

  int get _activeSubscoreValue {
    if (_activeSubscore != null) return _activeSubscore!;
    if (_healthData.steps > 0) {
      return (_healthData.steps / _stepGoal * 100).clamp(0, 100).round();
    }
    return 0;
  }

  int get _sleepSubscoreValue {
    if (_sleepSubscore != null) return _sleepSubscore!;
    if (_healthData.sleepDuration > 0) {
      return (_healthData.sleepDuration / _sleepGoal * 100)
          .clamp(0, 100)
          .round();
    }
    return 0;
  }

  int get _nutritionSubscoreValue {
    if (_nutritionSubscore != null) return _nutritionSubscore!;
    if (_healthData.waterIntake > 0) {
      return (_healthData.waterIntake / _waterGoal * 100).clamp(0, 100).round();
    }
    return 0;
  }

  int get _mindfulnessSubscoreValue {
    if (_mindfulnessSubscore != null) return _mindfulnessSubscore!;
    return 0;
  }

  void _showManualLogDialog(String metric) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Log $metric Manually"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Enter value",
            hintText: metric == "Water"
                ? "ml"
                : (metric == "Weight"
                      ? "kg"
                      : (metric == "Sleep" ? "hours" : "steps")),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0.0;
              if (val > 0) {
                final messenger = ScaffoldMessenger.of(context);
                setState(() {
                  if (metric == "Water") {
                    final int amount = val.round();
                    _healthData = _healthData.copyWith(
                      waterIntake: _healthData.waterIntake + amount.toDouble(),
                    );
                    HealthService.instance.logWater(amount).then((_) {
                      _syncManualWaterToApi(amount);
                    });
                  } else if (metric == "Weight") {
                    _healthData = _healthData.copyWith(weight: val);
                  } else if (metric == "Sleep") {
                    _healthData = _healthData.copyWith(
                      sleepDuration: val,
                      sleepQuality: "Manual Log",
                    );
                  } else if (metric == "Steps") {
                    _healthData = _healthData.copyWith(
                      steps: _healthData.steps + val,
                    );
                  }
                });
                Navigator.pop(context);
                messenger.showSnackBar(
                  SnackBar(content: Text("$metric logged successfully!")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _syncManualWaterToApi(int amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('onboarding_data');
      if (jsonStr != null) {
        final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
        final email = onboarding['auth']?['email'];
        if (email != null) {
          final token = await AuthService.instance.getAccessToken();
          final url =
              '${AuthService.apiBaseUrl}/api/water/log/${Uri.encodeComponent(email)}';
          final now = DateTime.now();

          var response = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'amount': amount,
              'timestamp': now.toIso8601String(),
            }),
          );

          if (response.statusCode == 401) {
            await AuthService.instance.refreshSessionToken();
            final newToken = await AuthService.instance.getAccessToken();
            response = await http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                if (newToken != null) 'Authorization': 'Bearer $newToken',
              },
              body: jsonEncode({
                'amount': amount,
                'timestamp': now.toIso8601String(),
              }),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error syncing manual logged water: $e");
    }
  }

  Future<void> _checkStatusAndSync() async {
    setState(() => _isSyncing = true);

    if (Platform.isAndroid) {
      final status = await HealthService.instance.getAndroidSdkStatus();
      setState(() => _sdkStatus = status);
    }

    await _loadSetupState();

    final prefs = await SharedPreferences.getInstance();
    final bool healthSyncEnabled =
        prefs.getBool('health_sync_enabled') ?? false;

    if (healthSyncEnabled) {
      final hasPerms = await HealthService.instance.checkPermissions();
      setState(() => _isConnected = hasPerms);
      if (hasPerms) {
        await _fetchRealData(forceSync: false);
      } else {
        // Automatically request permissions if enabled but missing
        await _connectHealthServices(showSnackbarOnFailure: false);
      }
    } else {
      setState(() => _isConnected = false);
    }

    setState(() => _isSyncing = false);
  }

  Future<void> _connectHealthServices({
    bool showSnackbarOnFailure = true,
  }) async {
    if (Platform.isAndroid &&
        _sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
      _showDownloadRationaleDialog();
      return;
    }

    setState(() => _isSyncing = true);
    final success = await HealthService.instance.requestPermissions();
    if (!mounted) return;
    setState(() => _isConnected = success);

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('health_sync_enabled', true);
      await _fetchRealData(forceSync: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Successfully connected to health services!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (showSnackbarOnFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Failed to grant health permissions. Please enable them to sync data.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    setState(() => _isSyncing = false);
  }

  Future<void> _fetchRealData({bool forceSync = false}) async {
    setState(() {
      _isSyncing = true;
      _dailyRecordsFuture = HealthService.instance
          .fetchDailyHealthDataForPeriod(days: 7, forceRefresh: forceSync);
    });
    try {
      // 1. Always load the active local Health Connect data to update the UI cards
      var data = await HealthService.instance.fetchHealthData();
      final prefs = await SharedPreferences.getInstance();

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final savedNutriDate = prefs.getString('local_nutrition_date');
      double cachedCal = 0.0;
      double cachedCarbs = 0.0;
      double cachedProtein = 0.0;
      double cachedFat = 0.0;

      if (savedNutriDate == todayStr) {
        cachedCal = prefs.getDouble('cached_nutrition_calories') ?? 0.0;
        cachedCarbs = prefs.getDouble('cached_nutrition_carbs') ?? 0.0;
        cachedProtein = prefs.getDouble('cached_nutrition_protein') ?? 0.0;
        cachedFat = prefs.getDouble('cached_nutrition_fat') ?? 0.0;
      } else {
        await prefs.setDouble('cached_nutrition_calories', 0.0);
        await prefs.setDouble('cached_nutrition_carbs', 0.0);
        await prefs.setDouble('cached_nutrition_protein', 0.0);
        await prefs.setDouble('cached_nutrition_fat', 0.0);
        await prefs.setString('local_nutrition_date', todayStr);
      }

      data = data.copyWith(
        nutritionCalories: cachedCal,
        carbs: cachedCarbs,
        protein: cachedProtein,
        fat: cachedFat,
      );

      setState(() {
        _healthData = data;
      });

      // 2. Populate states from the local cache immediately for an instant load
      setState(() {
        _serverWellnessScore = prefs.getInt('cached_wellness_score');
        _serverDailySummary = prefs.getString('cached_daily_summary');
        _activeSubscore = prefs.getInt('cached_active_subscore');
        _sleepSubscore = prefs.getInt('cached_sleep_subscore');
        _nutritionSubscore = prefs.getInt('cached_nutrition_subscore');
        _mindfulnessSubscore = prefs.getInt('cached_mindfulness_subscore');
        final cachedRecs = prefs.getStringList('cached_recommendations');
        if (cachedRecs != null) {
          _serverRecommendations = cachedRecs;
        }
        final lastSyncedStr = prefs.getString('last_sync_timestamp');
        if (lastSyncedStr != null) {
          _lastSynced = DateTime.tryParse(lastSyncedStr);
        }
        final localName = prefs.getString('user_name');
        if (localName != null && localName.isNotEmpty) {
          _userName = localName;
        } else {
          final jsonStr = prefs.getString('onboarding_data');
          if (jsonStr != null) {
            final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
            final name = onboarding['auth']?['name'];
            if (name != null && name.isNotEmpty) {
              _userName = name;
            }
          }
        }
        final jsonStr = prefs.getString('onboarding_data');
        if (jsonStr != null) {
          final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
          _userEmail = onboarding['auth']?['email'] ?? "";
        }

        // Load custom API metrics or reset them at midnight
        final savedMetricsDate = prefs.getString('cached_dashboard_metrics_date');
        if (savedMetricsDate == todayStr) {
          _apiCaloriesValue = prefs.getDouble('cached_calories_value');
          _apiCaloriesTarget = prefs.getDouble('cached_calories_target');
          _apiCaloriesStatus = prefs.getString('cached_calories_status');

          _apiSleepValue = prefs.getDouble('cached_sleep_value');
          _apiSleepTarget = prefs.getDouble('cached_sleep_target');
          _apiSleepStatus = prefs.getString('cached_sleep_status');

          _apiHeartRateValue = prefs.getDouble('cached_heart_rate_value');
          _apiHeartRateTarget = prefs.getDouble('cached_heart_rate_target');
          _apiHeartRateStatus = prefs.getString('cached_heart_rate_status');
        } else {
          _apiCaloriesValue = null;
          _apiCaloriesTarget = null;
          _apiCaloriesStatus = null;

          _apiSleepValue = null;
          _apiSleepTarget = null;
          _apiSleepStatus = null;

          _apiHeartRateValue = null;
          _apiHeartRateTarget = null;
          _apiHeartRateStatus = null;

          prefs.remove('cached_calories_value');
          prefs.remove('cached_calories_target');
          prefs.remove('cached_calories_status');

          prefs.remove('cached_sleep_value');
          prefs.remove('cached_sleep_target');
          prefs.remove('cached_sleep_status');

          prefs.remove('cached_heart_rate_value');
          prefs.remove('cached_heart_rate_target');
          prefs.remove('cached_heart_rate_status');

          prefs.setString('cached_dashboard_metrics_date', todayStr);
        }
      });

      // Fetch fresh nutrition from the API and update state/cache
      if (_userEmail.isNotEmpty) {
        try {
          final nutritionResult =
              await ApiService.instance.fetchNutritionLogs(_userEmail);
          final double apiCal =
              (nutritionResult['calories_today'] as num?)?.toDouble() ?? 0.0;
          final double apiCarbs =
              (nutritionResult['carbs_today'] as num?)?.toDouble() ?? 0.0;
          final double apiProtein =
              (nutritionResult['protein_today'] as num?)?.toDouble() ?? 0.0;
          final double apiFat =
              (nutritionResult['fat_today'] as num?)?.toDouble() ?? 0.0;

          setState(() {
            _healthData = _healthData.copyWith(
              nutritionCalories: apiCal,
              carbs: apiCarbs,
              protein: apiProtein,
              fat: apiFat,
            );
          });

          await prefs.setDouble('cached_nutrition_calories', apiCal);
          await prefs.setDouble('cached_nutrition_carbs', apiCarbs);
          await prefs.setDouble('cached_nutrition_protein', apiProtein);
          await prefs.setDouble('cached_nutrition_fat', apiFat);
          await prefs.setString('local_nutrition_date', todayStr);
        } catch (e) {
          debugPrint("Error fetching nutrition from API for dashboard: $e");
        }
      }

      await _fetchActiveChallenges();
      await _loadGymState();

      // 3. Determine if we should perform a backend synchronization
      bool shouldSync = forceSync;
      if (!shouldSync) {
        if (_lastSynced == null) {
          shouldSync = true;
        } else {
          final elapsed = DateTime.now().difference(_lastSynced!);
          if (elapsed.inHours >= 2) {
            shouldSync = true;
          }
        }
      }

      if (shouldSync) {
        final jsonStr = prefs.getString('onboarding_data');
        if (jsonStr != null) {
          final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
          final email = onboarding['auth']?['email'];
          if (email != null) {
            // Fetch daily health data for the last 7 days to sync to backend day-wise
            final syncData = await _dailyRecordsFuture!;
            await _syncAndRefreshDashboard(email, syncData);

            // Re-load local health data so waterIntake from initializeWaterIntakeFromApi is mapped
            final updatedData = await HealthService.instance.fetchHealthData();
            setState(() {
              _healthData = updatedData;
            });
          }
        }
      } else {
        debugPrint(
          "Auto-sync skipped: last sync was less than 2 hours ago (${_lastSynced != null ? DateTime.now().difference(_lastSynced!).inMinutes : 0} mins ago).",
        );
      }
    } catch (e) {
      debugPrint("Error in _fetchRealData combined flow: $e");
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _syncAndRefreshDashboard(
    String email,
    List<Map<String, dynamic>> dailyRecords,
  ) async {
    final future = () async {
      try {
        final token = await AuthService.instance.getAccessToken();
        final prefs = await SharedPreferences.getInstance();

        // Combined Endpoint: Sync Health and retrieve complete dashboard metrics
        final syncUrl =
            '${AuthService.apiBaseUrl}/api/dashboard/sync/${Uri.encodeComponent(email)}';
        final syncPayload = dailyRecords;

        // Debug log the full JSON payload
        debugPrint(
          "================ MERGED HOME SYNC JSON PAYLOAD (LAST 7 DAYS DAILY) ================",
        );
        debugPrint(const JsonEncoder.withIndent('  ').convert(syncPayload));
        debugPrint(
          "===================================================================================",
        );

        final response = await http.post(
          Uri.parse(syncUrl),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(syncPayload),
        );

        // Debug log the full JSON response
        debugPrint(
          "================ MERGED HOME SYNC API RESPONSE ================",
        );
        debugPrint("Status Code: ${response.statusCode}");
        debugPrint("Response Body: ${response.body}");
        debugPrint(
          "=================================================================",
        );

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          final int score = resData['wellness_score'] ?? 75;
          final String summary = resData['daily_summary'] ?? "";
          final List<String> recs = List<String>.from(
            resData['recommendations'] ?? [],
          );
          final String buddyMsg =
              resData['ai_buddy_message'] ?? "Hi! I am your AI Buddy.";
          final int activeSub = resData['active_subscore'] ?? 0;
          final int sleepSub = resData['sleep_subscore'] ?? 0;
          final int nutriSub = resData['nutrition_subscore'] ?? 0;
          final int mindSub = resData['mindfulness_subscore'] ?? 0;
          final int apiWaterToday = resData['water_intake_today'] ?? 0;

          await HealthService.instance.initializeWaterIntakeFromApi(
            apiWaterToday.toDouble(),
          );

          // Extract & Initialize Nutrition macros from dashboard sync response
          final double apiProtein = (resData['protein_today'] as num?)?.toDouble() ?? 0.0;
          final double apiCarbs = (resData['carbs_today'] as num?)?.toDouble() ?? 0.0;
          final double apiFat = (resData['fat_today'] as num?)?.toDouble() ?? 0.0;
          final double apiNutriCal = (resData['calories_today'] as num?)?.toDouble() ?? (apiProtein * 4 + apiCarbs * 4 + apiFat * 9);

          await HealthService.instance.initializeNutritionFromApi(
            apiProtein: apiProtein,
            apiCarbs: apiCarbs,
            apiFat: apiFat,
            apiCalories: apiNutriCal,
          );

          // Parse Custom API Metrics (Calories Burned, Sleep, Heart Rate) from widgets list
          double? parsedCalVal;
          double? parsedCalTarget;
          String? parsedCalStatus;

          double? parsedSleepVal;
          double? parsedSleepTarget;
          String? parsedSleepStatus;

          double? parsedHeartVal;
          double? parsedHeartTarget;
          String? parsedHeartStatus;

          final List<dynamic> widgetsData = resData['widgets'] ?? [];

          // Calories Burned
          final calWidget = widgetsData.firstWhere(
            (w) => w['title'] == 'Calories Burned',
            orElse: () => null,
          );
          if (calWidget != null) {
            parsedCalVal = double.tryParse(calWidget['value']?.toString() ?? '');
            parsedCalTarget = double.tryParse(calWidget['target']?.toString() ?? '');
            parsedCalStatus = calWidget['status']?.toString();
          } else {
            parsedCalVal = (resData['calories_burned_today'] ?? resData['calories_today'] ?? resData['active_calories'])?.toDouble();
            parsedCalTarget = (resData['calories_target'] ?? resData['calorie_goal'])?.toDouble();
            parsedCalStatus = resData['calories_status']?.toString();
          }

          // Sleep Duration
          final sleepWidget = widgetsData.firstWhere(
            (w) => w['title'] == 'Sleep Duration',
            orElse: () => null,
          );
          if (sleepWidget != null) {
            parsedSleepVal = double.tryParse(sleepWidget['value']?.toString() ?? '');
            parsedSleepTarget = double.tryParse(sleepWidget['target']?.toString() ?? '');
            parsedSleepStatus = sleepWidget['status']?.toString();
          } else {
            parsedSleepVal = (resData['sleep_today'] ?? resData['sleep_hours'] ?? resData['sleep_duration'])?.toDouble();
            parsedSleepTarget = (resData['sleep_target'] ?? resData['sleep_goal'])?.toDouble();
            parsedSleepStatus = resData['sleep_status']?.toString();
          }

          // Heart Rate
          final hrWidget = widgetsData.firstWhere(
            (w) => w['title'] == 'Heart Rate',
            orElse: () => null,
          );
          if (hrWidget != null) {
            parsedHeartVal = double.tryParse(hrWidget['value']?.toString() ?? '');
            parsedHeartStatus = hrWidget['status']?.toString();
            final targetStr = hrWidget['target']?.toString() ?? '';
            if (targetStr.contains('-')) {
              parsedHeartTarget = double.tryParse(targetStr.split('-')[0]);
            } else {
              parsedHeartTarget = double.tryParse(targetStr);
            }
          } else {
            parsedHeartVal = (resData['heart_rate_today'] ?? resData['heart_rate_bpm'] ?? resData['pulse'])?.toDouble();
            parsedHeartTarget = (resData['heart_rate_target'] ?? resData['heart_rate_goal'])?.toDouble();
            parsedHeartStatus = resData['heart_rate_status']?.toString();
          }

          // Parse and Sync gym session from API response
          if (resData['latest_gym_session'] != null) {
            final gym = resData['latest_gym_session'];
            final checkInTimeStr = gym['check_in_time']?.toString();
            final checkOutTimeStr = gym['check_out_time']?.toString();
            final gymName = gym['gym_name']?.toString() ?? "Gold's Gym";
            final gymId = gym['id']?.toString() ?? "";

            if (checkOutTimeStr == null || checkOutTimeStr.isEmpty) {
              await prefs.setBool('gym_checked_in', true);
              await prefs.setString('gym_name', gymName);
              await prefs.setString('gym_place', gymName);
              if (checkInTimeStr != null) {
                await prefs.setString('gym_check_in_time', checkInTimeStr);
              }
              await prefs.setString('gym_session_id', gymId);
              await prefs.remove('gym_check_out_time');
            } else {
              await prefs.remove('gym_checked_in');
              await prefs.remove('gym_name');
              await prefs.remove('gym_place');
              await prefs.remove('gym_check_in_time');
              await prefs.remove('gym_session_id');
              await prefs.remove('gym_logged_exercises');
              
              await prefs.setString('gym_check_out_time', checkOutTimeStr);
              final checkOutDate = checkOutTimeStr.substring(0, 10);
              await prefs.setString('gym_done_today_date', checkOutDate);
            }
            await _loadGymState();
          }

          setState(() {
            _apiCaloriesValue = parsedCalVal;
            _apiCaloriesTarget = parsedCalTarget;
            _apiCaloriesStatus = parsedCalStatus;

            _apiSleepValue = parsedSleepVal;
            _apiSleepTarget = parsedSleepTarget;
            _apiSleepStatus = parsedSleepStatus;

            _apiHeartRateValue = parsedHeartVal;
            _apiHeartRateTarget = parsedHeartTarget;
            _apiHeartRateStatus = parsedHeartStatus;

            _serverWellnessScore = score;
            _serverDailySummary = summary;
            _serverRecommendations = recs;
            _activeSubscore = activeSub;
            _sleepSubscore = sleepSub;
            _nutritionSubscore = nutriSub;
            _mindfulnessSubscore = mindSub;
            _lastSynced = DateTime.now();
          });

          // Save to SharedPreferences cache
          await prefs.setInt('cached_wellness_score', score);
          await prefs.setInt('cached_active_subscore', activeSub);
          await prefs.setInt('cached_sleep_subscore', sleepSub);
          await prefs.setInt('cached_nutrition_subscore', nutriSub);
          await prefs.setInt('cached_mindfulness_subscore', mindSub);
          await prefs.setString('cached_daily_summary', summary);
          await prefs.setStringList('cached_recommendations', recs);
          await prefs.setString('cached_ai_buddy_message', buddyMsg);
          await prefs.setString(
            'last_sync_timestamp',
            _lastSynced!.toIso8601String(),
          );

          // Save custom metrics to persistent cache
          final todayStr = DateTime.now().toIso8601String().substring(0, 10);
          await prefs.setString('cached_dashboard_metrics_date', todayStr);
          if (_apiCaloriesValue != null) await prefs.setDouble('cached_calories_value', _apiCaloriesValue!);
          if (_apiCaloriesTarget != null) await prefs.setDouble('cached_calories_target', _apiCaloriesTarget!);
          if (_apiCaloriesStatus != null) await prefs.setString('cached_calories_status', _apiCaloriesStatus!);

          if (_apiSleepValue != null) await prefs.setDouble('cached_sleep_value', _apiSleepValue!);
          if (_apiSleepTarget != null) await prefs.setDouble('cached_sleep_target', _apiSleepTarget!);
          if (_apiSleepStatus != null) await prefs.setString('cached_sleep_status', _apiSleepStatus!);

          if (_apiHeartRateValue != null) await prefs.setDouble('cached_heart_rate_value', _apiHeartRateValue!);
          if (_apiHeartRateTarget != null) await prefs.setDouble('cached_heart_rate_target', _apiHeartRateTarget!);
          if (_apiHeartRateStatus != null) await prefs.setString('cached_heart_rate_status', _apiHeartRateStatus!);

          debugPrint(
            "Successfully executed merged sync and updated local dashboard cache.",
          );
        } else {
          debugPrint(
            "Failed to execute merged sync: ${response.statusCode} - ${response.body}",
          );
        }
      } catch (e) {
        debugPrint("Error in _syncAndRefreshDashboard combined flow: $e");
      }
    }();

    HealthService.instance.homeSyncFuture = future;
    try {
      await future;
    } finally {
      HealthService.instance.homeSyncFuture = null;
    }
  }

  Future<void> _showHealthSyncDataDialog() async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: HealthService.instance.fetchDailyHealthDataForPeriod(
                days: 7,
              ),
              builder: (context, snapshot) {
                Widget content;
                List<Map<String, dynamic>> payload = [];

                if (snapshot.connectionState == ConnectionState.waiting) {
                  content = const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(
                        color: Colors.tealAccent,
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  content = Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "Error loading data: ${snapshot.error}",
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                } else {
                  payload = snapshot.data!;
                  final prettyJson = const JsonEncoder.withIndent(
                    '  ',
                  ).convert(payload);

                  content = Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black26
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: SelectableText(
                        prettyJson,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }

                return AlertDialog(
                  backgroundColor: isDark
                      ? const Color(0xFF1E1E26)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.bug_report_outlined,
                            color: Colors.tealAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Health Sync Debugger",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: 380,
                    child: content,
                  ),
                  actions: [
                    if (snapshot.connectionState == ConnectionState.done &&
                        !snapshot.hasError)
                      TextButton.icon(
                        icon: const Icon(
                          Icons.copy_outlined,
                          size: 16,
                          color: Colors.tealAccent,
                        ),
                        label: const Text(
                          "Copy JSON",
                          style: TextStyle(color: Colors.tealAccent),
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: const JsonEncoder.withIndent(
                                '  ',
                              ).convert(payload),
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "JSON payload copied to clipboard!",
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Close",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showOnboardingDataDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('onboarding_data');

    if (!mounted) return;

    if (jsonStr == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("No Onboarding Data"),
          content: const Text(
            "No local onboarding data has been saved yet. Complete onboarding or save a profile first.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    final Map<String, dynamic> data = jsonDecode(jsonStr);

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return DefaultTabController(
          length: 2,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_outlined, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text(
                      "Onboarding Data",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 480,
              child: Column(
                children: [
                  TabBar(
                    tabs: const [
                      Tab(text: "Preview"),
                      Tab(text: "Raw JSON"),
                    ],
                    labelColor: Colors.blueAccent,
                    unselectedLabelColor: isDark
                        ? Colors.white60
                        : Colors.black54,
                    indicatorColor: Colors.blueAccent,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDataSection("Account Information", [
                                _buildDataRow(
                                  "Provider",
                                  data['auth']?['provider'] ?? '--',
                                ),
                                _buildDataRow(
                                  "Name",
                                  data['auth']?['name'] ?? '--',
                                ),
                                _buildDataRow(
                                  "Email",
                                  data['auth']?['email'] ?? '--',
                                ),
                              ], isDark),
                              const SizedBox(height: 12),
                              _buildDataSection("Basic Profile", [
                                _buildDataRow(
                                  "DOB",
                                  data['profile']?['dob'] ?? '--',
                                ),
                                _buildDataRow(
                                  "Gender",
                                  data['profile']?['gender'] ?? '--',
                                ),
                                _buildDataRow(
                                  "Height",
                                  "${data['profile']?['height'] ?? 0} cm",
                                ),
                                _buildDataRow(
                                  "Weight",
                                  "${data['profile']?['weight'] ?? 0} kg",
                                ),
                              ], isDark),
                              const SizedBox(height: 12),
                              _buildDataSection("Wellness Goals", [
                                Text(
                                  ((data['goals'] as List?)?.join(', ') ??
                                      'None selected'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ], isDark),
                              const SizedBox(height: 12),
                              _buildDataSection("Permissions & Reminders", [
                                _buildDataRow(
                                  "Health Connect",
                                  (data['permissions']?['health_connect_connected'] ??
                                          false)
                                      ? "Connected"
                                      : "Disconnected",
                                ),
                                _buildDataRow(
                                  "Daily Alerts",
                                  (data['permissions']?['notifications']?['daily_reminder'] ??
                                          false)
                                      ? "Enabled"
                                      : "Disabled",
                                ),
                                _buildDataRow(
                                  "Hydration Alerts",
                                  (data['permissions']?['notifications']?['hydration_reminder'] ??
                                          false)
                                      ? "Enabled"
                                      : "Disabled",
                                ),
                                _buildDataRow(
                                  "Activity Alerts",
                                  (data['permissions']?['notifications']?['activity_reminder'] ??
                                          false)
                                      ? "Enabled"
                                      : "Disabled",
                                ),
                                _buildDataRow(
                                  "AI Wellness Tips",
                                  (data['permissions']?['notifications']?['ai_tips'] ??
                                          false)
                                      ? "Enabled"
                                      : "Disabled",
                                ),
                              ], isDark),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black26
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: SelectableText(
                              const JsonEncoder.withIndent('  ').convert(data),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Reset App?"),
                      content: const Text(
                        "This will clear all onboarding and local cache data, returning you to the onboarding wizard. Proceed?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            "Reset",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await AuthService.instance.signOut();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OnboardingScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: const Text("Reset Onboarding"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataSection(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    await _fetchRealData(forceSync: true);
    if (!mounted) return;
    setState(() => _isSyncing = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Health database synced!")));
  }

  void _showDownloadRationaleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.blue),
            SizedBox(width: 8),
            Text("Health Connect Required"),
          ],
        ),
        content: const Text(
          "Google Health Connect is required to securely aggregate and sync your health records. "
          "You will be redirected to the Play Store to download the app.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              HealthService.instance.installHealthConnect();
            },
            child: const Text("Download"),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final daysOfWeek = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
    ];
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    final dayName = daysOfWeek[now.weekday % 7];
    final monthName = months[now.month - 1];
    final dateHeaderString = "$dayName • $monthName ${now.day}";

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateHeaderString,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${_getTimeBasedGreeting()}",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                // Notification Bell (Circular)
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No new notifications")),
                    );
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.08),
                        width: 1.2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          color: isDark ? Colors.white70 : Colors.black87,
                          size: 20,
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Profile Avatar Initial Button (Circular)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.08),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "P",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSynced(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Widget _buildState1Banner(ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.asset('assets/health_sync.png', width: 32, height: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Connect Health Connect",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Sync your steps, sleep, and heart rate automatically.",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                _setConnectRequested(true);
                _connectHealthServices();
              },
              child: const Text(
                "Connect",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildState2Banner(ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text("⚠️", style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Permissions Required",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Allow sync permissions to enable tracking.",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onPressed: _connectHealthServices,
              child: const Text(
                "Grant",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildState3SubModeA(ThemeData theme, bool isDark) {
    return _buildSmallSetupGuideCard(theme, isDark);
  }

  Widget _buildSmallSetupGuideCard(ThemeData theme, bool isDark) {
    if (_dismissedSetupCard) return const SizedBox.shrink();

    final textColor = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: 16,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoogleFitSetupGuideScreen(
                        isDark: isDark,
                        onRefresh: () => _syncData(),
                      ),
                    ),
                  );
                },
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.sync_rounded,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Google Fit Setup Guide",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Tap to view step-by-step sync setup",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white30 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _setDismissedSetupCard(true),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.15 : 0.02),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(bool checked, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: checked ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: checked ? FontWeight.bold : FontWeight.normal,
              color: checked
                  ? (isDark ? Colors.white70 : Colors.black87)
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard(
    String title,
    String placeholder,
    String emoji,
    Color color,
    bool isDark,
  ) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            placeholder,
            style: TextStyle(
              color: Colors.amber[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Sync pending",
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildState3SubModeB(ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      children: [
        // 2. Verified No Data Mode Banner - MOVED TO BOTTOM
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blueAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "No activity has been detected yet",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Your dashboard will automatically update when your connected fitness app syncs new health data.",
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          _syncData();
                        },
                        child: const Text(
                          "Refresh Health Data",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        _setSetupCompleted(false);
                      },
                      child: const Text(
                        "View Sync Guide",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildWellnessScoreCard(ThemeData theme, bool isDark) {
    final score = _wellnessScore;
    Color scoreColor = const Color(0xFFFFB03A); // Amber for Fair
    String evaluation = "Fair";
    if (score >= 80) {
      scoreColor = const Color(0xFF2EE5A3); // Mint for Excellent
      evaluation = "Excellent";
    } else if (score >= 60) {
      scoreColor = const Color(0xFFFF6D55); // Coral/Peach for Good
      evaluation = "Good";
    }

    final ringsData = [
      ConcentricRingData(
        value: _activeSubscoreValue / 100.0,
        color: const Color(0xFF2EE5A3),
        label: "Active",
      ),
      ConcentricRingData(
        value: _sleepSubscoreValue / 100.0,
        color: const Color(0xFF8F6BFF),
        label: "Sleep",
      ),
      ConcentricRingData(
        value: _nutritionSubscoreValue / 100.0,
        color: const Color(0xFFFFB03A),
        label: "Nutrition",
      ),
      ConcentricRingData(
        value: _mindfulnessSubscoreValue / 100.0,
        color: const Color(0xFF2ECAE5),
        label: "Mindfulness",
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // Header row with card title and evaluation badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "DAILY WELLNESS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white60 : Colors.black54,
                    letterSpacing: 0.8,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: scoreColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        evaluation.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: scoreColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Centered Stack combining the concentric rings chart and the score inside its bottom-right gap
            SizedBox(
              width: 170,
              height: 145,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: ConcentricRingsChart(rings: ringsData),
                  ),
                  Positioned(
                    left:
                        82, // Positioned inside the bottom-right gap (x > 70, y > 70)
                    top: 76,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              "$score",
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "/100",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Wellness Score",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              color: isDark ? Colors.white10 : Colors.black12,
              height: 32,
              thickness: 1,
            ),
            // Bottom Legend
            Wrap(
              spacing: 20,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(
                  "Active: ${_activeSubscoreValue}%",
                  const Color(0xFF2EE5A3),
                  isDark,
                ),
                _buildLegendItem(
                  "Sleep: ${_sleepSubscoreValue}%",
                  const Color(0xFF8F6BFF),
                  isDark,
                ),
                _buildLegendItem(
                  "Nutrition: ${_nutritionSubscoreValue}%",
                  const Color(0xFFFFB03A),
                  isDark,
                ),
                _buildLegendItem(
                  "Mind: ${_mindfulnessSubscoreValue}%",
                  const Color(0xFF2ECAE5),
                  isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendationCard(ThemeData theme, bool isDark) {
    String recommendationText =
        "Analyzing your activity and sleep logs... Syncing with advisor models...";

    if (_serverDailySummary != null) {
      recommendationText = _serverDailySummary!;
      if (_serverRecommendations.isNotEmpty) {
        recommendationText +=
            "\n\n💡 Recommendations:\n" +
            _serverRecommendations.map((r) => "• $r").join("\n");
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/ai_buddy.png', width: 24, height: 24),
                const SizedBox(width: 8),
                Text(
                  "AI Wellness Advisor",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recommendationText,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveChallengeCard(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text("🏆", style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      "Active Challenge",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "3 days left",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Weekly Hydration Champion",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              "Log at least 2000 ml of water daily for 7 consecutive days.",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Progress: 5/7 days completed",
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  "71%",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: const LinearProgressIndicator(
                value: 5 / 7,
                minHeight: 6,
                backgroundColor: Colors.white12,
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardsCard(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text("🎁", style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Rewards Status",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Earn points to unlock digital vouchers.",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "1,240 pts",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.amber,
                  ),
                ),
                Text(
                  "Level 3 Silver",
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualLoggingWidget(ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Manual Logging",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "No health services connected. You can log your metrics manually below:",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildManualLogButton(
                  "💧 Log Water",
                  () => _showManualLogDialog("Water"),
                  Colors.blue,
                ),
                _buildManualLogButton(
                  "⚖️ Log Weight",
                  () => _showManualLogDialog("Weight"),
                  Colors.green,
                ),
                _buildManualLogButton(
                  "🌙 Log Sleep",
                  () => _showManualLogDialog("Sleep"),
                  Colors.purple,
                ),
                _buildManualLogButton(
                  "🚶 Log Steps",
                  () => _showManualLogDialog("Steps"),
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualLogButton(
    String label,
    VoidCallback onPressed,
    Color color,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.08),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withOpacity(0.2), width: 1.2),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildWaterIntakeSliver(ThemeData theme, bool isDark) {
    final progress = (_healthData.waterIntake / _waterGoal).clamp(0.0, 1.0);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text("💧", style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Water Intake",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                "Stay hydrated throughout the day",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${_healthData.waterIntake.round()} / ${_waterGoal.round()} ml",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WaterLoggingScreen(
                        onWaterLogged: () {
                          _fetchRealData(forceSync: false);
                        },
                      ),
                    ),
                  ).then((_) {
                    _fetchRealData(forceSync: false);
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.02)
                          : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _waterWaveController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: WavePainter(
                                  progress: progress,
                                  wavePhase:
                                      _waterWaveController.value * 2 * pi,
                                  bubbles: _waterBubbles,
                                  isDark: isDark,
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(
                                    isDark ? 0.35 : 0.05,
                                  ),
                                  Colors.black.withOpacity(isDark ? 0.1 : 0.0),
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.water_drop,
                                        color: Colors.white,
                                        size: 20,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black38,
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${(progress * 100).round()}% Target Met",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black38,
                                              blurRadius: 4,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Tap anywhere to log water intake",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black38,
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionSliver(ThemeData theme, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NutritionLoggingScreen(
                  onFoodLogged: () {
                    _fetchRealData(forceSync: true);
                  },
                ),
              ),
            );
          },
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text("🍎", style: TextStyle(fontSize: 28)),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Nutrition Summary",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          "Today's macros and intake",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Calories",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${_healthData.nutritionCalories.round()} kcal",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _macroElement(
                      "Carbs",
                      "${_healthData.carbs.round()}g",
                      Colors.blue,
                    ),
                    _macroElement(
                      "Protein",
                      "${_healthData.protein.round()}g",
                      Colors.green,
                    ),
                    _macroElement(
                      "Fat",
                      "${_healthData.fat.round()}g",
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    "Tap to log food ›",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orangeAccent.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVitalsHeader(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
        child: Text(
          "Vitals & Heart",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildVitalsGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        childAspectRatio: 1.15,
        children: [
          MetricCard(
            title: "Pulse Rate",
            value: _healthData.heartRate > 0
                ? _healthData.heartRate.round().toString()
                : "--",
            unit: "bpm",
            icon: "💓",
            color: const Color(0xFFC72C3A),
            subtitle: "Realtime reading",
            onTap: () => _navigateToMetricDetail(
              'heart_rate',
              'Heart Rate',
              '💓',
              const Color(0xFFC72C3A),
            ),
          ),
          MetricCard(
            title: "Resting Heart",
            value: _healthData.restingHeartRate > 0
                ? _healthData.restingHeartRate.round().toString()
                : "--",
            unit: "bpm",
            icon: "💤",
            color: const Color(0xFFC72C3A),
            subtitle: "Average pulse",
            onTap: () => _navigateToMetricDetail(
              'heart_rate',
              'Heart Rate',
              '💤',
              const Color(0xFFC72C3A),
            ),
          ),
          MetricCard(
            title: "Blood Pressure",
            value: _healthData.systolicBP > 0
                ? "${_healthData.systolicBP.round()}/${_healthData.diastolicBP.round()}"
                : "--/--",
            unit: "mmHg",
            icon: "🩺",
            color: Colors.teal,
            subtitle: "Systolic/Diastolic",
          ),
          MetricCard(
            title: "Blood Sugar",
            value: _healthData.bloodGlucose > 0
                ? _healthData.bloodGlucose.round().toString()
                : "--",
            unit: "mg/dL",
            icon: "🩸",
            color: Colors.deepOrangeAccent,
            subtitle: "Glucose level",
          ),
          MetricCard(
            title: "SpO2 Oxygen",
            value: _healthData.spo2 > 0 ? "${_healthData.spo2.round()}%" : "--",
            unit: "",
            icon: "🫁",
            color: Colors.lightBlueAccent,
            subtitle: "Blood Saturation",
          ),
          MetricCard(
            title: "Mindfulness",
            value: _healthData.mindfulnessMinutes.round().toString(),
            unit: "mins",
            icon: "🧘",
            color: Colors.purple,
            subtitle: "Breathing time",
          ),
        ],
      ),
    );
  }

  Widget _buildSleepWeightHeader(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
        child: Text(
          "Sleep & Body composition",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSleepWeightGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        childAspectRatio: 1.15,
        children: [
          MetricCard(
            title: "Sleep Duration",
            value: _healthData.sleepDuration > 0
                ? "${_healthData.sleepDuration} hrs"
                : "--",
            unit: "",
            icon: "🌙",
            color: const Color(0xFF5A5AE6),
            progress: _healthData.sleepDuration / _sleepGoal,
            subtitle: "Goal: ${_sleepGoal.round()} hrs",
            onTap: () => _navigateToMetricDetail(
              'sleep',
              'Sleep',
              '🌙',
              const Color(0xFF5A5AE6),
            ),
          ),
          MetricCard(
            title: "Sleep Quality",
            value: _healthData.sleepQuality,
            unit: "",
            icon: "⭐",
            color: Colors.amber,
            subtitle: "Score estimate",
          ),
          MetricCard(
            title: "Body Weight",
            value: _healthData.weight > 0
                ? _healthData.weight.toString()
                : "--",
            unit: "kg",
            icon: "⚖️",
            color: Colors.greenAccent,
            subtitle: "Latest records",
          ),
          MetricCard(
            title: "BMI",
            value: _healthData.bmi > 0 ? _healthData.bmi.toString() : "--",
            unit: "",
            icon: "📊",
            color: Colors.tealAccent,
            subtitle: "Body Mass Index",
          ),
          if (_healthData.bodyFat != null)
            MetricCard(
              title: "Body Fat",
              value: "${_healthData.bodyFat}%",
              unit: "",
              icon: "📉",
              color: Colors.redAccent,
              subtitle: "Percentage fat",
            ),
        ],
      ),
    );
  }

  Widget _buildMedicalSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: MedicalRecordsSection(
          healthData: _healthData,
          onProvideConsentPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (sheetContext) => MedicalConsentSheet(
                onAuthorize: _handleAuthorizeMedicalRecords,
              ),
            );
          },
          onRevokeConsentPressed: _showRevokeConsentConfirmDialog,
        ),
      ),
    );
  }

  Future<void> _navigateToMetricDetail(
    String metric,
    String title,
    String icon,
    Color color,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('onboarding_data');
    String email = "testuser@arcar.com";
    if (jsonStr != null) {
      final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
      final storedEmail = onboarding['auth']?['email'];
      if (storedEmail != null) {
        email = storedEmail;
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MetricDetailScreen(
          metric: metric.toLowerCase() == 'fitness' ? 'workouts' : metric,
          title: title,
          icon: icon,
          color: color,
          email: email,
        ),
      ),
    ).then((_) {
      _fetchRealData(forceSync: false);
    });
  }

  Widget _buildStepsCard(
    bool isDark,
    double steps,
    double goal,
    VoidCallback onTap,
  ) {
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF132320), Color(0xFF0E1A18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFE8F5F2), Color(0xFFD3EBE5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final borderColor = isDark
        ? const Color(0xFF1F3530).withOpacity(0.8)
        : const Color(0xFFB9DDD3);
    final textColor = isDark ? Colors.white : const Color(0xFF1E2843);
    final progress = (steps / goal).clamp(0.0, 1.0);

    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text("👣", style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      "STEPS",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? const Color(0xFF38E5A6)
                            : const Color(0xFF4C8D80),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatWithCommas(steps.round()),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: isDark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.04),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF006D56),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "${(progress * 100).round()}%",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatWithCommas(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildHeartRateCard(
    bool isDark,
    double bpm,
    double restingBpm,
    String? status,
    VoidCallback onTap,
  ) {
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF2D1418), Color(0xFF1E0C0E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFF0F2), Color(0xFFFCDCE1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final borderColor = isDark
        ? const Color(0xFF3F1F24).withOpacity(0.8)
        : const Color(0xFFF5CCD2);
    final textColor = isDark ? Colors.white : const Color(0xFF1E2843);

    return SizedBox(
      height: 140,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double circleSize = min(constraints.maxWidth - 4, 122.0);
            return SizedBox(
              width: circleSize,
              height: circleSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: gradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("❤️", style: TextStyle(fontSize: 18)),
                              const SizedBox(height: 5),
                              Text(
                                bpm > 0 ? bpm.round().toString() : "--",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  height: 1.1,
                                ),
                              ),
                              const Text(
                                "bpm",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1D1D23)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFF5CCD2),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          "Resting: ${restingBpm > 0 ? restingBpm.round() : '--'}${status != null && status.isNotEmpty ? ' • $status' : ''}",
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFC72C3A),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCaloriesCard(
    bool isDark,
    double calories,
    double goal,
    String? status,
    VoidCallback onTap,
  ) {
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF281B10), Color(0xFF1B1109)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFF8EE), Color(0xFFF7E6D0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final borderColor = isDark
        ? const Color(0xFF392719).withOpacity(0.8)
        : const Color(0xFFEFD5B5);
    final textColor = isDark ? Colors.white : const Color(0xFF1E2843);

    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text("🔥", style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      "Calories",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? const Color(0xFFFFB03A)
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      calories.round().toString(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "kcal",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Goal: ${goal.round()}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE08200),
                      ),
                    ),
                    if (status != null && status.isNotEmpty)
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSleepCard(
    bool isDark,
    double sleepHours,
    double goal,
    String? status,
    VoidCallback onTap,
  ) {
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF181628), Color(0xFF100F1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFF2F2FC), Color(0xFFDFDFFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final borderColor = isDark
        ? const Color(0xFF25233E).withOpacity(0.8)
        : const Color(0xFFCDCDFA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E2843);
    final progress = (sleepHours / goal).clamp(0.0, 1.0);

    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text("🌙", style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          const Text(
                            "SLEEP",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF5A5AE6),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${sleepHours.toInt()}h",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              height: 1.05,
                            ),
                          ),
                          Text(
                            "${((sleepHours - sleepHours.toInt()) * 60).round()}m",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Goal: ${goal.round()}h",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white30 : Colors.black45,
                            ),
                          ),
                          if (status != null && status.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(3),
                    child: CustomPaint(
                      painter: SleepRingPainter(
                        progress: progress,
                        color: const Color(0xFF5A5AE6),
                        strokeWidth: 5.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Sleek Glowing Morphic Background Blobs
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          // Glow Blob 1 (Top Right)
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
                    Colors.purple.withOpacity(isDark ? 0.22 : 0.18),
                    Colors.purple.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Glow Blob 2 (Middle Left)
          Positioned(
            top: 250,
            left: -120,
            width: 380,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(isDark ? 0.22 : 0.18),
                    Colors.blue.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Glow Blob 3 (Bottom Right)
          Positioned(
            bottom: -80,
            right: -60,
            width: 340,
            height: 340,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.green.withOpacity(isDark ? 0.18 : 0.15),
                    Colors.green.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => _fetchRealData(forceSync: true),
              color: const Color(0xFFFF6D55),
              backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Header (Greeting, Profile, Notification Icon)
                  _buildHeader(theme, isDark),

                  // Active challenges actions row
                  SliverToBoxAdapter(
                    child: _buildActiveChallengesRow(theme, isDark),
                  ),

                  // Health Connect status banner at the top
                  if (!_isConnected)
                    SliverToBoxAdapter(
                      child: _healthConnectRequested
                          ? _buildState2Banner(theme, isDark)
                          : _buildState1Banner(theme, isDark),
                    ),

                  // Guide/Setup status card when connected but no data
                  if (_isConnected && !_hasHealthData)
                    if (!_healthSetupCompleted)
                      SliverToBoxAdapter(
                        child: _buildState3SubModeA(theme, isDark),
                      )
                    else
                      SliverToBoxAdapter(
                        child: _buildState3SubModeB(theme, isDark),
                      ),

                  // Main Wellness & Score Card
                  SliverToBoxAdapter(
                    child: _buildWellnessScoreCard(theme, isDark),
                  ),

                  // Face Scan Banner
                  SliverToBoxAdapter(
                    child: _buildFaceScanBanner(theme, isDark),
                  ),

                  // Asymmetric Staggered Width Rows: Row 1 (Steps wide + HR circle), Row 2 (Calories + Sleep wide)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 12,
                        bottom: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: Steps (wide) & Heart Rate (narrow/circle)
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildStepsCard(
                                  isDark,
                                  _healthData.steps,
                                  _stepGoal,
                                  () => _navigateToMetricDetail(
                                    'steps',
                                    'Steps',
                                    '👣',
                                    const Color(0xFF006D56),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildHeartRateCard(
                                  isDark,
                                  _apiHeartRateValue ?? _healthData.heartRate,
                                  _apiHeartRateTarget ??
                                      (_healthData.restingHeartRate > 0
                                          ? _healthData.restingHeartRate
                                          : 64.0),
                                  _apiHeartRateStatus,
                                  () => _navigateToMetricDetail(
                                    'heart_rate',
                                    'Heart Rate',
                                    '❤️',
                                    const Color(0xFFC72C3A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Row 2: Calories (narrow) & Sleep (wide)
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildCaloriesCard(
                                  isDark,
                                  _apiCaloriesValue ?? _healthData.activeCalories,
                                  _apiCaloriesTarget ?? _calorieGoal,
                                  _apiCaloriesStatus,
                                  () => _navigateToMetricDetail(
                                    'calories',
                                    'Calories',
                                    '🔥',
                                    const Color(0xFFE08200),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: _buildSleepCard(
                                  isDark,
                                  _apiSleepValue ?? _healthData.sleepDuration,
                                  _apiSleepTarget ?? _sleepGoal,
                                  _apiSleepStatus,
                                  () => _navigateToMetricDetail(
                                    'sleep',
                                    'Sleep',
                                    '🌙',
                                    const Color(0xFF5A5AE6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Water Intake Section
                  _buildWaterIntakeSliver(theme, isDark),

                  // Nutrition Section
                  _buildNutritionSliver(theme, isDark),

                  // AI Health Buddy Card
                  SliverToBoxAdapter(
                    child: _buildAIRecommendationCard(theme, isDark),
                  ),

                  // Today's Plan Section
                  SliverToBoxAdapter(
                    child: _buildTodaysPlanSection(theme, isDark),
                  ),

                  // Quick Access Section
                  SliverToBoxAdapter(
                    child: _buildQuickAccessSection(theme, isDark),
                  ),

                  // Active Challenge Card
                  // SliverToBoxAdapter(
                  //   child: _buildActiveChallengeCard(theme, isDark),
                  // ),

                  // Your Last 12 Days Graph
                  SliverToBoxAdapter(
                    child: _buildLastDaysActivityBarGraph(theme, isDark),
                  ),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            ),
          ),
          if (_isSyncing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.blueAccent,
                ),
              ),
            ),
          if (_isSyncing && _serverWellnessScore == null)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: isDark
                        ? Colors.black.withOpacity(0.65)
                        : Colors.white.withOpacity(0.55),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.06),
                                width: 1.2,
                              ),
                            ),
                            child: const CircularProgressIndicator(
                              color: Color(0xFFFF6D55),
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Analyzing your health telemetry...",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Creating your personalized dashboard",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
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

  Widget _macroElement(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAuthorizeMedicalRecords() async {
    setState(() => _isSyncing = true);

    final success = await HealthService.instance.grantMedicalConsent();
    if (success) {
      await _fetchRealData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to grant medical access permissions."),
          backgroundColor: Colors.orange,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Medical records access authorized!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildFaceScanBanner(ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E2836), const Color(0xFF0F1318)]
                : [const Color(0xFFE5F1FF), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            width: 1.3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Scan your face, ",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const Text(
                          "read 9 vitals.",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF6D55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "HR • BP • SpO2 • HRV • Stress",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D55).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF6D55).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.face_retouching_natural_rounded,
                        color: Color(0xFFFF6D55),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaysPlanSection(ThemeData theme, bool isDark) {
    final labelColor = isDark ? Colors.white60 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 8,
          ),
          child: Text(
            "TODAY'S PLAN",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: labelColor,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _buildPlanItem(
                  "🧘",
                  "08:00",
                  "5-min breath reset",
                  "Mind",
                  const Color(0xFF8F6BFF),
                  false,
                ),
                const Divider(color: Colors.white10, height: 16),
                _buildPlanItem(
                  "🍲",
                  "13:00",
                  "Log your lunch",
                  "Nutri",
                  const Color(0xFFFFB03A),
                  true,
                ),
                const Divider(color: Colors.white10, height: 16),
                _buildPlanItem(
                  "🏋️",
                  "18:30",
                  "Strength session @ Office Gym",
                  "Move",
                  const Color(0xFF2EE5A3),
                  false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanItem(
    String emoji,
    String time,
    String title,
    String badge,
    Color badgeColor,
    bool completed,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Text(
          time,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: completed
                  ? (isDark ? Colors.white30 : Colors.black38)
                  : (isDark ? Colors.white : Colors.black87),
              decoration: completed ? TextDecoration.lineThrough : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessSection(ThemeData theme, bool isDark) {
    final labelColor = isDark ? Colors.white60 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 8,
          ),
          child: Text(
            "QUICK ACCESS",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: labelColor,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickAccessItem(
                      "📷",
                      "Face Scan",
                      const Color(0xFFFF6D55),
                    ),
                    _buildQuickAccessItem(
                      "🍲",
                      "Log Meal",
                      const Color(0xFFFFB03A),
                    ),
                    _buildQuickAccessItem(
                      "🩺",
                      "Doctor",
                      const Color(0xFFFF65A3),
                    ),
                    _buildQuickAccessItem(
                      "💪",
                      "Trainer",
                      const Color(0xFF2EE5A3),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickAccessItem(
                      "🪪",
                      "Health Card",
                      const Color(0xFF2ECAE5),
                    ),
                    _buildQuickAccessItem(
                      "🛡️",
                      "SOS",
                      const Color(0xFFFF3B30),
                    ),
                    _buildQuickAccessItem(
                      "🏆",
                      "Compete",
                      const Color(0xFFFFD60A),
                    ),
                    _buildQuickAccessItem(
                      "✨",
                      "Buddy",
                      const Color(0xFF8F6BFF),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessItem(String emoji, String title, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2), width: 1.2),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastDaysActivityBarGraph(ThemeData theme, bool isDark) {
    final labelColor = isDark ? Colors.white60 : Colors.black54;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dailyRecordsFuture,
      builder: (context, snapshot) {
        List<Map<String, dynamic>> records = [];
        bool isLoading = true;

        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          records = snapshot.data!.reversed.toList();
          isLoading = false;
        }

        // If loading or empty, show 7 placeholder bars with default values
        if (isLoading || records.isEmpty) {
          records = List.generate(7, (index) {
            final date = DateTime.now().subtract(Duration(days: 6 - index));
            return {
              'date':
                  "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
              'steps': 0,
            };
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 8,
              ),
              child: Text(
                "YOUR LAST 7 DAYS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: labelColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: SizedBox(
                  height: 75,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: records.map((record) {
                      final double steps = (record['steps'] as num).toDouble();
                      final fraction = (steps / _stepGoal).clamp(0.06, 1.0);

                      final dateStr = record['date'] as String;
                      final date = DateTime.tryParse(dateStr) ?? DateTime.now();
                      final weekdayStr = [
                        "M",
                        "T",
                        "W",
                        "T",
                        "F",
                        "S",
                        "S",
                      ][date.weekday - 1];

                      // Is today?
                      final isToday =
                          date.day == DateTime.now().day &&
                          date.month == DateTime.now().month &&
                          date.year == DateTime.now().year;

                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // The actual bar
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  height: 50 * fraction,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: isToday
                                          ? [
                                              const Color(0xFF2EE5A3),
                                              const Color(
                                                0xFF2EE5A3,
                                              ).withValues(alpha: 0.9),
                                            ]
                                          : [
                                              const Color(
                                                0xFF2EE5A3,
                                              ).withValues(alpha: 0.45),
                                              const Color(
                                                0xFF2EE5A3,
                                              ).withValues(alpha: 0.75),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: isToday
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF2EE5A3,
                                              ).withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Weekday Label
                            Text(
                              weekdayStr,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: isToday
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: isToday
                                    ? const Color(0xFF2EE5A3)
                                    : (isDark
                                          ? Colors.white54
                                          : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRevokeConsentConfirmDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Revoke Medical Consent?"),
          ],
        ),
        content: const Text(
          "Wiping medical consent will immediately remove all clinical records, vaccinations, and ECG reports from your view. "
          "You will need to provide explicit consent again to re-sync them.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isSyncing = true);
              await HealthService.instance.revokeMedicalConsent();

              await _fetchRealData();
              if (!mounted) return;
              setState(() => _isSyncing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Medical records consent revoked and data cleared.",
                  ),
                  backgroundColor: Colors.blueGrey,
                ),
              );
            },
            child: const Text("Revoke", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChallengesRow(ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;

    // Determine if gym check-in card should be shown
    bool showGymCheckinCard = false;
    final hasActiveGymChallenge = _activeChallenges.any(
      (c) =>
          c.metricType == 'workouts' ||
          c.title.toLowerCase().contains('gym') ||
          c.title.toLowerCase().contains('workout'),
    );

    final isGymCompletedToday = _activeChallenges.any(
      (c) =>
          (c.metricType == 'workouts' ||
              c.title.toLowerCase().contains('gym') ||
              c.title.toLowerCase().contains('workout')) &&
          c.completedToday,
    );

    if (_gymCheckedIn) {
      showGymCheckinCard = true;
    } else if (!isGymCompletedToday && hasActiveGymChallenge) {
      showGymCheckinCard = true;
    }

    // Filter other active challenges (if gym check-in & out is done today, don't show gym/workouts challenges in active goals)
    final otherChallenges = _activeChallenges.where((c) {
      final isGym =
          c.metricType == 'workouts' ||
          c.title.toLowerCase().contains('gym') ||
          c.title.toLowerCase().contains('workout');
      if (isGym && isGymCompletedToday) {
        return false;
      }
      return true;
    }).toList();

    final totalItems = (showGymCheckinCard ? 1 : 0) + otherChallenges.length;
    final isSingleItem = totalItems == 1;

    // If nothing to show, return shrink
    if (totalItems == 0) {
      return const SizedBox.shrink();
    }

    if (isSingleItem) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActiveGoalsHeader(theme, textColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 72,
              child: showGymCheckinCard
                  ? _buildGymCheckinDashboardCard(isDark, isSingleItem: true)
                  : _buildChallengeDashboardCard(
                      otherChallenges.first,
                      isDark,
                      isSingleItem: true,
                    ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActiveGoalsHeader(theme, textColor),
        SizedBox(
          height: 72,
          child: ListView(
            controller: _activeGoalsScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              if (showGymCheckinCard)
                _buildGymCheckinDashboardCard(isDark, isSingleItem: false),
              ...otherChallenges.map(
                (c) => _buildChallengeDashboardCard(
                  c,
                  isDark,
                  isSingleItem: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveGoalsHeader(ThemeData theme, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "ACTIVE GOALS",
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: textColor.withOpacity(0.6),
              letterSpacing: 1.2,
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymCheckinDashboardCard(
    bool isDark, {
    bool isSingleItem = false,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;

    // Indigo-to-blue glassmorphic capsule design
    final cardBg = isDark
        ? Colors.indigoAccent.withOpacity(0.12)
        : Colors.indigoAccent.withOpacity(0.06);
    final borderColor = Colors.indigoAccent.withOpacity(0.35);

    return Container(
      width: isSingleItem ? double.infinity : 250,
      margin: isSingleItem
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GymCheckinScreen(
                  onStatusChanged: () {
                    _loadGymState();
                    _fetchActiveChallenges();
                  },
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Pulsing indicator / badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.indigoAccent.withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: _gymCheckedIn
                        ? const Text("🏋️‍♂️", style: TextStyle(fontSize: 16))
                        : const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.indigoAccent,
                            size: 18,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            _gymCheckedIn ? "GYM ACTIVE" : "GYM CHECK-IN",
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.indigoAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (_gymCheckedIn) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _gymCheckedIn
                            ? (_gymName ?? "Workout")
                            : "Check in now",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (_gymCheckedIn) ...[
                        const SizedBox(height: 1),
                        Text(
                          _formatDuration(_gymElapsed),
                          style: const TextStyle(
                            fontSize: 9,
                            fontFamily: 'monospace',
                            color: Colors.indigoAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeDashboardCard(
    Challenge challenge,
    bool isDark, {
    bool isSingleItem = false,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final color = challenge.color;
    final cardBg = isDark ? color.withOpacity(0.08) : color.withOpacity(0.04);
    final borderColor = color.withOpacity(0.25);

    // Determine category icon
    String emoji = "🏆";
    if (challenge.metricType == 'steps')
      emoji = "👣";
    else if (challenge.metricType == 'water')
      emoji = "🥤";
    else if (challenge.metricType == 'sleep')
      emoji = "🌙";
    else if (challenge.metricType == 'calories')
      emoji = "🔥";
    else if (challenge.metricType == 'heart_rate')
      emoji = "❤️";
    else if (challenge.metricType == 'workouts' ||
        challenge.title.toLowerCase().contains('gym') ||
        challenge.title.toLowerCase().contains('workout'))
      emoji = "🏋️‍♂️";

    final progressVal = (challenge.progress / challenge.target).clamp(0.0, 1.0);
    final pct = (progressVal * 100).round();

    return Container(
      width: isSingleItem ? double.infinity : 170,
      margin: isSingleItem
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (challenge.metricType == 'water') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WaterLoggingScreen(
                    onWaterLogged: () {
                      _fetchRealData(forceSync: true);
                    },
                  ),
                ),
              );
            } else if (challenge.metricType == 'workouts' ||
                challenge.title.toLowerCase().contains('gym') ||
                challenge.title.toLowerCase().contains('workout')) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GymCheckinScreen(
                    onStatusChanged: () {
                      _loadGymState();
                      _fetchActiveChallenges();
                    },
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MetricDetailScreen(
                    metric: challenge.metricType.toLowerCase() == 'fitness'
                        ? 'workouts'
                        : challenge.metricType,
                    title: challenge.title,
                    icon: emoji,
                    color: color,
                    email: _userEmail,
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Thin circular progress ring wrapping the emoji
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progressVal,
                        strokeWidth: 2.8,
                        backgroundColor: isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.04),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        challenge.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$pct% done",
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleFitSetupGuideScreen extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRefresh;

  const GoogleFitSetupGuideScreen({
    super.key,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                        ),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                        ),
                        color: isDark ? Colors.white70 : Colors.black87,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Sync Guide",
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: textColor,
                            ),
                          ),
                          Text(
                            "Setup Google Fit synchronization",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text("🎉", style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Almost Synced!",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Health Connect is connected. To view health metrics, please ensure a supported fitness app (like Google Fit) is active and syncing with Health Connect.",
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Connection Progress",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildProgressItem(
                          true,
                          "Health Connect Installed",
                          isDark,
                        ),
                        _buildProgressItem(
                          true,
                          "Connected Successfully",
                          isDark,
                        ),
                        _buildProgressItem(true, "Permissions Granted", isDark),
                        _buildProgressItem(false, "Fitness App Synced", isDark),
                        _buildProgressItem(
                          false,
                          "Health Data Available",
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.help_outline,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Google Fit Sync Steps",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildGuideStep(
                          "1",
                          "Open Google Fit app on your device",
                          isDark,
                        ),
                        _buildGuideStep("2", "Go to your Profile tab", isDark),
                        _buildGuideStep(
                          "3",
                          "Open Settings (Gear Icon)",
                          isDark,
                        ),
                        _buildGuideStep(
                          "4",
                          "Enable Health Connect Sync option",
                          isDark,
                        ),
                        _buildGuideStep(
                          "5",
                          "Grant all Read & Write Permissions requested",
                          isDark,
                        ),
                        _buildGuideStep(
                          "6",
                          "Walk for a few minutes or wait for the data to sync",
                          isDark,
                        ),
                        _buildGuideStep(
                          "7",
                          "Return to Arcare App and refresh",
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      onRefresh();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Sync & Refresh Dashboard",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(bool completed, String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: completed
                ? const Color(0xFF00C781)
                : (isDark ? Colors.white24 : Colors.black26),
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: completed
                  ? (isDark ? Colors.white.withOpacity(0.87) : Colors.black87)
                  : (isDark ? Colors.white.withOpacity(0.3) : Colors.black38),
              fontWeight: completed ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String step, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SleepRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  SleepRingPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius =
        min(size.width / 2, size.height / 2) - strokeWidth / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint bgPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Paint fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final double sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SleepRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
