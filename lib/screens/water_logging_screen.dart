import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/water/wave_painter.dart';

/// Matches OpenAPI `WaterLogResponse`: id (int), amount (int), timestamp (date-time).
class WaterLog {
  final int? id;
  final int amount;
  final DateTime timestamp;

  WaterLog({this.id, required this.amount, required this.timestamp});

  factory WaterLog.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'];
    final amount = amountRaw is num
        ? amountRaw.round()
        : int.tryParse('$amountRaw') ?? 0;
    final idRaw = json['id'];
    final id = idRaw is num
        ? idRaw.toInt()
        : int.tryParse('$idRaw');

    return WaterLog(
      id: id,
      amount: amount,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
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

  // Graph states (period: day | week | month per API docs)
  String _selectedGraphPeriod = "week";
  List<Map<String, dynamic>> _graphData = [];
  bool _isLoadingGraph = false;
  String? _graphError;
  String? _logsError;

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
    if (!mounted) return;
    setState(() {
      _isLoadingGraph = true;
      _graphError = null;
    });

    try {
      final email = await ApiService.instance.getUserEmail();
      final resData = await ApiService.instance
          .fetchWaterGraph(email, _selectedGraphPeriod);

      // WaterGraphResponse: { period, data: [{ label, amount }] }
      dynamic raw = resData['data'];
      if (raw is Map) {
        raw = raw['data'] ?? raw['points'] ?? raw['items'];
      }
      raw ??= resData['points'] ?? resData['items'];

      final parsed = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final amountRaw = m['amount'] ?? m['value'] ?? m['water'] ?? 0;
          final amount = amountRaw is num
              ? amountRaw.toDouble()
              : double.tryParse('$amountRaw') ?? 0.0;
          parsed.add({
            'label': (m['label'] ?? m['date'] ?? m['day'] ?? '').toString(),
            'amount': amount,
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _graphData = parsed;
        _isLoadingGraph = false;
        _graphError = null;
      });
    } catch (e) {
      debugPrint("Error fetching water graph: $e");
      if (!mounted) return;
      setState(() {
        _isLoadingGraph = false;
        _graphData = [];
        _graphError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLogs = true;
      _logsError = null;
    });

    try {
      final email = await ApiService.instance.getUserEmail();
      // HydrationHistoryResponse: { water_intake_today, logs: WaterLogResponse[] }
      final resData = await ApiService.instance.fetchWaterLogs(email);

      final totalRaw = resData['water_intake_today'] ?? 0;
      final totalToday = totalRaw is num
          ? totalRaw.round()
          : int.tryParse('$totalRaw') ?? 0;
      final logsJson = resData['logs'] as List<dynamic>? ?? [];

      await HealthService.instance.setWaterIntakeToday(totalToday.toDouble());

      if (!mounted) return;
      setState(() {
        _currentIntake = totalToday.toDouble();
        _startIntakeProgress = (_currentIntake / _waterGoal).clamp(0.0, 1.0);
        _targetIntakeProgress = _startIntakeProgress;
        _waterLogs = logsJson
            .whereType<Map>()
            .map((x) => WaterLog.fromJson(Map<String, dynamic>.from(x)))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _isLoadingLogs = false;
        _logsError = null;
      });
    } catch (e) {
      debugPrint("Error fetching water logs: $e");
      if (!mounted) return;
      setState(() {
        _isLoadingLogs = false;
        _logsError = e.toString().replaceFirst('Exception: ', '');
      });
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
    if (amount <= 0 || _isSyncing) return;

    setState(() => _isSyncing = true);

    // Optimistic local update + animation
    final success = await HealthService.instance.logWater(amount);
    if (success) {
      final oldIntake = _currentIntake;
      final newIntake = oldIntake + amount;
      _startIntakeProgress = (oldIntake / _waterGoal).clamp(0.0, 1.0);
      _targetIntakeProgress = (newIntake / _waterGoal).clamp(0.0, 1.0);
      _levelAnimation = Tween<double>(
        begin: _startIntakeProgress,
        end: _targetIntakeProgress,
      ).animate(
        CurvedAnimation(parent: _levelController, curve: Curves.easeOutBack),
      );
      setState(() => _currentIntake = newIntake);
      _levelController
        ..reset()
        ..forward();
    }

    try {
      // POST /api/water/log/{email} — WaterLogCreate
      final email = await ApiService.instance.getUserEmail();
      await ApiService.instance.addWaterLog(email, {
        'amount': amount,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      widget.onWaterLogged?.call();
      await _fetchLogs();
      await _fetchGraphData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logged +$amount ml of water!"),
          backgroundColor: Colors.blueAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      debugPrint("Error syncing logged water to backend: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to sync water log: ${e.toString().replaceFirst('Exception: ', '')}",
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Re-sync totals from server / local after failure
      await _fetchLogs();
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _deleteLog(WaterLog log) async {
    if (log.id == null || _isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      // DELETE /api/water/log/{log_id}
      await ApiService.instance.deleteWaterLog(log.id!);
      await HealthService.instance.updateLocalWaterIntake(
        -log.amount.toDouble(),
      );

      widget.onWaterLogged?.call();
      await _fetchLogs();
      await _fetchGraphData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Log deleted successfully"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint("Error deleting log: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to delete: ${e.toString().replaceFirst('Exception: ', '')}",
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showEditDialog(WaterLog log) async {
    final controller = TextEditingController(text: log.amount.toString());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Edit Water Log",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Enter amount (ml)",
              prefixIcon:
                  const Icon(Icons.water_drop, color: Colors.blueAccent),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final amount = int.tryParse(controller.text.trim()) ?? 0;
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
    controller.dispose();
  }

  Future<void> _updateLog(WaterLog log, int newAmount) async {
    if (log.id == null || _isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      // PUT /api/water/log/{log_id} — WaterLogCreate body
      final result = await ApiService.instance.updateWaterLog(log.id!, {
        'amount': newAmount,
        'timestamp': log.timestamp.toUtc().toIso8601String(),
      });

      // Prefer server values when present
      final serverAmount = (result['amount'] as num?)?.round() ?? newAmount;
      final serverTs = DateTime.tryParse(result['timestamp']?.toString() ?? '') ??
          log.timestamp;

      final delta = (serverAmount - log.amount).toDouble();
      await HealthService.instance.updateLocalWaterIntake(delta);

      widget.onWaterLogged?.call();
      await _fetchLogs();
      await _fetchGraphData();

      if (!mounted) return;
      // Keep local list snappy if fetch is slow
      setState(() {
        final idx = _waterLogs.indexWhere((x) => x.id == log.id);
        if (idx != -1) {
          _waterLogs[idx] = WaterLog(
            id: log.id,
            amount: serverAmount,
            timestamp: serverTs,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Log updated successfully"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint("Error updating log: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to update: ${e.toString().replaceFirst('Exception: ', '')}",
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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
    final textColor = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? Colors.white54 : Colors.black45;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Hydration Trends",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Refresh graph',
                icon: Icon(Icons.refresh_rounded, size: 18, color: muted),
                onPressed: _isLoadingGraph ? null : _fetchGraphData,
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
          const SizedBox(height: 8),
          Text(
            "Period: day · week · month",
            style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          if (_isLoadingGraph)
            const SizedBox(
              height: 170,
              child: Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            )
          else if (_graphError != null)
            SizedBox(
              height: 170,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: muted, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Could not load graph',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _graphError!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchGraphData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_graphData.isEmpty)
            SizedBox(
              height: 170,
              child: Center(
                child: Text(
                  "No hydration data for this period yet.\nLog some water to see trends.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 13, height: 1.35),
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
          setState(() => _selectedGraphPeriod = value);
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
        .map((e) => (e['amount'] as num?)?.toDouble() ?? 0.0)
        .toList();
    double maxAmount = values.fold(0.0, max);
    if (maxAmount == 0.0) maxAmount = _waterGoal;

    final dense = values.length > 8;
    const minSlot = 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 170,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final neededWidth = values.length * minSlot + 56;
              final chartWidth = max(constraints.maxWidth, neededWidth);
              final plotWidth = chartWidth - 52;

              final chartBody = SizedBox(
                width: chartWidth,
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 48,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6, top: 4, bottom: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final t in [1.0, 0.75, 0.5, 0.25, 0.0])
                              Text(
                                t == 0
                                    ? "0"
                                    : "${(maxAmount * t).round()}",
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: CustomPaint(
                              painter: LineChartPainter(
                                values: values,
                                isDark: isDark,
                                maxAmount: maxAmount,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 22,
                            width: plotWidth,
                            child: _buildChartTimeline(
                              isDark,
                              width: plotWidth,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              if (chartWidth <= constraints.maxWidth + 0.5) {
                return chartBody;
              }

              return Stack(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: chartBody,
                  ),
                  if (dense)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 22,
                      child: IgnorePointer(
                        child: Container(
                          width: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                (isDark
                                        ? const Color(0xFF16161C)
                                        : Colors.white)
                                    .withOpacity(0),
                                (isDark
                                        ? const Color(0xFF16161C)
                                        : Colors.white)
                                    .withOpacity(0.9),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (dense)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Swipe chart to see all ${values.length} points",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          _graphSummaryLine(values),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  String _graphSummaryLine(List<double> values) {
    if (values.isEmpty) return '';
    final total = values.fold<double>(0, (a, b) => a + b);
    final avg = total / values.length;
    return 'Avg ${avg.round()} ml · Total ${total.round()} ml · ${values.length} points';
  }

  Widget _buildChartTimeline(bool isDark, {required double width}) {
    if (_graphData.isEmpty) return const SizedBox();

    final int len = _graphData.length;
    final indexes = _timelineLabelIndexes(len);
    final double stepX = len > 1 ? width / (len - 1) : width;
    final dense = len > 8;

    final labels = <Widget>[];
    for (final i in indexes) {
      final label = _graphData[i]['label']?.toString() ?? "";
      final displayLabel = _formatGraphLabel(label, dense: dense);
      final double posX = i * stepX;
      final double left = (posX - 22).clamp(0.0, max(0.0, width - 44));
      labels.add(
        Positioned(
          left: left,
          width: 44,
          child: Text(
            displayLabel,
            style: TextStyle(
              fontSize: dense ? 8.5 : 9,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return SizedBox(
      height: 22,
      width: width,
      child: Stack(clipBehavior: Clip.none, children: labels),
    );
  }

  Set<int> _timelineLabelIndexes(int count) {
    if (count <= 1) return {0};
    if (count <= 6) return {for (var i = 0; i < count; i++) i};

    final target = count > 16 ? 5 : (count > 8 ? 6 : 8);
    final step = max(1.0, (count - 1) / (target - 1));
    final indexes = <int>{0, count - 1};
    for (var t = 1; t < target - 1; t++) {
      indexes.add((t * step).round().clamp(0, count - 1));
    }
    return indexes;
  }

  String _formatGraphLabel(String label, {bool dense = false}) {
    if (label.isEmpty) return '';

    if (label.contains('T')) {
      try {
        final dt = DateTime.parse(label);
        return dense
            ? '${dt.hour}h'
            : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        final parts = label.split('T');
        if (parts.length > 1 && parts[1].length >= 5) {
          return dense ? '${parts[1].substring(0, 2)}h' : parts[1].substring(0, 5);
        }
      }
    }

    // YYYY-MM-DD
    if (label.length >= 10 && label[4] == '-' && label[7] == '-') {
      if (dense) return label.substring(8, 10); // day
      return label.substring(5, 10); // MM-DD
    }

    if (label.length > (dense ? 4 : 6)) {
      return label.substring(0, dense ? 4 : 6);
    }
    return label;
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

    if (_logsError != null) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              "Could not load water logs",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _logsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            TextButton(onPressed: _fetchLogs, child: const Text("Retry")),
          ],
        ),
      );
    }

    if (_waterLogs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "No logs recorded yet. Tap a quick amount to start.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
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
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

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
