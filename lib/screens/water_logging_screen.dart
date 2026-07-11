import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/health_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/water/wave_painter.dart';

class WaterLog {
  final String? id;
  final int amount;
  final DateTime timestamp;
  WaterLog({this.id, required this.amount, required this.timestamp});

  factory WaterLog.fromJson(Map<String, dynamic> json) {
    return WaterLog(
      id: json['id']?.toString(),
      amount: json['amount'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class WaterLoggingScreen extends StatefulWidget {
  final VoidCallback? onWaterLogged;
  const WaterLoggingScreen({super.key, this.onWaterLogged});

  @override
  State<WaterLoggingScreen> createState() => _WaterLoggingScreenState();
}

class _WaterLoggingScreenState extends State<WaterLoggingScreen>
    with TickerProviderStateMixin {
  final double _waterGoal = 2500.0; // Daily Goal in ml
  double _currentIntake = 0.0;
  bool _isSyncing = false;
  bool _isLoadingLogs = true;
  bool _logsExpanded = false;
  List<WaterLog> _waterLogs = [];

  // Graph states
  String _selectedGraphPeriod = "week"; // "day", "week", "month"
  List<Map<String, dynamic>> _graphData = [];
  bool _isLoadingGraph = false;

  late AnimationController _waveController;
  late AnimationController _levelController;
  Animation<double>? _levelAnimation;
  double _startIntakeProgress = 0.0;
  double _targetIntakeProgress = 0.0;

  final TextEditingController _customController = TextEditingController();

  // Bubble animation particle system
  final List<BubbleParticle> _bubbles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Wave ripple animation loop
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Liquid level transition controller
    _levelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _loadLocalWater();
    _fetchLogs(); // Retrieve 7 water logs first time
    _fetchGraphData(); // Load graph trend data
    _initializeBubbles();

    // Listen to wave ripples to update bubble particles
    _waveController.addListener(_updateBubbles);
  }

  void _loadLocalWater() {
    // Read the current local water intake from HealthService
    final currentLocal = HealthService.instance.localWaterIntake;
    setState(() {
      _currentIntake = currentLocal;
      _startIntakeProgress = (_currentIntake / _waterGoal).clamp(0.0, 1.0);
      _targetIntakeProgress = _startIntakeProgress;
    });
  }

  Future<void> _fetchGraphData() async {
    setState(() => _isLoadingGraph = true);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('onboarding_data');
    if (jsonStr == null) {
      setState(() => _isLoadingGraph = false);
      return;
    }

    final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
    final email = onboarding['auth']?['email'];
    if (email == null) {
      setState(() => _isLoadingGraph = false);
      return;
    }

    try {
      final token = await AuthService.instance.getAccessToken();
      final url =
          '${AuthService.apiBaseUrl}/api/water/graph/${Uri.encodeComponent(email)}?period=$_selectedGraphPeriod';

      var response = await http.get(
        Uri.parse(url),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        await AuthService.instance.refreshSessionToken();
        final newToken = await AuthService.instance.getAccessToken();
        response = await http.get(
          Uri.parse(url),
          headers: {if (newToken != null) 'Authorization': 'Bearer $newToken'},
        );
      }

      if (response.statusCode == 200) {
        // Debug log the graph API response
        debugPrint("================ WATER GRAPH API RESPONSE ================");
        debugPrint("Response Body: ${response.body}");
        debugPrint("==========================================================");

        final Map<String, dynamic> resData = jsonDecode(response.body);
        final List<dynamic> dataList = resData['data'] ?? [];
        setState(() {
          _graphData = List<Map<String, dynamic>>.from(dataList);
          _isLoadingGraph = false;
        });
      } else {
        setState(() => _isLoadingGraph = false);
      }
    } catch (e) {
      debugPrint("Error fetching water graph: $e");
      setState(() => _isLoadingGraph = false);
    }
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoadingLogs = true);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('onboarding_data');
    if (jsonStr == null) {
      setState(() => _isLoadingLogs = false);
      return;
    }

    final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
    final email = onboarding['auth']?['email'];
    if (email == null) {
      setState(() => _isLoadingLogs = false);
      return;
    }

    try {
      final token = await AuthService.instance.getAccessToken();
      final url =
          '${AuthService.apiBaseUrl}/api/water/logs/${Uri.encodeComponent(email)}';

      var response = await http.get(
        Uri.parse(url),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        await AuthService.instance.refreshSessionToken();
        final newToken = await AuthService.instance.getAccessToken();
        response = await http.get(
          Uri.parse(url),
          headers: {if (newToken != null) 'Authorization': 'Bearer $newToken'},
        );
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> resData = jsonDecode(response.body);
        final int totalToday = resData['water_intake_today'] ?? 0;
        final List<dynamic> logsJson = resData['logs'] ?? [];

        await HealthService.instance.setWaterIntakeToday(totalToday.toDouble());

        setState(() {
          debugPrint('Water logs fetched successfully: $resData');
          _currentIntake = totalToday.toDouble();
          _startIntakeProgress = (_currentIntake / _waterGoal).clamp(0.0, 1.0);
          _targetIntakeProgress = _startIntakeProgress;
          _waterLogs = logsJson.map((x) => WaterLog.fromJson(x)).toList();
          _isLoadingLogs = false;
        });
      } else {
        setState(() => _isLoadingLogs = false);
      }
    } catch (e) {
      debugPrint("Error fetching water logs: $e");
      setState(() => _isLoadingLogs = false);
    }
  }

  void _initializeBubbles() {
    for (int i = 0; i < 20; i++) {
      _bubbles.add(
        BubbleParticle(
          x: _random.nextDouble(),
          y: _random.nextDouble(), // Distribute vertically initially
          radius: 2.0 + _random.nextDouble() * 4.0,
          speed: 0.003 + _random.nextDouble() * 0.005,
        ),
      );
    }
  }

  void _updateBubbles() {
    if (!mounted) return;
    setState(() {
      for (var bubble in _bubbles) {
        // Move bubbles upward
        bubble.y -= bubble.speed;
        // Wiggle slightly horizontally
        bubble.x += sin(_waveController.value * 2 * pi + bubble.y * 10) * 0.002;

        // Reset bubble to bottom if it floats out of water boundary
        final double waterTopY = 1.0 - _getCurrentVisualProgress();
        if (bubble.y < waterTopY || bubble.x < 0 || bubble.x > 1) {
          bubble.y = 1.0;
          bubble.x = _random.nextDouble();
          bubble.speed = 0.003 + _random.nextDouble() * 0.005;
        }
      }
    });
  }

  double _getCurrentVisualProgress() {
    if (_levelAnimation == null) return _targetIntakeProgress;
    return _levelAnimation!.value;
  }

  Future<void> _logWater(int amount) async {
    if (amount <= 0) return;

    setState(() => _isSyncing = true);

    // Save locally
    final success = await HealthService.instance.logWater(amount);

    if (success) {
      final now = DateTime.now();
      final oldIntake = _currentIntake;
      final newIntake = oldIntake + amount;

      // Setup level rise animation
      _startIntakeProgress = (oldIntake / _waterGoal).clamp(0.0, 1.0);
      _targetIntakeProgress = (newIntake / _waterGoal).clamp(0.0, 1.0);

      _levelAnimation =
          Tween<double>(
            begin: _startIntakeProgress,
            end: _targetIntakeProgress,
          ).animate(
            CurvedAnimation(
              parent: _levelController,
              curve: Curves.easeOutBack,
            ),
          );

      setState(() {
        _currentIntake = newIntake;
      });

      _levelController.reset();
      _levelController.forward();

      // Refresh parent dashboard
      if (widget.onWaterLogged != null) {
        widget.onWaterLogged!();
      }

      // Sync to API with Auth & Refresh Token
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

            // Debug log the logged water API response
            debugPrint("================ SYNC MANUAL WATER API RESPONSE ================");
            debugPrint("Status Code: ${response.statusCode}");
            debugPrint("Response Body: ${response.body}");
            debugPrint("=================================================================");
          }
        }
      } catch (e) {
        debugPrint("Error syncing logged water to backend: $e");
      }

      // Reload graph and logs history list
      await _fetchLogs();
      await _fetchGraphData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logged +$amount ml of water!"),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error logging water locally."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    setState(() => _isSyncing = false);
  }

  Future<void> _deleteLog(WaterLog log) async {
    if (log.id == null) return;
    setState(() => _isSyncing = true);

    try {
      final token = await AuthService.instance.getAccessToken();
      final url = '${AuthService.apiBaseUrl}/api/water/log/${log.id}';

      var response = await http.delete(
        Uri.parse(url),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        await AuthService.instance.refreshSessionToken();
        final newToken = await AuthService.instance.getAccessToken();
        response = await http.delete(
          Uri.parse(url),
          headers: {if (newToken != null) 'Authorization': 'Bearer $newToken'},
        );
      }

      // Debug log the delete water log API response
      debugPrint("================ DELETE WATER LOG API RESPONSE ================");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");
      debugPrint("===============================================================");

      if (response.statusCode == 200) {
        // Adjust local pref data
        await HealthService.instance.updateLocalWaterIntake(
          -log.amount.toDouble(),
        );

        setState(() {
          _waterLogs.removeWhere((x) => x.id == log.id);
          _currentIntake = (_currentIntake - log.amount).clamp(
            0.0,
            double.infinity,
          );
          _startIntakeProgress = (_currentIntake / _waterGoal).clamp(0.0, 1.0);
          _targetIntakeProgress = _startIntakeProgress;
        });

        // Trigger callback to refresh Dashboard
        if (widget.onWaterLogged != null) {
          widget.onWaterLogged!();
        }

        // Fetch graph and logs fresh
        await _fetchGraphData();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Log deleted successfully")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to delete log")));
      }
    } catch (e) {
      debugPrint("Error deleting log: $e");
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _showEditDialog(WaterLog log) async {
    final controller = TextEditingController(text: log.amount.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Water Log"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "Enter amount (ml)",
              prefixIcon: Icon(Icons.water_drop, color: Colors.blueAccent),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = int.tryParse(controller.text) ?? 0;
                if (amount > 0) {
                  Navigator.pop(context);
                  _updateLog(log, amount);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateLog(WaterLog log, int newAmount) async {
    if (log.id == null) return;
    setState(() => _isSyncing = true);

    try {
      final token = await AuthService.instance.getAccessToken();
      final url = '${AuthService.apiBaseUrl}/api/water/log/${log.id}';

      var response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': newAmount,
          'timestamp': log.timestamp.toIso8601String(),
        }),
      );

      if (response.statusCode == 401) {
        await AuthService.instance.refreshSessionToken();
        final newToken = await AuthService.instance.getAccessToken();
        response = await http.put(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            if (newToken != null) 'Authorization': 'Bearer $newToken',
          },
          body: jsonEncode({
            'amount': newAmount,
            'timestamp': log.timestamp.toIso8601String(),
          }),
        );
      }

      // Debug log the update water log API response
      debugPrint("================ UPDATE WATER LOG API RESPONSE ================");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");
      debugPrint("===============================================================");

      if (response.statusCode == 200) {
        final delta = (newAmount - log.amount).toDouble();
        await HealthService.instance.updateLocalWaterIntake(delta);

        setState(() {
          final idx = _waterLogs.indexWhere((x) => x.id == log.id);
          if (idx != -1) {
            _waterLogs[idx] = WaterLog(
              id: log.id,
              amount: newAmount,
              timestamp: log.timestamp,
            );
          }
          _currentIntake = (_currentIntake + delta).clamp(0.0, double.infinity);
          _startIntakeProgress = (_currentIntake / _waterGoal).clamp(0.0, 1.0);
          _targetIntakeProgress = _startIntakeProgress;
        });

        // Trigger callback to refresh Dashboard
        if (widget.onWaterLogged != null) {
          widget.onWaterLogged!();
        }

        // Fetch graph data fresh
        await _fetchGraphData();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Log updated successfully")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to update log")));
      }
    } catch (e) {
      debugPrint("Error updating log: $e");
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _levelController.dispose();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentVisualProgress = _getCurrentVisualProgress();

    return Scaffold(
      body: Stack(
        children: [
          // 1. Glowing Morphic Background
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          Positioned(
            top: -50,
            left: -50,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(isDark ? 0.25 : 0.20),
                    Colors.blue.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            right: -80,
            width: 350,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.cyan.withOpacity(isDark ? 0.20 : 0.15),
                    Colors.cyan.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Main Scrollable Panel
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Screen Title with back button
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        const Text("💧", style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Hydration Tracker",
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              "Log water & watch the waves rise",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Beaker cylinder wave animation
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 190,
                            height: 310,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(
                                    isDark ? 0.15 : 0.05,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(36),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                width: 180,
                                height: 300,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.03)
                                      : Colors.black.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(36),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.12)
                                        : Colors.black.withOpacity(0.08),
                                    width: 2.0,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _waveController,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          painter: WavePainter(
                                            progress: currentVisualProgress,
                                            wavePhase:
                                                _waveController.value * 2 * pi,
                                            bubbles: _bubbles,
                                            isDark: isDark,
                                          ),
                                          size: const Size(180, 300),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: Container(
                              width: 180,
                              height: 300,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 24,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _beakerTick("2500 ml", isDark),
                                  _beakerTick("2000 ml", isDark),
                                  _beakerTick("1500 ml", isDark),
                                  _beakerTick("1000 ml", isDark),
                                  _beakerTick("500 ml", isDark),
                                  _beakerTick("0 ml", isDark),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress Summary Display
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "${_currentIntake.round()} ml / ${_waterGoal.round()} ml",
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.blueAccent,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Daily Progress: ${(_targetIntakeProgress * 100).round()}%",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick logging preset cards with assets
                    Text(
                      "Quick Logging",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPresetCard(
                          "assets/water-cup.png",
                          "Cup",
                          250,
                          isDark,
                        ),
                        _buildPresetCard(
                          "assets/water_bottle.png",
                          "Bottle",
                          500,
                          isDark,
                        ),
                        _buildPresetCard(
                          "assets/flask-water.png",
                          "Flask",
                          750,
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Custom Logger Input
                    Text(
                      "Custom Amount",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isDark ? 0.15 : 0.03,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _customController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter volume (ml)",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.blueAccent,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                prefixIcon: const Icon(
                                  Icons.water_drop,
                                  color: Colors.blueAccent,
                                ),
                                fillColor: isDark
                                    ? const Color(0xFF1E1E26)
                                    : Colors.white,
                                filled: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            shadowColor: Colors.blueAccent.withOpacity(0.3),
                          ),
                          onPressed: _isSyncing
                              ? null
                              : () {
                                  final val =
                                      int.tryParse(_customController.text) ?? 0;
                                  if (val > 0) {
                                    _logWater(val);
                                    _customController.clear();
                                    FocusScope.of(context).unfocus();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Please enter a valid volume amount",
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: const Text(
                            "Log",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Log history stacked view list
                    _buildLogsView(isDark),
                    const SizedBox(height: 28),

                    // Hydration Trends Graph View
                    _buildGraphView(isDark),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _beakerTick(String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: (isDark ? Colors.white30 : Colors.black38),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 8,
          height: 1.5,
          color: (isDark ? Colors.white24 : Colors.black12),
        ),
      ],
    );
  }

  Widget _buildPresetCard(
    String imagePath,
    String label,
    int amount,
    bool isDark,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: _isSyncing ? null : () => _logWater(amount),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Image.asset(
                  imagePath,
                  width: 32,
                  height: 48,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Text(label[0], style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "+$amount ml",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGraphView(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Hydration Trends 📊",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildGraphTab("Day", "day"),
                    _buildGraphTab("Week", "week"),
                    _buildGraphTab("Month", "month"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoadingGraph)
            const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            )
          else if (_graphData.isEmpty)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  "No graph data available",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            _buildChartLine(isDark),
        ],
      ),
    );
  }

  Widget _buildGraphTab(String label, String value) {
    final isSelected = _selectedGraphPeriod == value;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedGraphPeriod = value;
          });
          _fetchGraphData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildChartLine(bool isDark) {
    final List<double> values = _graphData
        .map((e) => (e['amount'] as num).toDouble())
        .toList();
    double maxAmount = values.fold(0.0, max);
    if (maxAmount == 0.0) maxAmount = _waterGoal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              height: 150,
              width: 50,
              padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${maxAmount.round()}",
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${(maxAmount * 0.75).round()}",
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${(maxAmount * 0.5).round()}",
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${(maxAmount * 0.25).round()}",
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "0",
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 150,
                child: CustomPaint(
                  painter: LineChartPainter(
                    values: values,
                    isDark: isDark,
                    maxAmount: maxAmount,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(width: 50),
            Expanded(child: _buildChartTimeline(isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildChartTimeline(bool isDark) {
    if (_graphData.isEmpty) return const SizedBox();

    final int len = _graphData.length;
    final List<Widget> positionedLabels = [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double stepX = len > 1 ? width / (len - 1) : width;

        for (int i = 0; i < len; i++) {
          final label = _graphData[i]['label']?.toString() ?? "";
          String displayLabel = label;
          if (label.length == 10) {
            displayLabel = label.substring(5); // MM-DD
          } else if (label.contains('T')) {
            final parts = label.split('T');
            if (parts.length > 1) {
              displayLabel = parts[1].substring(0, 5); // HH:MM
            }
          }

          // Decide if we should show this label
          bool showLabel = false;
          if (len <= 7) {
            showLabel = (i == 0 || i == len ~/ 2 || i == len - 1);
          } else if (len <= 24) {
            showLabel =
                (i == 0 ||
                i == len ~/ 3 ||
                i == (2 * len) ~/ 3 ||
                i == len - 1);
          } else {
            showLabel = (i == 0 || i == 9 || i == 19 || i == len - 1);
          }

          if (showLabel) {
            final double posX = i * stepX;
            final double left = (posX - 25).clamp(0.0, width - 50);
            positionedLabels.add(
              Positioned(
                left: left,
                width: 50,
                child: Text(
                  displayLabel,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            );
          }
        }

        return SizedBox(
          height: 16,
          child: Stack(clipBehavior: Clip.none, children: positionedLabels),
        );
      },
    );
  }

  Widget _buildLogsView(bool isDark) {
    if (_isLoadingLogs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    if (_waterLogs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "No logs recorded for today yet.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    final hasMultipleLogs = _waterLogs.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Water Logs History",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (hasMultipleLogs)
              TextButton(
                onPressed: () {
                  setState(() {
                    _logsExpanded = !_logsExpanded;
                  });
                },
                child: Text(
                  _logsExpanded ? "Collapse" : "View All",
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasMultipleLogs)
          (_logsExpanded
              ? _buildExpandedLogs(isDark)
              : _buildStackedLogs(isDark))
        else
          _buildSingleLogCard(isDark, _waterLogs.first),
      ],
    );
  }

  Widget _buildSingleLogCard(bool isDark, WaterLog log) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${log.amount} ml logged",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(log.timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_rounded,
              color: Colors.blueAccent,
              size: 18,
            ),
            onPressed: () => _showEditDialog(log),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
            onPressed: () => _deleteLog(log),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedLogs(bool isDark) {
    final displayLogs = _waterLogs.take(3).toList();

    return GestureDetector(
      onTap: () {
        setState(() {
          _logsExpanded = true;
        });
      },
      child: Container(
        height: 80.0 + (displayLogs.length - 1) * 16.0,
        child: Stack(
          children: List.generate(displayLogs.length, (index) {
            // Reverse order for stacking so the latest is on top
            final reversedIndex = displayLogs.length - 1 - index;
            final log = displayLogs[reversedIndex];

            // Layout offsets
            final double offset = reversedIndex * 16.0;
            final double scale = 1.0 - (reversedIndex * 0.05);

            return Positioned(
              left: 0,
              right: 0,
              top: offset,
              child: Transform.scale(
                scale: scale,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${log.amount} ml logged",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(log.timestamp),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.unfold_more_rounded,
                        color: isDark ? Colors.white30 : Colors.black26,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildExpandedLogs(bool isDark) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: min(_waterLogs.length, 7), // Show up to the last 7 logs
          itemBuilder: (context, index) {
            final log = _waterLogs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${log.amount} ml logged",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(log.timestamp),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Colors.blueAccent,
                        size: 18,
                      ),
                      onPressed: () => _showEditDialog(log),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      onPressed: () => _deleteLog(log),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> values;
  final bool isDark;
  final double maxAmount;

  LineChartPainter({
    required this.values,
    required this.isDark,
    required this.maxAmount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    // Draw horizontal grid lines
    final Paint gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final double y = height - (height * i / 4);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    final double stepX = values.length > 1
        ? width / (values.length - 1)
        : width;
    final List<Offset> points = [];

    for (int i = 0; i < values.length; i++) {
      final double x = i * stepX;
      final double normalizedVal = (values[i] / maxAmount).clamp(0.0, 1.0);
      final double y = height - (normalizedVal * (height - 12)) - 6;
      points.add(Offset(x, y));
    }

    // 1. Draw area gradient path under the line
    if (points.isNotEmpty) {
      final Path areaPath = Path()
        ..moveTo(points.first.dx, height)
        ..lineTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final controlX1 = prev.dx + (curr.dx - prev.dx) / 2;
        final controlY1 = prev.dy;
        final controlX2 = prev.dx + (curr.dx - prev.dx) / 2;
        final controlY2 = curr.dy;
        areaPath.cubicTo(
          controlX1,
          controlY1,
          controlX2,
          controlY2,
          curr.dx,
          curr.dy,
        );
      }
      areaPath.lineTo(points.last.dx, height);
      areaPath.close();

      final Paint areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blueAccent.withOpacity(0.25),
            Colors.blueAccent.withOpacity(0.00),
          ],
        ).createShader(Rect.fromLTRB(0, 0, width, height));

      canvas.drawPath(areaPath, areaPaint);
    }

    // 2. Draw smooth line path
    final Path linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final controlX1 = prev.dx + (curr.dx - prev.dx) / 2;
      final controlY1 = prev.dy;
      final controlX2 = prev.dx + (curr.dx - prev.dx) / 2;
      final controlY2 = curr.dy;
      linePath.cubicTo(
        controlX1,
        controlY1,
        controlX2,
        controlY2,
        curr.dx,
        curr.dy,
      );
    }

    final Paint linePaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // 3. Draw dots on data points
    final Paint dotOuterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint dotInnerPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;

    final drawDots = values.length <= 12;
    if (drawDots) {
      for (final pt in points) {
        canvas.drawCircle(pt, 5.0, dotInnerPaint);
        canvas.drawCircle(pt, 2.5, dotOuterPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.isDark != isDark ||
        oldDelegate.maxAmount != maxAmount;
  }
}
