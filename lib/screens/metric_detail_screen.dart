import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';

class MetricDetailScreen extends StatefulWidget {
  final String
  metric; // 'steps', 'calories', 'sleep', 'water', 'workouts', or 'heart_rate'
  final String title;
  final String icon;
  final Color color;
  final String email;

  const MetricDetailScreen({
    super.key,
    required this.metric,
    required this.title,
    required this.icon,
    required this.color,
    required this.email,
  });

  @override
  State<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends State<MetricDetailScreen>
    with TickerProviderStateMixin {
  String _selectedPeriod = 'days'; // 'days', 'weeks', 'month'
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _apiResponse = {};
  List<dynamic> _chartData = [];
  int? _hoveredIndex;
  bool _historyExpanded = false;
  int? _expandedLogIndex;

  late AnimationController _chartAnimController;
  late AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    _chartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _fetchGraphData();
  }

  @override
  void dispose() {
    _chartAnimController.dispose();
    _bgAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchGraphData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.instance.getAccessToken();
      // Ensure we encode the email correctly.
      final encodedEmail = Uri.encodeComponent(widget.email);
      final url =
          'https://api.prabhash.site/api/health/graph/$encodedEmail?metric=${widget.metric}&period=$_selectedPeriod';

      var response = await http.get(
        Uri.parse(url),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      // Handle 401 Authorization Token refresh
      if (response.statusCode == 401) {
        await AuthService.instance.refreshSessionToken();
        final newToken = await AuthService.instance.getAccessToken();
        response = await http.get(
          Uri.parse(url),
          headers: {if (newToken != null) 'Authorization': 'Bearer $newToken'},
        );
      }

      if (response.statusCode == 200) {
        debugPrint("API Response ($url): ${response.body}");
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _apiResponse = data;
          _chartData = data['data'] ?? [];
          _isLoading = false;
        });
        _chartAnimController.forward(from: 0.0);
      } else {
        debugPrint(
          "API Error ($url): Status ${response.statusCode} - ${response.body}",
        );
        setState(() {
          _errorMessage = "Server error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("API Exception: $e");
      setState(() {
        _errorMessage = "Network or parsing error occurred: $e";
        _isLoading = false;
      });
    }
  }

  String _formatStatValue(num val) {
    if (widget.metric == 'steps') {
      return _formatNumberWithCommas(val.round());
    } else if (widget.metric == 'calories') {
      return "${val.round()} kcal";
    } else if (widget.metric == 'water') {
      return "${val.round()} ml";
    } else if (widget.metric == 'sleep') {
      final hours = val.toDouble();
      final h = hours.toInt();
      final m = ((hours - h) * 60).round();
      if (h == 0) return "${m}m";
      if (m == 0) return "${h}h";
      return "${h}h ${m}m";
    } else if (widget.metric == 'heart_rate') {
      return "${val.round()} bpm";
    } else if (widget.metric == 'workouts') {
      return "${val.round()} session${val.round() != 1 ? 's' : ''}";
    }
    return val.toStringAsFixed(1);
  }

  String _formatNumberWithCommas(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => "${m[1]},",
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Theme ambient background
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          // Animated Glow Blobs pulsing in background
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, child) {
              final double pulse = _bgAnimController.value;
              final double size1 = 320 + (pulse * 30);
              final double size2 = 380 - (pulse * 25);
              final double size3 = 340 + (pulse * 20);

              return Stack(
                children: [
                  // Glow Blob 1 (Top Right) matching metric color
                  Positioned(
                    top: -100 - (pulse * 15),
                    right: -100 - (pulse * 15),
                    width: size1,
                    height: size1,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            widget.color.withOpacity(
                              (isDark ? 0.22 : 0.18) * (0.85 + pulse * 0.2),
                            ),
                            widget.color.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Glow Blob 2 (Middle Left)
                  Positioned(
                    top: 250 + (pulse * 20),
                    left: -120 - (pulse * 10),
                    width: size2,
                    height: size2,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.blue.withOpacity(
                              (isDark ? 0.18 : 0.14) *
                                  (0.9 + (1.0 - pulse) * 0.15),
                            ),
                            Colors.blue.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Glow Blob 3 (Bottom Right)
                  Positioned(
                    bottom: -80 - (pulse * 10),
                    right: -60 - (pulse * 10),
                    width: size3,
                    height: size3,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.green.withOpacity(
                              (isDark ? 0.15 : 0.12) * (0.85 + pulse * 0.25),
                            ),
                            Colors.green.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Custom Navigation Row matching WaterLoggingScreen + Profile Avatar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
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
                        const SizedBox(width: 8),
                        Text(widget.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                "Historical analysis & health insights",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(
                            "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Primary Content Loading or Body
                if (_isLoading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: widget.color),
                    ),
                  )
                else if (_errorMessage != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("⚠️", style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.color.withOpacity(0.12),
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: widget.color,
                                    width: 1,
                                  ),
                                ),
                              ),
                              onPressed: _fetchGraphData,
                              child: Text(
                                "Retry Connection",
                                style: TextStyle(
                                  color: widget.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Statistics cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: _buildStatsGrid(),
                    ),
                  ),

                  // Chart Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Activity Trend 📊",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildMiniGraphTab(
                                        "Days",
                                        "days",
                                        isDark,
                                      ),
                                      _buildMiniGraphTab(
                                        "Weeks",
                                        "weeks",
                                        isDark,
                                      ),
                                      _buildMiniGraphTab(
                                        "Month",
                                        "month",
                                        isDark,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildLineChart(isDark),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // AI Feedback Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: _buildAIFeedbackCard(isDark),
                    ),
                  ),

                  // Detailed Records History Section
                  _buildHistoryLogsSection(isDark),

                  // Extra bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 50)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateProgressTarget(double val) {
    if (widget.metric == 'steps') {
      return (val / 10000.0).clamp(0.05, 1.0);
    } else if (widget.metric == 'calories') {
      return (val / 2500.0).clamp(0.05, 1.0);
    } else if (widget.metric == 'sleep') {
      return (val / 8.0).clamp(0.05, 1.0);
    } else if (widget.metric == 'water') {
      return (val / 2500.0).clamp(0.05, 1.0);
    } else if (widget.metric == 'heart_rate') {
      return (val / 120.0).clamp(0.05, 1.0);
    } else if (widget.metric == 'workouts') {
      return (val / 5.0).clamp(0.05, 1.0);
    }
    return 0.7;
  }

  Widget _buildStatsGrid() {
    final List<Widget> stats = [];

    // 1. Average
    if (_apiResponse['average'] != null) {
      final double avgVal = (_apiResponse['average'] as num).toDouble();
      stats.add(
        _buildStatCard(
          title: "Period ${widget.title}",
          value: _formatStatValue(avgVal),
          description: "Calculated avg.",
          icon: Icons.calendar_today_outlined,
          progressTarget: _calculateProgressTarget(avgVal),
        ),
      );
    }

    // 2. Total
    if (_apiResponse['total'] != null) {
      stats.add(
        _buildStatCard(
          title: "Combined",
          value: _formatStatValue(_apiResponse['total'] as num),
          description: "Combined activity",
          icon: Icons.bar_chart_rounded,
          progressTarget: 0.85,
        ),
      );
    }

    // 3. Calories total or average if steps metric
    if (widget.metric == 'steps' && _apiResponse['calories_total'] != null) {
      final double calVal = (_apiResponse['calories_total'] as num).toDouble();
      stats.add(
        _buildStatCard(
          title: "Activity",
          value: "${calVal.round()} kcal",
          description: "Est. energy burn",
          icon: Icons.local_fire_department,
          altColor: const Color(0xFFFF9500),
          progressTarget: (calVal / 3000.0).clamp(0.05, 1.0),
        ),
      );
    }

    if (stats.isEmpty) return const SizedBox();

    return Column(
      children: stats
          .map(
            (card) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: card,
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required double progressTarget,
    Color? altColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = altColor ?? widget.color;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      margin: EdgeInsets.zero,
      borderRadius: 18,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 11, color: displayColor.withOpacity(0.8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white38 : Colors.black45,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 8,
                    color: isDark ? Colors.white24 : Colors.black38,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Interactive Custom Activity Ring
          AnimatedBuilder(
            animation: _chartAnimController,
            builder: (context, child) {
              final currentProgress =
                  progressTarget * _chartAnimController.value;
              return Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(2),
                child: CustomPaint(
                  painter: ActivityRingPainter(
                    progress: currentProgress,
                    color: displayColor,
                  ),
                  child: Center(
                    child: Text(
                      "${(currentProgress * 100).round()}%",
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniGraphTab(String label, String value, bool isDark) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedPeriod = value;
            _historyExpanded = false;
            _expandedLogIndex = null;
          });
          _fetchGraphData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? widget.color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(bool isDark) {
    if (_chartData.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.02)
              : Colors.black.withOpacity(0.01),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            "No historical logs available for this range",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    final List<double> values = _chartData
        .map((e) => ((e['value'] ?? 0.0) as num).toDouble())
        .toList();

    double maxVal = values.fold(0.0, max);
    if (maxVal == 0.0) maxVal = 100.0; // Avoid divide by 0/flat chart

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Y-Axis Labels
            Container(
              height: 180,
              width: 55,
              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatAxisLabel(maxVal),
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatAxisLabel(maxVal * 0.75),
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatAxisLabel(maxVal * 0.5),
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatAxisLabel(maxVal * 0.25),
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
            // The Canvas Chart + Gesture Detector
            Expanded(
              child: SizedBox(
                height: 180,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final stepX = values.length > 1
                        ? width / (values.length - 1)
                        : width;

                    return GestureDetector(
                      onPanDown: (details) => _handleChartTouch(
                        details.localPosition.dx,
                        stepX,
                        values.length,
                      ),
                      onPanUpdate: (details) => _handleChartTouch(
                        details.localPosition.dx,
                        stepX,
                        values.length,
                      ),
                      onPanEnd: (_) => setState(() => _hoveredIndex = null),
                      onPanCancel: () => setState(() => _hoveredIndex = null),
                      onTapDown: (details) => _handleChartTouch(
                        details.localPosition.dx,
                        stepX,
                        values.length,
                      ),
                      onTapUp: (_) => setState(() => _hoveredIndex = null),
                      child: AnimatedBuilder(
                        animation: _chartAnimController,
                        builder: (context, child) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                painter: MetricDetailChartPainter(
                                  values: values,
                                  isDark: isDark,
                                  maxAmount: maxVal,
                                  color: widget.color,
                                  hoveredIndex: _hoveredIndex,
                                  animationVal: _chartAnimController.value,
                                ),
                                size: Size.infinite,
                              ),
                              // Tooltip UI
                              if (_hoveredIndex != null &&
                                  _hoveredIndex! < _chartData.length) ...[
                                _buildChartTooltip(
                                  width,
                                  stepX,
                                  values,
                                  isDark,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // X-Axis Labels Row
        Row(
          children: [
            const SizedBox(width: 55),
            Expanded(child: _buildTimelineRow(isDark)),
          ],
        ),
      ],
    );
  }

  void _handleChartTouch(double localX, double stepX, int length) {
    if (length == 0) return;
    final index = (localX / stepX).round().clamp(0, length - 1);
    if (_hoveredIndex != index) {
      setState(() {
        _hoveredIndex = index;
      });
    }
  }

  Widget _buildChartTooltip(
    double chartWidth,
    double stepX,
    List<double> values,
    bool isDark,
  ) {
    final index = _hoveredIndex!;
    final double x = index * stepX;
    final double val = values[index];
    final String rawDate = _chartData[index]['label']?.toString() ?? "";
    final String formattedDate = _formatLogDate(rawDate);
    final String formattedValue = _formatStatValue(val);

    // Calculate tooltip positioning with bounds clamping
    const tooltipWidth = 120.0;
    double left = x - (tooltipWidth / 2);
    left = left.clamp(0.0, chartWidth - tooltipWidth);

    return Positioned(
      left: left,
      top: -30, // Hover above the chart area
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: EdgeInsets.zero,
        borderRadius: 8,
        blur: 12.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 8,
                color: isDark ? Colors.white38 : Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formattedValue,
              style: TextStyle(
                fontSize: 10,
                color: widget.color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLogDate(String label) {
    if (label.length == 10) {
      try {
        final date = DateTime.parse(label);
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
        return "${months[date.month - 1]} ${date.day}, ${date.year}";
      } catch (_) {
        return label;
      }
    }
    return label;
  }

  bool _checkIsGoalHit(double val) {
    if (widget.metric == 'steps') return val >= 6000;
    if (widget.metric == 'calories') return val >= 500;
    if (widget.metric == 'sleep') return val >= 7.0;
    if (widget.metric == 'water') return val >= 2000;
    if (widget.metric == 'heart_rate') return val >= 60 && val <= 100;
    if (widget.metric == 'workouts') return val >= 1;
    return true;
  }

  Widget _buildHistoryLogsSection(bool isDark) {
    if (_chartData.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    final labelColor = isDark ? Colors.white60 : Colors.black54;
    final List<dynamic> reversedLogs = _chartData.reversed.toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
                  child: Text(
                    "DETAILED RECORD HISTORY",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: labelColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (reversedLogs.length > 1)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _historyExpanded = !_historyExpanded;
                      });
                    },
                    child: Text(
                      _historyExpanded ? "Collapse" : "View All",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                  ),
              ],
            ),
            _historyExpanded
                ? _buildExpandedLogs(reversedLogs, isDark)
                : _buildStackedLogs(reversedLogs, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedLogs(List<dynamic> logs, bool isDark) {
    final displayLogs = logs.take(3).toList();
    final weekdayNames = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
    ];

    return GestureDetector(
      onTap: () {
        setState(() {
          _historyExpanded = true;
        });
      },
      child: SizedBox(
        height: 72.0 + (displayLogs.length - 1) * 12.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: List.generate(displayLogs.length, (index) {
            // Reverse order for stacking so the latest is on top
            final reversedIndex = displayLogs.length - 1 - index;
            final log = displayLogs[reversedIndex];

            // Layout offsets
            final double offset = reversedIndex * 12.0;
            final double scale = 1.0 - (reversedIndex * 0.04);

            final double val = ((log['value'] ?? 0.0) as num).toDouble();
            final String dateLabel = log['label']?.toString() ?? "";
            final String displayDate = _formatLogDate(dateLabel);

            String displayWeekday = "";
            try {
              final date = DateTime.parse(dateLabel);
              displayWeekday = weekdayNames[date.weekday % 7];
            } catch (_) {
              displayWeekday = "Logged Date";
            }

            final String displayValue = _formatStatValue(val);
            final bool isGoalHit = _checkIsGoalHit(val);

            return Positioned(
              left: 0,
              right: 0,
              top: offset,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1D1D23) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: widget.color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayDate,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayWeekday,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white30 : Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            displayValue,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isGoalHit ? "ACTIVE GOAL HIT" : "BELOW TARGET",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isGoalHit
                                  ? const Color(0xFF00C781)
                                  : const Color(0xFFFF3B30),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: isDark ? Colors.white24 : Colors.black38,
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

  Widget _buildExpandedLogs(List<dynamic> logs, bool isDark) {
    final weekdayNames = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final double val = ((log['value'] ?? 0.0) as num).toDouble();
        final double? calories = log['calories_burned'] != null
            ? (log['calories_burned'] as num).toDouble()
            : null;
        final String dateLabel = log['label']?.toString() ?? "";
        final String displayDate = _formatLogDate(dateLabel);

        String displayWeekday = "";
        try {
          final date = DateTime.parse(dateLabel);
          displayWeekday = weekdayNames[date.weekday % 7];
        } catch (_) {
          displayWeekday = "Logged Date";
        }

        final String displayValue = _formatStatValue(val);
        final bool isGoalHit = _checkIsGoalHit(val);
        final double progress = _calculateProgressTarget(val);
        final bool isExpanded = _expandedLogIndex == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(isExpanded ? 0.06 : 0.03)
                : Colors.white.withOpacity(isExpanded ? 0.95 : 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpanded
                  ? widget.color.withOpacity(0.3)
                  : (isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.02)),
              width: isExpanded ? 1.5 : 1.0,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(isDark ? 0.15 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _expandedLogIndex = isExpanded ? null : index;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isExpanded
                                  ? widget.color.withOpacity(0.12)
                                  : widget.color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: widget.color,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayDate,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  displayWeekday,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white30
                                        : Colors.black45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                displayValue,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isGoalHit ? "ACTIVE GOAL HIT" : "BELOW TARGET",
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: isGoalHit
                                      ? const Color(0xFF00C781)
                                      : const Color(0xFFFF3B30),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: isExpanded ? 0.25 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: isDark ? Colors.white30 : Colors.black45,
                            ),
                          ),
                        ],
                      ),

                      // Collapsible Detail Section
                      AnimatedCrossFade(
                        firstChild: const SizedBox(height: 0),
                        secondChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            Divider(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.06),
                              height: 1.0,
                            ),
                            const SizedBox(height: 16),

                            // Visual analysis cards
                            Row(
                              children: [
                                // Progress activity ring inside card
                                Container(
                                  width: 48,
                                  height: 48,
                                  padding: const EdgeInsets.all(2),
                                  child: CustomPaint(
                                    painter: ActivityRingPainter(
                                      progress: progress,
                                      color: widget.color,
                                    ),
                                    child: Center(
                                      child: Text(
                                        "${(progress * 100).round()}%",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${widget.title.toUpperCase()} PROGRESS",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black45,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isGoalHit
                                            ? "Fantastic effort! You've achieved your goal."
                                            : "Keep going, you are close to hitting your goal!",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Display calories burned if metric is steps
                            if (widget.metric == 'steps' &&
                                calories != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF9500,
                                  ).withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFF9500,
                                    ).withOpacity(0.12),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF9500,
                                        ).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.local_fire_department,
                                        color: Color(0xFFFF9500),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "EST. CALORIES BURNED",
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFFF9500),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            "${calories.toStringAsFixed(1)} kcal burned",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        crossFadeState: isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogDetailsBottomSheet(
    BuildContext context,
    Map<String, dynamic> log,
    bool isDark,
  ) {
    final double val = ((log['value'] ?? 0.0) as num).toDouble();
    final double? calories = log['calories_burned'] != null
        ? (log['calories_burned'] as num).toDouble()
        : null;
    final String dateLabel = log['label']?.toString() ?? "";
    final String displayDate = _formatLogDate(dateLabel);

    final weekdayNames = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
    ];
    String displayWeekday = "";
    try {
      final date = DateTime.parse(dateLabel);
      displayWeekday = weekdayNames[date.weekday % 7];
    } catch (_) {
      displayWeekday = "Logged Day";
    }

    final String displayValue = _formatStatValue(val);
    final bool isGoalHit = _checkIsGoalHit(val);
    final double progress = _calculateProgressTarget(val);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayWeekday,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white30 : Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isGoalHit
                          ? const Color(0xFF00C781).withOpacity(0.12)
                          : const Color(0xFFFF3B30).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isGoalHit ? "GOAL ACHIEVED" : "BELOW TARGET",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isGoalHit
                            ? const Color(0xFF00C781)
                            : const Color(0xFFFF3B30),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.02)
                      : Colors.black.withOpacity(0.01),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.02),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      padding: const EdgeInsets.all(3),
                      child: CustomPaint(
                        painter: ActivityRingPainter(
                          progress: progress,
                          color: widget.color,
                        ),
                        child: Center(
                          child: Text(
                            "${(progress * 100).round()}%",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white38 : Colors.black45,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              displayValue,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (widget.metric == 'steps' && calories != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF9500).withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_fire_department,
                          color: Color(0xFFFF9500),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "EST. CALORIES BURNED",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF9500),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${calories.toStringAsFixed(1)} kcal",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color.withOpacity(0.12),
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: widget.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  "Done",
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  String _formatAxisLabel(double value) {
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}k";
    }
    return value.round().toString();
  }

  Widget _buildTimelineRow(bool isDark) {
    final int len = _chartData.length;
    if (len == 0) return const SizedBox();

    final List<Widget> labelWidgets = [];
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double stepX = len > 1 ? width / (len - 1) : width;

        for (int i = 0; i < len; i++) {
          final label = _chartData[i]['label']?.toString() ?? "";
          String displayLabel = label;

          // Simplify Date string formats
          if (label.length == 10) {
            // YYYY-MM-DD -> MM/DD
            displayLabel = "${label.substring(5, 7)}/${label.substring(8)}";
          } else if (label.contains('W')) {
            // week notation like 2026-W24 -> W24
            final parts = label.split('-W');
            if (parts.length > 1) {
              displayLabel = "W${parts[1]}";
            }
          }

          // Smart label thinning so it doesn't look crowded
          bool shouldShow = false;
          if (len <= 7) {
            shouldShow = (i == 0 || i == len ~/ 2 || i == len - 1);
          } else if (len <= 15) {
            shouldShow =
                (i == 0 ||
                i == len ~/ 3 ||
                i == (2 * len) ~/ 3 ||
                i == len - 1);
          } else {
            shouldShow =
                (i == 0 ||
                i == len ~/ 4 ||
                i == len ~/ 2 ||
                i == (3 * len) ~/ 4 ||
                i == len - 1);
          }

          if (shouldShow) {
            labelWidgets.add(
              Positioned(
                left: i * stepX - 20, // Center the label text roughly
                width: 40,
                child: Text(
                  displayLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
              ),
            );
          }
        }

        return SizedBox(
          height: 15,
          child: Stack(clipBehavior: Clip.none, children: labelWidgets),
        );
      },
    );
  }

  Widget _buildAIFeedbackCard(bool isDark) {
    final feedbackText = _apiResponse['feedback']?.toString();
    if (feedbackText == null || feedbackText.isEmpty) {
      return const SizedBox();
    }

    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, child) {
        final double pulse = _bgAnimController.value;
        return GlassCard(
          padding: const EdgeInsets.all(18),
          margin: EdgeInsets.zero,
          borderRadius: 20,
          border: Border.all(
            color: widget.color.withOpacity(0.12 + (pulse * 0.08)),
            width: 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "✨",
                            style: TextStyle(fontSize: 14, color: widget.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AI Wellness Buddy",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            "Personal health advisor",
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Breathing neon indicator badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.color.withOpacity(0.12),
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
                            shape: BoxShape.circle,
                            color: widget.color.withOpacity(
                              0.4 + (pulse * 0.6),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withOpacity(0.5 * pulse),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "ANALYSIS LIVE",
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: widget.color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Message Bubble style layout
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.02)
                      : Colors.black.withOpacity(0.01),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                  ),
                ),
                child: Text(
                  feedbackText,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MetricDetailChartPainter extends CustomPainter {
  final List<double> values;
  final bool isDark;
  final double maxAmount;
  final Color color;
  final int? hoveredIndex;
  final double animationVal;

  MetricDetailChartPainter({
    required this.values,
    required this.isDark,
    required this.maxAmount,
    required this.color,
    required this.animationVal,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    // Draw horizontal grid lines
    final Paint gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.03)
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
      final double y = height - (normalizedVal * (height - 16)) - 8;
      points.add(Offset(x, y));
    }

    // Clip base chart components for slide-in drawing animation
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width * animationVal, height));

    // 1. Draw area gradient path under the curve line
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
          colors: [color.withOpacity(0.22), color.withOpacity(0.00)],
        ).createShader(Rect.fromLTRB(0, 0, width, height));

      canvas.drawPath(areaPath, areaPaint);
    }

    // 2. Draw smooth line path
    if (points.isNotEmpty) {
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

      // Draw subtle glow shadow under the line path for premium neon glow look
      final Paint glowPaint = Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, glowPaint);

      final Paint linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(linePath, linePaint);
    }

    // 3. Draw dots on data points (only if length is small, e.g. <= 15 and we are not hovering)
    final drawDots = values.length <= 15 && hoveredIndex == null;
    if (drawDots && points.isNotEmpty) {
      final Paint dotOuterPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final Paint dotInnerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (final pt in points) {
        canvas.drawCircle(pt, 4.5, dotInnerPaint);
        canvas.drawCircle(pt, 2.0, dotOuterPaint);
      }
    }

    canvas.restore();

    // 2.5 Draw vertical interactive guidelines and pointer glow (outside chart animation clip)
    if (hoveredIndex != null && hoveredIndex! < points.length) {
      final double x = hoveredIndex! * stepX;
      final Paint guidelinePaint = Paint()
        ..color = color.withOpacity(0.25)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Draw dashed vertical guide line
      for (double y = 0; y < height; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 3.5), guidelinePaint);
      }

      final Offset pt = points[hoveredIndex!];
      final Paint outerGlowPaint = Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 11.0, outerGlowPaint);

      final Paint innerGlowPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final Paint pointerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pt, 5.0, innerGlowPaint);
      canvas.drawCircle(pt, 2.5, pointerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MetricDetailChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.isDark != isDark ||
        oldDelegate.maxAmount != maxAmount ||
        oldDelegate.color != color ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.animationVal != animationVal;
  }
}

class ActivityRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  ActivityRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint trackPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final Paint progressPaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    if (progress > 0) {
      progressPaint.style = PaintingStyle.stroke;
    } else {
      progressPaint.style = PaintingStyle.fill;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - 2;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ActivityRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
