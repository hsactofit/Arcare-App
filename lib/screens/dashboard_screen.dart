import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/medical/medical_records_section.dart';
import '../widgets/medical/medical_consent_sheet.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import 'water_logging_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
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

  // Server-synced states
  int? _serverWellnessScore;
  String? _serverDailySummary;
  List<String> _serverRecommendations = [];
  int? _activeSubscore;
  int? _sleepSubscore;
  int? _nutritionSubscore;
  int? _mindfulnessSubscore;

  @override
  void initState() {
    super.initState();
    _loadSetupState();
    _checkStatusAndSync();
  }

  Future<void> _loadSetupState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _healthSetupCompleted = prefs.getBool('healthSetupCompleted') ?? false;
      _healthConnectRequested =
          prefs.getBool('healthConnectRequested') ?? false;
      _userName = prefs.getString('user_name') ?? "User";

      // Load custom goals configuration
      _stepGoal = prefs.getDouble('goal_steps') ?? 10000.0;
      _waterGoal = prefs.getDouble('goal_water') ?? 2500.0;
      _calorieGoal = prefs.getDouble('goal_calories') ?? 600.0;
      _exerciseGoal = prefs.getDouble('goal_exercise') ?? 60.0;
      _sleepGoal = prefs.getDouble('goal_sleep') ?? 8.0;
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
    // 1. Always load the active local Health Connect data to update the UI cards
    final data = await HealthService.instance.fetchHealthData();
    setState(() {
      _healthData = data;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

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
      });

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
            final syncData = await HealthService.instance
                .fetchDailyHealthDataForPeriod(days: 7);
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
    }
  }

  Future<void> _syncAndRefreshDashboard(
    String email,
    List<Map<String, dynamic>> dailyRecords,
  ) async {
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

        await HealthService.instance.initializeWaterIntakeFromApi(apiWaterToday.toDouble());

        setState(() {
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
                  "Hey, $_userName 👋",
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
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      children: [
        // 2. Dashboard Banner (Info Section) - MOVED TO BOTTOM
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text("🎉", style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "You're Almost Ready!",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Health Connect has been connected successfully. However, we couldn't find any health data. Connect a supported fitness application (Google Fit, Samsung Health, Fitbit, Garmin, Mi Fitness, etc.) and allow it to sync with Health Connect.",
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Setup Progress
                const Text(
                  "Setup Progress",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 8),
                _buildProgressItem(true, "Health Connect Installed", isDark),
                _buildProgressItem(true, "Connected Successfully", isDark),
                _buildProgressItem(true, "Permissions Granted", isDark),
                _buildProgressItem(false, "Fitness App Synced", isDark),
                _buildProgressItem(false, "Health Data Available", isDark),

                const SizedBox(height: 16),

                // Actions
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
                          setState(() {
                            _showGuide = !_showGuide;
                          });
                        },
                        child: Text(
                          _showGuide
                              ? "Hide Setup Guide"
                              : "Setup Google Fit →",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(
                          isDark ? 0.08 : 0.12,
                        ),
                        foregroundColor: textColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _syncData();
                      },
                      child: const Text("Refresh Dashboard"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 3. Google Fit Setup Guide (collapsible) - MOVED TO BOTTOM
        if (_showGuide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        "Google Fit Setup Guide",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep("1", "Open Google Fit app on your device"),
                  _buildGuideStep("2", "Go to your Profile tab"),
                  _buildGuideStep("3", "Open Settings (Gear Icon)"),
                  _buildGuideStep("4", "Enable Health Connect Sync option"),
                  _buildGuideStep(
                    "5",
                    "Grant all Read & Write Permissions requested",
                  ),
                  _buildGuideStep(
                    "6",
                    "Walk for a few minutes or wait for the data to sync",
                  ),
                  _buildGuideStep(
                    "7",
                    "Return to this app and tap 'Refresh Dashboard' above",
                  ),
                ],
              ),
            ),
          ),

        // 4. User Confirmation Card - MOVED TO BOTTOM
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "I've already completed the setup",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "If you have already completed the setup steps above but we still can't detect health data, you can continue using the dashboard.",
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
                          backgroundColor: theme.colorScheme.primary,
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
                          "Verify Again",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          _setSetupCompleted(true);
                        },
                        child: const Text(
                          "I've Completed the Setup",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                // Circular Ring with Lightning Bolt
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: score / 100.0,
                        strokeWidth: 6,
                        backgroundColor: scoreColor.withOpacity(0.12),
                        color: scoreColor,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Icon(Icons.flash_on_rounded, color: scoreColor, size: 26),
                  ],
                ),
                const SizedBox(width: 18),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "DAILY WELLNESS SCORE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "$score",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            " /100",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(color: Colors.white10, height: 1),
            ),
            // Bottom 4 Sub-Scores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSubscoreColumn(
                  _activeSubscore != null ? "$_activeSubscore" : "--",
                  "Active",
                  const Color(0xFF2EE5A3),
                ),
                _buildSubscoreColumn(
                  _sleepSubscore != null ? "$_sleepSubscore" : "--",
                  "Sleep",
                  const Color(0xFF8F6BFF),
                ),
                _buildSubscoreColumn(
                  _nutritionSubscore != null ? "$_nutritionSubscore" : "--",
                  "Nutri",
                  const Color(0xFFFFB03A),
                ),
                _buildSubscoreColumn(
                  _mindfulnessSubscore != null ? "$_mindfulnessSubscore" : "--",
                  "Mind",
                  const Color(0xFF2ECAE5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscoreColumn(String value, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_healthData.waterIntake / _waterGoal).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.12),
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(color: Colors.blue, width: 1),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.blue),
                label: const Text(
                  "Log Water Intake",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
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
            ],
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
            color: Colors.red,
            subtitle: "Realtime reading",
          ),
          MetricCard(
            title: "Resting Heart",
            value: _healthData.restingHeartRate > 0
                ? _healthData.restingHeartRate.round().toString()
                : "--",
            unit: "bpm",
            icon: "💤",
            color: Colors.indigo,
            subtitle: "Average pulse",
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
            value: "${_healthData.sleepDuration} hrs",
            unit: "",
            icon: "🌙",
            color: Colors.purpleAccent,
            progress: _healthData.sleepDuration / _sleepGoal,
            subtitle: "Goal: ${_sleepGoal.round()} hrs",
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
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header (Greeting, Profile, Notification Icon)
                _buildHeader(theme, isDark),

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
                SliverToBoxAdapter(child: _buildFaceScanBanner(theme, isDark)),

                // 2x2 Grid: Steps, Heart Rate, Calories, Sleep
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.22,
                    children: [
                      MetricCard(
                        title: "Steps",
                        value: _healthData.steps.round().toString(),
                        unit: "",
                        icon: "👣",
                        color: const Color(0xFF2EE5A3),
                        subtitle: "Goal: ${_stepGoal.round()}",
                      ),
                      MetricCard(
                        title: "Heart Rate",
                        value: _healthData.heartRate > 0
                            ? "${_healthData.heartRate.round()}"
                            : "--",
                        unit: _healthData.heartRate > 0 ? "bpm" : "",
                        icon: "❤️",
                        color: const Color(0xFFFF6D55),
                        subtitle: _healthData.heartRate > 0
                            ? "bpm avg"
                            : "No readings",
                      ),
                      MetricCard(
                        title: "Calories",
                        value: _healthData.activeCalories > 0
                            ? "${_healthData.activeCalories.round()}"
                            : "--",
                        unit: _healthData.activeCalories > 0 ? "kcal" : "",
                        icon: "🔥",
                        color: const Color(0xFFFFB03A),
                        subtitle: "Goal: ${_calorieGoal.round()} kcal",
                      ),
                      MetricCard(
                        title: "Sleep",
                        value: _healthData.sleepDuration > 0
                            ? "${_healthData.sleepDuration.toInt()}h ${((_healthData.sleepDuration - _healthData.sleepDuration.toInt()) * 60).toInt()}m"
                            : "--",
                        unit: "",
                        icon: "🌙",
                        color: const Color(0xFF8F6BFF),
                        subtitle: "Goal: ${_sleepGoal.round()} hrs",
                      ),
                    ],
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
                SliverToBoxAdapter(
                  child: _buildActiveChallengeCard(theme, isDark),
                ),

                // Your Last 12 Days Graph
                SliverToBoxAdapter(
                  child: _buildLastDaysActivityBarGraph(theme, isDark),
                ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
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
    final List<double> heights = [
      0.3,
      0.45,
      0.2,
      0.55,
      0.65,
      0.4,
      0.75,
      0.6,
      0.8,
      0.85,
      0.7,
      0.9,
    ];

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
            "YOUR LAST 12 DAYS",
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SizedBox(
              height: 45,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: heights.map((h) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      height: 45 * h,
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFFFB03A,
                        ).withOpacity(h > 0.7 ? 0.85 : 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
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
}
