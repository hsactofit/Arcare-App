import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _selectedPeriod = "Weekly";
  late Future<List<Map<String, dynamic>>> _dailyDataFuture;

  @override
  void initState() {
    super.initState();
    _dailyDataFuture = _fetchTrendsFromServer();
  }

  Future<List<Map<String, dynamic>>> _fetchTrendsFromServer() async {
    final email = await ApiService.instance.getUserEmail();
    return ApiService.instance.fetchTrends(email, _selectedPeriod);
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
          // Background Glows
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
                // Title Area
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Progress Trends 📈",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        "Track your activity stats over time",
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Period Selector Chips
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

                // Main Stats Content
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _dailyDataFuture,
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
                              const Text("⚠️", style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 16),
                              Text(
                                "Failed to load trends from server",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  "${snapshot.error}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _dailyDataFuture = _fetchTrendsFromServer();
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

                      final dailyData = snapshot.data ?? [];

                      // Calculate Averages/Totals
                      double totalSteps = 0;
                      double totalCalories = 0;
                      double totalSleep = 0;
                      double totalWater = 0;
                      int daysWithData = 0;

                      for (var day in dailyData) {
                        final steps = (day['steps'] as num).toDouble();
                        final calories = (day['calories'] as num).toDouble();
                        final sleep = (day['sleep_duration_hours'] as num)
                            .toDouble();
                        final water = (day['water_intake_ml'] as num)
                            .toDouble();

                        totalSteps += steps;
                        totalCalories += calories;
                        totalSleep += sleep;
                        totalWater += water;
                        if (steps > 0 ||
                            calories > 0 ||
                            sleep > 0 ||
                            water > 0) {
                          daysWithData++;
                        }
                      }

                      final avgSteps = dailyData.isEmpty
                          ? 0.0
                          : (totalSteps / dailyData.length);
                      final avgSleep = dailyData.isEmpty
                          ? 0.0
                          : (totalSleep / dailyData.length);
                      final avgCalories = dailyData.isEmpty
                          ? 0.0
                          : (totalCalories / dailyData.length);
                      final avgWater = dailyData.isEmpty
                          ? 0.0
                          : (totalWater / dailyData.length);

                      return RefreshIndicator(
                        onRefresh: () async {
                          final f = _fetchTrendsFromServer();
                          setState(() {
                            _dailyDataFuture = f;
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
                            // Overview Summary Cards Grid
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 1.4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: [
                                _buildMetricSummaryCard(
                                  "🚶 Steps",
                                  "${avgSteps.round()}",
                                  "avg/day",
                                  Colors.green,
                                  isDark,
                                ),
                                _buildMetricSummaryCard(
                                  "🔥 Calories",
                                  "${avgCalories.round()} kcal",
                                  "avg/day",
                                  Colors.orange,
                                  isDark,
                                ),
                                _buildMetricSummaryCard(
                                  "🌙 Sleep",
                                  "${avgSleep.toStringAsFixed(1)} hrs",
                                  "avg/night",
                                  Colors.purple,
                                  isDark,
                                ),
                                _buildMetricSummaryCard(
                                  "💧 Hydration",
                                  "${avgWater.round()} ml",
                                  "avg/day",
                                  Colors.blue,
                                  isDark,
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Daily Logs Header
                            Text(
                              "Day-by-Day Logs (Last 7 Days)",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (dailyData.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Center(
                                  child: Text(
                                    "No sync logs available yet",
                                    style: TextStyle(color: secondaryTextColor),
                                  ),
                                ),
                              )
                            else
                              ...dailyData.map((day) {
                                final String dateStr = day['date'] as String;
                                final steps = day['steps'] as int;
                                final calories = day['calories'] as int;
                                final double sleep =
                                    (day['sleep_duration_hours'] as num)
                                        .toDouble();
                                final water = day['water_intake_ml'] as int;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDate(dateStr),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: textColor,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildLogMetric(
                                              "🚶 $steps",
                                              "steps",
                                            ),
                                            _buildLogMetric(
                                              "🔥 $calories",
                                              "kcal",
                                            ),
                                            _buildLogMetric(
                                              "🌙 ${sleep.toStringAsFixed(1)}h",
                                              "sleep",
                                            ),
                                            _buildLogMetric(
                                              "💧 ${water}ml",
                                              "water",
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),

                            const SizedBox(
                              height: 80,
                            ), // Padding to clear bottom navigation bar
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
            _dailyDataFuture = _fetchTrendsFromServer();
          });
        }
      },
    );
  }

  Widget _buildMetricSummaryCard(
    String title,
    String value,
    String subtitle,
    Color color,
    bool isDark,
  ) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: textColor,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
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
        "Mon",
        "Tue",
        "Wed",
        "Thu",
        "Fri",
        "Sat",
        "Sun",
      ];
      final List<String> months = [
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
      return "${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}";
    } catch (_) {
      return dateStr;
    }
  }
}
