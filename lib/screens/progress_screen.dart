import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  String _selectedPeriod = "Weekly";
  late Future<Map<String, dynamic>> _trendsFuture;
  late AnimationController _chartAnimController;

  bool _isLogsExpanded = false;
  String _selectedGraphMetric = "steps";

  @override
  void initState() {
    super.initState();
    _chartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _trendsFuture = _fetchTrendsFromServer().then((data) {
      _chartAnimController.forward(from: 0.0);
      return data;
    });
  }

  @override
  void dispose() {
    _chartAnimController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchTrendsFromServer() async {
    final email = await ApiService.instance.getUserEmail();
    return ApiService.instance.fetchProgressTrends(email, _selectedPeriod);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            width: 250,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(isDark ? 0.15 : 0.1),
                    Colors.blue.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    "Progress & Trends",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                // Period Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildPeriodChip("Daily"),
                      const SizedBox(width: 8),
                      _buildPeriodChip("Weekly"),
                      const SizedBox(width: 8),
                      _buildPeriodChip("Monthly"),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Main Content
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _trendsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("⚠️",
                                  style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 16),
                              Text(
                                "Failed to load trends",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  "${snapshot.error}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _trendsFuture = _fetchTrendsFromServer();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        );
                      }

                      final trendsData = snapshot.data ?? {};
                      final averages =
                          trendsData['averages'] as Map<String, dynamic>? ?? {};
                      final targets =
                          trendsData['targets'] as Map<String, dynamic>? ?? {};
                      final dailyData =
                          trendsData['history'] as List<dynamic>? ?? [];
                      final graphData =
                          trendsData['graph_data'] as List<dynamic>? ?? [];

                      final avgSteps =
                          (averages['steps'] as num?)?.toDouble() ?? 0.0;
                      final avgSleep =
                          (averages['sleep'] as num?)?.toDouble() ?? 0.0;
                      final avgCalories =
                          (averages['calories'] as num?)?.toDouble() ?? 0.0;
                      final avgWater =
                          (averages['hydration'] as num?)?.toDouble() ?? 0.0;

                      final targetSteps =
                          (targets['steps'] as num?)?.toDouble() ?? 10000;
                      final targetSleep =
                          (targets['sleep'] as num?)?.toDouble() ?? 8;
                      final targetCalories =
                          (targets['calories'] as num?)?.toDouble() ?? 2000;
                      final targetWater =
                          (targets['hydration'] as num?)?.toDouble() ?? 2500;

                      final metricCards = [
                        _MetricInfo(
                            "🚶 Steps",
                            "${avgSteps.round()}",
                            "avg / target ${targetSteps.round()}",
                            Colors.green,
                            avgSteps / targetSteps),
                        _MetricInfo(
                            "🔥 Calories",
                            "${avgCalories.round()} kcal",
                            "avg / target ${targetCalories.round()}",
                            Colors.orange,
                            avgCalories / targetCalories),
                        _MetricInfo(
                            "🌙 Sleep",
                            "${avgSleep.toStringAsFixed(1)} hrs",
                            "avg / target ${targetSleep.toStringAsFixed(0)}h",
                            Colors.purple,
                            avgSleep / targetSleep),
                        _MetricInfo(
                            "💧 Hydration",
                            "${avgWater.round()} ml",
                            "avg / target ${targetWater.round()}ml",
                            Colors.blue,
                            avgWater / targetWater),
                      ];

                      return RefreshIndicator(
                        onRefresh: () async {
                          final f = _fetchTrendsFromServer();
                          setState(() {
                            _trendsFuture = f;
                          });
                          try {
                            await f;
                          } catch (_) {}
                        },
                        child: ListView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            // ─── Summary Metric Cards Grid ───
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 1.3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: metricCards
                                  .map((c) => _buildExpandedCard(c, isDark))
                                  .toList(),
                            ),

                            const SizedBox(height: 24),

                            // ─── Graph Section ───
                            _buildGraphSection(graphData, isDark, textColor),

                            const SizedBox(height: 24),

                            // ─── History Logs (Collapsible) ───
                            _buildHistorySection(
                                dailyData, isDark, textColor, secondaryTextColor),

                            const SizedBox(height: 80),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedCard(_MetricInfo card, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF1A1A2E), card.color, 0.12)
            : Color.lerp(Colors.white, card.color, 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: card.color.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: card.color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(card.title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600])),
          const SizedBox(height: 4),
          Text(card.value,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: textColor)),
          const SizedBox(height: 4),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: card.progress.clamp(0.0, 1.0),
              backgroundColor: card.color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(card.color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(card.subtitle,
              style: TextStyle(fontSize: 10, color: card.color)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────
  //  Graph Section (from graph_data)
  // ──────────────────────────────────────────────────
  Widget _buildGraphSection(
      List<dynamic> graphData, bool isDark, Color textColor) {
    if (graphData.isEmpty) return const SizedBox.shrink();

    final metricOptions = [
      {"key": "steps", "label": "Steps", "color": Colors.green},
      {"key": "calories", "label": "Calories", "color": Colors.orange},
      {"key": "sleep", "label": "Sleep", "color": Colors.purple},
      {"key": "water", "label": "Water", "color": Colors.blue},
    ];

    final selectedOption = metricOptions.firstWhere(
      (o) => o['key'] == _selectedGraphMetric,
      orElse: () => metricOptions.first,
    );
    final graphColor = selectedOption['color'] as Color;

    // Extract values for selected metric
    final List<double> values = graphData.map((point) {
      final p = point as Map<String, dynamic>;
      return (p[_selectedGraphMetric] as num?)?.toDouble() ?? 0.0;
    }).toList();

    final List<String> labels = graphData.map((point) {
      final p = point as Map<String, dynamic>;
      return (p['label'] as String?) ?? '';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Trends Graph",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 12),
        // Metric selector row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: metricOptions.map((option) {
              final key = option['key'] as String;
              final label = option['label'] as String;
              final color = option['color'] as Color;
              final isSelected = _selectedGraphMetric == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGraphMetric = key),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.2)
                          : (isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.03)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? color
                                : (isDark
                                    ? Colors.white60
                                    : Colors.black54))),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // The graph itself
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartAnimController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _TrendsBarChartPainter(
                    values: values,
                    labels: labels,
                    color: graphColor,
                    isDark: isDark,
                    animProgress: _chartAnimController.value,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────
  //  History Logs — Stacked Cards with Expand/Close
  // ──────────────────────────────────────────────────
  Widget _buildHistorySection(List<dynamic> dailyData, bool isDark,
      Color textColor, Color? secondaryTextColor) {
    final headerText = _selectedPeriod == "Daily"
        ? "Day-by-Day Logs (Last 7 Days)"
        : _selectedPeriod == "Weekly"
            ? "Week-by-Week Logs (Last 4 Weeks)"
            : "Month-by-Month Logs (Last 3 Months)";

    if (dailyData.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headerText,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text("No sync logs available yet",
                  style: TextStyle(color: secondaryTextColor)),
            ),
          ),
        ],
      );
    }

    // Build individual log card widgets
    final logCards = dailyData.map((dayItem) {
      final day = dayItem as Map<String, dynamic>;
      return _buildSingleLogCard(day, textColor, isDark);
    }).toList();

    if (_isLogsExpanded) {
      // ── Expanded: show all cards + close button ──
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(headerText,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textColor)),
              ),
              GestureDetector(
                onTap: () => setState(() => _isLogsExpanded = false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 14, color: Colors.blueAccent),
                      SizedBox(width: 4),
                      Text("Close",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...logCards.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card,
              )),
        ],
      );
    }

    // ── Collapsed: stacked cards ──
    const double cardHeight = 88;
    const double stackOffset = 16;
    final visibleCount = logCards.length.clamp(1, 4);
    final totalHeight = cardHeight + (visibleCount - 1) * stackOffset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headerText,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _isLogsExpanded = true),
          child: SizedBox(
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(visibleCount, (i) {
                // Render in reverse so card 0 is on top
                final reverseIdx = visibleCount - 1 - i;
                final day =
                    dailyData[reverseIdx] as Map<String, dynamic>;
                final anyOk = _hasAnyCompletion(day);

                return Positioned(
                  top: reverseIdx * stackOffset,
                  left: reverseIdx * 4.0,
                  right: reverseIdx * 4.0,
                  height: cardHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Color.lerp(const Color(0xFF1A1A2E),
                              anyOk ? Colors.green : Colors.blueGrey, 0.08)
                          : Color.lerp(Colors.white,
                              anyOk ? Colors.green : Colors.blueGrey, 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: _buildStackedLogContent(day, textColor, isDark),
                  ),
                );
              }),
            ),
          ),
        ),
        if (dailyData.length > 1)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "Tap to expand ${dailyData.length} entries",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueAccent.withOpacity(0.8),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  bool _hasAnyCompletion(Map<String, dynamic> day) {
    final tgt = day['targets_completed'] as Map<String, dynamic>? ?? {};
    return tgt['steps'] == 'yes' ||
        tgt['calories'] == 'yes' ||
        tgt['sleep'] == 'yes' ||
        tgt['hydration'] == 'yes';
  }

  Widget _buildStackedLogContent(
      Map<String, dynamic> day, Color textColor, bool isDark) {
    final dateStr = day['date'] as String? ?? '';
    final steps = (day['steps'] as num?)?.round() ?? 0;
    final calories = (day['calories'] as num?)?.round() ?? 0;
    final sleep = (day['sleep'] as num?)?.toDouble() ?? 0.0;
    final water = (day['water'] as num?)?.round() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_formatDate(dateStr),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textColor)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("🚶 $steps",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text("🔥 $calories",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text("🌙 ${sleep.toStringAsFixed(1)}h",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text("💧 ${water}ml",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleLogCard(
      Map<String, dynamic> day, Color textColor, bool isDark) {
    final dateStr = day['date'] as String? ?? '';
    final steps = (day['steps'] as num?)?.round() ?? 0;
    final calories = (day['calories'] as num?)?.round() ?? 0;
    final sleep = (day['sleep'] as num?)?.toDouble() ?? 0.0;
    final water = (day['water'] as num?)?.round() ?? 0;

    final tgt = day['targets_completed'] as Map<String, dynamic>? ?? {};
    final stepsOk = tgt['steps'] == 'yes';
    final calOk = tgt['calories'] == 'yes';
    final sleepOk = tgt['sleep'] == 'yes';
    final waterOk = tgt['hydration'] == 'yes';
    final anyOk = stepsOk || calOk || sleepOk || waterOk;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDate(dateStr),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor)),
              Icon(Icons.check_circle_outline,
                  color: anyOk ? Colors.green : Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLogMetric("🚶 $steps", "steps", completed: stepsOk),
              _buildLogMetric("🔥 $calories", "kcal", completed: calOk),
              _buildLogMetric("🌙 ${sleep.toStringAsFixed(1)}h", "sleep",
                  completed: sleepOk),
              _buildLogMetric("💧 ${water}ml", "water",
                  completed: waterOk),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────
  //  Helper Widgets
  // ──────────────────────────────────────────────────
  Widget _buildPeriodChip(String label) {
    final isSelected = _selectedPeriod == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      selected: isSelected,
      elevation: 0,
      pressElevation: 0,
      selectedColor: Colors.blueAccent,
      backgroundColor: isDark
          ? Colors.white.withOpacity(0.04)
          : Colors.black.withOpacity(0.03),
      side: BorderSide(
        color: isSelected
            ? Colors.blueAccent
            : (isDark ? Colors.white10 : Colors.black12),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = label;
            _isLogsExpanded = false;
            _trendsFuture = _fetchTrendsFromServer().then((data) {
              _chartAnimController.forward(from: 0.0);
              return data;
            });
          });
        }
      },
    );
  }

  Widget _buildLogMetric(String value, String label, {bool completed = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: completed ? Colors.green : null)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final now = DateTime.now();

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return "Today";
      }

      final yesterday = now.subtract(const Duration(days: 1));
      if (date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day) {
        return "Yesterday";
      }

      final List<String> weekdays = [
        "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
      ];
      final List<String> months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
      ];
      return "${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}";
    } catch (_) {
      return dateStr;
    }
  }
}


// ──────────────────────────────────────────────────────────────
//  Bar Chart Painter (for Trends Graph)
// ──────────────────────────────────────────────────────────────
class _TrendsBarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final bool isDark;
  final double animProgress;

  _TrendsBarChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.isDark,
    required this.animProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

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

      final barRect =
          RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(6),
      );

      // Gradient fill
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withOpacity(0.5)],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));
      canvas.drawRRect(barRect, paint);

      // Value label on top
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
        tp.paint(
            canvas,
            Offset(x + barWidth / 2 - tp.width / 2,
                y - tp.height - 4));
      }

      // Label below
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
    return v.toStringAsFixed(1);
  }

  String _shortLabel(String label) {
    // "2026-07-12" => "Jul 12", "2026-W28" => "W28", "2026-07" => "Jul"
    if (label.contains('W')) {
      return label.split('-').last;
    }
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
  bool shouldRepaint(covariant _TrendsBarChartPainter old) =>
      old.animProgress != animProgress ||
      old.color != color ||
      old.values != values;
}

// ──────────────────────────────────────────────────────────────
//  Data class
// ──────────────────────────────────────────────────────────────
class _MetricInfo {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final double progress;

  _MetricInfo(this.title, this.value, this.subtitle, this.color, this.progress);
}
