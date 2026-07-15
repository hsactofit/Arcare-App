import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class NutritionLog {
  final int? id;
  final String foodName;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final DateTime timestamp;

  NutritionLog({
    this.id,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.timestamp,
  });

  factory NutritionLog.fromJson(Map<String, dynamic> json) {
    return NutritionLog(
      id: json['id'] as int?,
      foodName: json['food_name'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class NutritionLoggingScreen extends StatefulWidget {
  final VoidCallback? onFoodLogged;
  const NutritionLoggingScreen({super.key, this.onFoodLogged});

  @override
  State<NutritionLoggingScreen> createState() => _NutritionLoggingScreenState();
}

class _NutritionLoggingScreenState extends State<NutritionLoggingScreen>
    with TickerProviderStateMixin {
  // Daily goal defaults
  final double _calorieGoal = 2000.0;

  // Today's totals from API
  double _caloriesToday = 0;
  double _proteinToday = 0;
  double _fatToday = 0;
  double _carbsToday = 0;

  bool _isLoading = true;
  bool _isSyncing = false;
  List<NutritionLog> _logs = [];

  // Graph state
  String _selectedGraphPeriod = "week";
  List<Map<String, dynamic>> _graphData = [];
  bool _isLoadingGraph = false;

  // Form controllers
  final TextEditingController _foodNameCtrl = TextEditingController();
  final TextEditingController _caloriesCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _fatCtrl = TextEditingController();
  final TextEditingController _carbsCtrl = TextEditingController();

  // Animations
  late AnimationController _ringController;
  late AnimationController _graphAnimController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _graphAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fetchData();
    _fetchGraphData();
  }

  @override
  void dispose() {
    _foodNameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    _ringController.dispose();
    _graphAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final email = await ApiService.instance.getUserEmail();
      final result = await ApiService.instance.fetchNutritionLogs(email);

      final logsRaw = result['logs'] as List<dynamic>? ?? [];
      setState(() {
        _caloriesToday = (result['calories_today'] as num?)?.toDouble() ?? 0;
        _proteinToday = (result['protein_today'] as num?)?.toDouble() ?? 0;
        _fatToday = (result['fat_today'] as num?)?.toDouble() ?? 0;
        _carbsToday = (result['carbs_today'] as num?)?.toDouble() ?? 0;
        _logs = logsRaw
            .map((e) => NutritionLog.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _isLoading = false;
      });
      _ringController.forward(from: 0.0);
    } catch (e) {
      debugPrint("Error fetching nutrition: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchGraphData() async {
    setState(() => _isLoadingGraph = true);
    try {
      final email = await ApiService.instance.getUserEmail();
      final result = await ApiService.instance
          .fetchNutritionGraph(email, _selectedGraphPeriod);
      final data = result['data'] as List<dynamic>? ?? [];
      setState(() {
        _graphData =
            data.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoadingGraph = false;
      });
      _graphAnimController.forward(from: 0.0);
    } catch (e) {
      debugPrint("Error fetching nutrition graph: $e");
      setState(() => _isLoadingGraph = false);
    }
  }

  Future<void> _addFoodLog({
    required String foodName,
    required double calories,
    double protein = 0,
    double fat = 0,
    double carbs = 0,
  }) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final email = await ApiService.instance.getUserEmail();
      await ApiService.instance.addNutritionLog(email, {
        'food_name': foodName,
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
      });
      widget.onFoodLogged?.call();
      await _fetchData();
      await _fetchGraphData();
    } catch (e) {
      debugPrint("Error adding food log: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to log food: $e")),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _deleteLog(int logId) async {
    try {
      await ApiService.instance.deleteNutritionLog(logId);
      widget.onFoodLogged?.call();
      await _fetchData();
      await _fetchGraphData();
    } catch (e) {
      debugPrint("Error deleting nutrition log: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Nutrition",
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 22)),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent))
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchData();
                await _fetchGraphData();
              },
              child: ListView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // ─── Calorie Summary Ring ───
                  _buildCalorieSummary(isDark, textColor, subtextColor),
                  const SizedBox(height: 20),

                  // ─── Macro Breakdown ───
                  _buildMacroBreakdown(isDark, textColor),
                  const SizedBox(height: 24),

                  // ─── Quick Add Food ───
                  _buildQuickAddSection(isDark, textColor, subtextColor),
                  const SizedBox(height: 24),

                  // ─── Custom Log Form ───
                  _buildCustomLogForm(isDark, textColor, subtextColor),
                  const SizedBox(height: 24),

                  // ─── Today's Logs ───
                  _buildLogsSection(isDark, textColor, subtextColor),
                  const SizedBox(height: 24),

                  // ─── Graph ───
                  _buildGraphSection(isDark, textColor),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  // ──────────────────────────────────────────────────
  //  Calorie Summary Ring
  // ──────────────────────────────────────────────────
  Widget _buildCalorieSummary(
      bool isDark, Color textColor, Color subtextColor) {
    final progress = (_caloriesToday / _calorieGoal).clamp(0.0, 1.0);
    final remaining = (_calorieGoal - _caloriesToday).clamp(0, double.infinity);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _ringController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _CalorieRingPainter(
                    progress: progress * _ringController.value,
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${_caloriesToday.round()}",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        Text("kcal",
                            style:
                                TextStyle(fontSize: 11, color: subtextColor)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          // Info text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Intake",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textColor)),
                const SizedBox(height: 8),
                _infoRow("Goal", "${_calorieGoal.round()} kcal", subtextColor),
                const SizedBox(height: 4),
                _infoRow("Consumed", "${_caloriesToday.round()} kcal",
                    Colors.orangeAccent),
                const SizedBox(height: 4),
                _infoRow("Remaining", "${remaining.round()} kcal",
                    remaining > 0 ? Colors.green : Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor)),
      ],
    );
  }

  // ──────────────────────────────────────────────────
  //  Macro Breakdown
  // ──────────────────────────────────────────────────
  Widget _buildMacroBreakdown(bool isDark, Color textColor) {
    return Row(
      children: [
        _macroCard("Protein", _proteinToday, "g", Colors.green, isDark),
        const SizedBox(width: 10),
        _macroCard("Carbs", _carbsToday, "g", Colors.blue, isDark),
        const SizedBox(width: 10),
        _macroCard("Fat", _fatToday, "g", Colors.orange, isDark),
      ],
    );
  }

  Widget _macroCard(
      String label, double value, String unit, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? color.withOpacity(0.12)
              : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text("${value.round()}$unit",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────
  //  Quick Add Food Presets
  // ──────────────────────────────────────────────────
  Widget _buildQuickAddSection(
      bool isDark, Color textColor, Color subtextColor) {
    final presets = [
      {"name": "Apple", "emoji": "🍎", "cal": 95.0, "p": 0.5, "f": 0.3, "c": 25.0},
      {"name": "Banana", "emoji": "🍌", "cal": 105.0, "p": 1.3, "f": 0.4, "c": 27.0},
      {"name": "Chicken Breast", "emoji": "🍗", "cal": 165.0, "p": 31.0, "f": 3.6, "c": 0.0},
      {"name": "Rice (1 cup)", "emoji": "🍚", "cal": 206.0, "p": 4.3, "f": 0.4, "c": 45.0},
      {"name": "Egg", "emoji": "🥚", "cal": 78.0, "p": 6.0, "f": 5.0, "c": 0.6},
      {"name": "Salad", "emoji": "🥗", "cal": 120.0, "p": 3.0, "f": 7.0, "c": 12.0},
      {"name": "Bread (1 slice)", "emoji": "🍞", "cal": 79.0, "p": 2.7, "f": 1.0, "c": 15.0},
      {"name": "Milk (1 glass)", "emoji": "🥛", "cal": 149.0, "p": 8.0, "f": 8.0, "c": 12.0},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Quick Add",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 4),
        Text("Tap to log instantly",
            style: TextStyle(fontSize: 12, color: subtextColor)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((p) {
            return GestureDetector(
              onTap: _isSyncing
                  ? null
                  : () => _addFoodLog(
                        foodName: p['name'] as String,
                        calories: p['cal'] as double,
                        protein: p['p'] as double,
                        fat: p['f'] as double,
                        carbs: p['c'] as double,
                      ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p['emoji'] as String,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(p['name'] as String,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white70
                                : Colors.black87)),
                    const SizedBox(width: 4),
                    Text("${(p['cal'] as double).round()}",
                        style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.orangeAccent
                                : Colors.deepOrange,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────
  //  Custom Log Form
  // ──────────────────────────────────────────────────
  Widget _buildCustomLogForm(
      bool isDark, Color textColor, Color subtextColor) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Log Custom Food",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 16),
          _buildTextField(_foodNameCtrl, "Food name", isDark,
              icon: Icons.restaurant),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildTextField(
                      _caloriesCtrl, "Calories", isDark,
                      keyboardType: TextInputType.number,
                      icon: Icons.local_fire_department)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildTextField(
                      _proteinCtrl, "Protein (g)", isDark,
                      keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildTextField(_fatCtrl, "Fat (g)", isDark,
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildTextField(
                      _carbsCtrl, "Carbs (g)", isDark,
                      keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSyncing ? null : _submitCustomLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Log Food",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String hint, bool isDark,
      {TextInputType keyboardType = TextInputType.text, IconData? icon}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon,
                size: 18,
                color: isDark ? Colors.white30 : Colors.black26)
            : null,
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _submitCustomLog() {
    final name = _foodNameCtrl.text.trim();
    final cal = double.tryParse(_caloriesCtrl.text.trim()) ?? 0;
    if (name.isEmpty || cal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a food name and calories")),
      );
      return;
    }

    final protein = double.tryParse(_proteinCtrl.text.trim()) ?? 0;
    final fat = double.tryParse(_fatCtrl.text.trim()) ?? 0;
    final carbs = double.tryParse(_carbsCtrl.text.trim()) ?? 0;

    _addFoodLog(
      foodName: name,
      calories: cal,
      protein: protein,
      fat: fat,
      carbs: carbs,
    ).then((_) {
      _foodNameCtrl.clear();
      _caloriesCtrl.clear();
      _proteinCtrl.clear();
      _fatCtrl.clear();
      _carbsCtrl.clear();
    });
  }

  // ──────────────────────────────────────────────────
  //  Today's Logs
  // ──────────────────────────────────────────────────
  Widget _buildLogsSection(
      bool isDark, Color textColor, Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Today's Food Log",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor)),
            Text("${_logs.length} entries",
                style: TextStyle(fontSize: 12, color: subtextColor)),
          ],
        ),
        const SizedBox(height: 12),
        if (_logs.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  const Text("🍽️", style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  Text("No food logged yet",
                      style: TextStyle(
                          fontSize: 14,
                          color: subtextColor,
                          fontWeight: FontWeight.w600)),
                  Text("Use the quick add or form above",
                      style: TextStyle(fontSize: 12, color: subtextColor)),
                ],
              ),
            ),
          )
        else
          ..._logs.map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Dismissible(
                  key: Key('nutrition_log_${log.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                  ),
                  onDismissed: (_) {
                    if (log.id != null) _deleteLog(log.id!);
                  },
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text("🍽️",
                                style: TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log.foodName,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87)),
                              const SizedBox(height: 2),
                              Text(
                                "P: ${log.protein.round()}g · C: ${log.carbs.round()}g · F: ${log.fat.round()}g",
                                style: TextStyle(
                                    fontSize: 11, color: subtextColor),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${log.calories.round()} kcal",
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.orangeAccent)),
                            Text(
                              _formatTime(log.timestamp),
                              style: TextStyle(
                                  fontSize: 10, color: subtextColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $amPm";
  }

  // ──────────────────────────────────────────────────
  //  Graph Section
  // ──────────────────────────────────────────────────
  Widget _buildGraphSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Nutrition Trends",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 12),
        // Period tabs
        Row(
          children: ["day", "week", "month"].map((p) {
            final isSelected = _selectedGraphPeriod == p;
            final label =
                p == "day" ? "Day" : p == "week" ? "Week" : "Month";
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                selectedColor: Colors.orangeAccent,
                backgroundColor: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.03),
                side: BorderSide(
                  color: isSelected
                      ? Colors.orangeAccent
                      : (isDark ? Colors.white10 : Colors.black12),
                ),
                label: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? Colors.white70
                                : Colors.black87))),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedGraphPeriod = p);
                    _fetchGraphData();
                  }
                },
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 200,
            child: _isLoadingGraph
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.orangeAccent, strokeWidth: 2))
                : _graphData.isEmpty
                    ? Center(
                        child: Text("No data for this period",
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38)))
                    : AnimatedBuilder(
                        animation: _graphAnimController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: Size.infinite,
                            painter: _NutritionBarChartPainter(
                              data: _graphData,
                              isDark: isDark,
                              animProgress: _graphAnimController.value,
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Calorie Ring Painter
// ──────────────────────────────────────────────────────────────
class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _CalorieRingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;

    // Background ring
    final bgPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: const [
          Color(0xFFFFA726),
          Color(0xFFFF7043),
          Color(0xFFFFA726),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter old) =>
      old.progress != progress;
}

// ──────────────────────────────────────────────────────────────
//  Nutrition Bar Chart Painter
// ──────────────────────────────────────────────────────────────
class _NutritionBarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool isDark;
  final double animProgress;

  _NutritionBarChartPainter({
    required this.data,
    required this.isDark,
    required this.animProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Extract calorie values
    final values =
        data.map((d) => (d['calories'] as num?)?.toDouble() ?? 0.0).toList();
    final labels =
        data.map((d) => (d['label'] as String?) ?? '').toList();

    final maxVal = values.reduce(max);
    if (maxVal == 0) return;

    final int count = values.length;
    const double bottomPadding = 28;
    const double topPadding = 12;
    final double chartHeight = size.height - bottomPadding - topPadding;
    final double barWidth = (size.width / count) * 0.55;
    final double spacing = size.width / count;

    // Grid lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = topPadding + chartHeight * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Bars
    for (int i = 0; i < count; i++) {
      final normalised = values[i] / maxVal;
      final barHeight = chartHeight * normalised * animProgress;
      final x = spacing * i + (spacing - barWidth) / 2;
      final y = topPadding + chartHeight - barHeight;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(6),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFA726),
            const Color(0xFFFF7043).withOpacity(0.6),
          ],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));
      canvas.drawRRect(barRect, paint);

      // Value label
      if (animProgress > 0.8) {
        final tp = TextPainter(
          text: TextSpan(
            text: _formatValue(values[i]),
            style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(x + barWidth / 2 - tp.width / 2, y - tp.height - 4));
      }

      // Label
      final labelText = _shortLabel(labels.length > i ? labels[i] : '');
      final labelTp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white54 : Colors.black45),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(
          canvas,
          Offset(x + barWidth / 2 - labelTp.width / 2,
              size.height - bottomPadding + 6));
    }
  }

  String _formatValue(double v) {
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(1)}k";
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(0);
  }

  String _shortLabel(String label) {
    if (label.contains('W')) return label.split('-').last;
    final parts = label.split('-');
    if (parts.length == 3) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final m = int.tryParse(parts[1]) ?? 1;
      return "${months[m.clamp(1, 12) - 1]} ${int.tryParse(parts[2]) ?? ''}";
    }
    if (parts.length == 2) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final m = int.tryParse(parts[1]) ?? 1;
      return months[m.clamp(1, 12) - 1];
    }
    return label;
  }

  @override
  bool shouldRepaint(covariant _NutritionBarChartPainter old) =>
      old.animProgress != animProgress || old.data != data;
}
