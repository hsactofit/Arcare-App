import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

  // Custom goals
  final double _stepGoal = 10000.0;
  final double _waterGoal = 2500.0;
  final double _calorieGoal = 600.0;
  final double _exerciseGoal = 60.0;
  final double _sleepGoal = 8.0;

  // Onboarding & Setup States
  bool _healthSetupCompleted = false;
  bool _healthConnectRequested = false;
  bool _showGuide = false;

  // Server-synced states
  int? _serverWellnessScore;
  String? _serverDailySummary;
  List<String> _serverRecommendations = [];

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
                setState(() {
                  if (metric == "Water") {
                    _healthData = _healthData.copyWith(
                      waterIntake: _healthData.waterIntake + val,
                    );
                  } else if (metric == "Weight") {
                    _healthData = _healthData.copyWith(weight: val);
                  } else if (metric == "Sleep") {
                    _healthData = _healthData.copyWith(
                      sleepDuration: val,
                      sleepQuality: "Manual Log",
                    );
                  } else if (metric == "Steps") {
                    _healthData = _healthData.copyWith(
                      steps: _healthData.steps + val.round(),
                    );
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _checkStatusAndSync() async {
    setState(() => _isSyncing = true);

    if (Platform.isAndroid) {
      final status = await HealthService.instance.getAndroidSdkStatus();
      setState(() => _sdkStatus = status);
    }

    final prefs = await SharedPreferences.getInstance();
    final bool healthSyncEnabled =
        prefs.getBool('health_sync_enabled') ?? false;

    if (healthSyncEnabled) {
      final hasPerms = await HealthService.instance.checkPermissions();
      setState(() => _isConnected = hasPerms);
      if (hasPerms) {
        await _fetchRealData();
      }
    } else {
      setState(() => _isConnected = false);
    }

    setState(() => _isSyncing = false);
  }

  Future<void> _connectHealthServices() async {
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
      await _fetchRealData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Successfully connected to health services!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Failed to grant health permissions. Please enable them to sync data.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
    setState(() => _isSyncing = false);
  }

  Future<void> _fetchRealData() async {
    final data = await HealthService.instance.fetchHealthData();
    setState(() {
      _healthData = data;
      _lastSynced = DateTime.now();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('onboarding_data');
      if (jsonStr != null) {
        final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
        final email = onboarding['auth']?['email'];
        if (email != null) {
          await _syncAndRefreshDashboard(email, data);
        }
      }
    } catch (e) {
      debugPrint("Error in _fetchRealData combined flow: $e");
    }
  }

  Future<void> _syncAndRefreshDashboard(String email, HealthData data) async {
    try {
      final token = await AuthService.instance.getAccessToken();

      // 1. Sync Health Data (POST)
      final syncUrl =
          '${AuthService.apiBaseUrl}/api/health/sync/${Uri.encodeComponent(email)}';
      final syncPayload = {
        'steps': data.steps.round(),
        'calories': (data.activeCalories + data.basalCalories).round(),
        'sleep_duration_hours': data.sleepDuration,
        'water_intake_ml': data.waterIntake.round(),
        'workouts_count': data.workouts,
        'heart_rate_bpm': data.heartRate.round(),
      };

      final response = await http.post(
        Uri.parse(syncUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(syncPayload),
      );

      if (response.statusCode == 200) {
        debugPrint("Successfully synced health telemetry to server.");
      } else {
        debugPrint(
          "Failed to sync health telemetry: ${response.statusCode} - ${response.body}",
        );
      }

      // 2. Fetch Dashboard Metrics (GET)
      final url =
          '${AuthService.apiBaseUrl}/api/dashboard/${Uri.encodeComponent(email)}';
      final responseDash = await http.get(
        Uri.parse(url),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (responseDash.statusCode == 200) {
        final dashData = jsonDecode(responseDash.body);
        setState(() {
          _serverWellnessScore = dashData['wellness_score'];
          _serverDailySummary = dashData['daily_summary'];
          if (dashData['recommendations'] != null) {
            _serverRecommendations = List<String>.from(
              dashData['recommendations'],
            );
          }
        });
        debugPrint("Successfully fetched dashboard data from server.");
      } else {
        debugPrint(
          "Failed to fetch dashboard data: ${responseDash.statusCode} - ${responseDash.body}",
        );
      }
    } catch (e) {
      debugPrint("Error in _syncAndRefreshDashboard: $e");
    }
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
    await _fetchRealData();
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
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Profile Picture
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.4),
                      width: 1.5,
                    ),
                    image: const DecorationImage(
                      image: NetworkImage(
                        "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=256&auto=format&fit=crop",
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello, Champion! ✨",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      _lastSynced != null
                          ? "Last synced: ${_formatLastSynced(_lastSynced!)}"
                          : "Ready to sync your wellness?",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                // Debug Onboarding Inspector
                IconButton(
                  icon: const Icon(
                    Icons.data_object_outlined,
                    color: Colors.blueAccent,
                  ),
                  tooltip: "View Onboarding Data",
                  onPressed: _showOnboardingDataDialog,
                ),
                const SizedBox(width: 4),
                // Notification Icon
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("No new notifications")),
                        );
                      },
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
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
            const Text("🔌", style: TextStyle(fontSize: 28)),
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
        // 1. Dashboard Banner
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

                // 2. Setup Progress
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

                // 3. Actions
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

        // 4. Google Fit Setup Guide (collapsible)
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

        // 5. Default Empty Metric Cards (Waiting state placeholders)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Activity Status",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.15,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildPlaceholderCard(
                "Steps",
                "Waiting for Health Data...",
                "🚶",
                Colors.green,
                isDark,
              ),
              _buildPlaceholderCard(
                "Sleep",
                "Waiting for Health Data...",
                "🌙",
                Colors.purple,
                isDark,
              ),
              _buildPlaceholderCard(
                "Calories",
                "Waiting for Health Data...",
                "🔥",
                Colors.orange,
                isDark,
              ),
              _buildPlaceholderCard(
                "Distance",
                "Waiting for Health Data...",
                "📍",
                Colors.blue,
                isDark,
              ),
            ],
          ),
        ),

        // 6. User Confirmation Card
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
                          "Verify Again",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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
        // 1. Verified No Data Mode Banner
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

        // 2. Zero Value Metric Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Health Records (Zero Values)",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.15,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              MetricCard(
                title: "Steps",
                value: "0",
                unit: "steps",
                icon: "🚶",
                color: Colors.green,
                progress: 0.0,
                subtitle: "Goal: ${_stepGoal.round()}",
              ),
              MetricCard(
                title: "Calories",
                value: "0",
                unit: "kcal",
                icon: "🔥",
                color: Colors.orange,
                progress: 0.0,
                subtitle: "Goal: ${_calorieGoal.round()}",
              ),
              MetricCard(
                title: "Sleep",
                value: "0",
                unit: "h",
                icon: "🌙",
                color: Colors.purple,
                progress: 0.0,
                subtitle: "Goal: ${_sleepGoal.round()} hrs",
              ),
              MetricCard(
                title: "Distance",
                value: "0",
                unit: "km",
                icon: "📍",
                color: Colors.blue,
                subtitle: "Walking / Running",
              ),
              MetricCard(
                title: "Move Minutes",
                value: "0",
                unit: "min",
                icon: "⏱️",
                color: Colors.cyan,
                progress: 0.0,
                subtitle: "Goal: ${_exerciseGoal.round()} mins",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWellnessScoreCard(ThemeData theme, bool isDark) {
    final score = _wellnessScore;
    Color scoreColor = Colors.orange;
    String evaluation = "Fair";
    if (score >= 80) {
      scoreColor = Colors.green;
      evaluation = "Excellent";
    } else if (score >= 60) {
      scoreColor = Colors.blueAccent;
      evaluation = "Good";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: score / 100.0,
                    strokeWidth: 8,
                    backgroundColor: scoreColor.withOpacity(0.12),
                    color: scoreColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  "$score",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your Wellness Score",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      evaluation,
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Calculated from steps, sleep, and water intake stats.",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendationCard(ThemeData theme, bool isDark) {
    String recommendationText =
        "Not enough sync data yet to generate advanced advice. Complete a full day of activity tracking to unlock personalized AI recommendation models.";

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
                const Text("🤖", style: TextStyle(fontSize: 24)),
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
                  const Row(
                    children: [
                      Text("💧", style: TextStyle(fontSize: 28)),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Water Intake",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            "Stay hydrated throughout the day",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    "${_healthData.waterIntake.round()} / ${_waterGoal.round()} ml",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
                  final shellState = context
                      .findAncestorStateOfType<MainShellState>();
                  shellState?.setIndex(1); // Switch to Water Logging screen
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
                SliverToBoxAdapter(
                  child: _buildAIRecommendationCard(theme, isDark),
                ),

                // Daily Activity Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 16,
                      bottom: 8,
                    ),
                    child: Text(
                      "Daily Activity",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.15,
                    children: [
                      MetricCard(
                        title: "Steps",
                        value: _healthData.steps.round().toString(),
                        unit: "steps",
                        icon: "🚶",
                        color: Colors.green,
                        progress: _healthData.steps / _stepGoal,
                        subtitle: "Goal: ${_stepGoal.round()}",
                      ),
                      MetricCard(
                        title: "Active Energy",
                        value: _healthData.activeCalories.round().toString(),
                        unit: "kcal",
                        icon: "🔥",
                        color: Colors.orange,
                        progress: _healthData.activeCalories / _calorieGoal,
                        subtitle: "Goal: ${_calorieGoal.round()} kcal",
                      ),
                      MetricCard(
                        title: "Sleep Duration",
                        value: "${_healthData.sleepDuration} hrs",
                        unit: "",
                        icon: "🌙",
                        color: Colors.purpleAccent,
                        progress: _healthData.sleepDuration / _sleepGoal,
                        subtitle: "Goal: ${_sleepGoal.round()} hrs",
                      ),
                    ],
                  ),
                ),

                // Hydration (Water Intake)
                _buildWaterIntakeSliver(theme, isDark),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
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
