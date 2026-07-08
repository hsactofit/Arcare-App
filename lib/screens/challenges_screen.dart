import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_card.dart';
import '../widgets/concentric_rings_chart.dart';
import '../services/health_service.dart';

class LeaderboardPlayer {
  String name;
  double progress;
  final String progressTextPattern;
  final bool isUser;
  final String avatarUrl;

  LeaderboardPlayer({
    required this.name,
    required this.progress,
    required this.progressTextPattern,
    this.isUser = false,
    this.avatarUrl = "",
  });

  String get progressText {
    return progressTextPattern.replaceAll('%s', progress.round().toString());
  }
}

class Challenge {
  final String id;
  final String title;
  final String desc;
  double progress;
  final double target;
  final String progressTextPattern;
  final int points;
  final String timeLeft;
  final Color color;
  final String metricType;
  bool isJoined;
  List<LeaderboardPlayer> leaderboard;
  bool isExpanded;

  Challenge({
    required this.id,
    required this.title,
    required this.desc,
    required this.progress,
    required this.target,
    required this.progressTextPattern,
    required this.points,
    required this.timeLeft,
    required this.color,
    required this.metricType,
    required this.isJoined,
    required this.leaderboard,
    this.isExpanded = false,
  });
}

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final int _userPoints = 350;
  String _userName = "User";
  bool _isLoading = true;
  HealthData _healthData = HealthData();

  late List<Challenge> _challenges;

  @override
  void initState() {
    super.initState();
    _initChallenges();
    _loadData();
  }

  void _initChallenges() {
    _challenges = [
      Challenge(
        id: "hydration",
        title: "Weekly Hydration Champion",
        desc: "Log at least 2000 ml of water daily for 7 consecutive days.",
        progress: 5.0,
        target: 7.0,
        progressTextPattern: "Progress: %s/7 days completed",
        points: 150,
        timeLeft: "3 days left",
        color: Colors.blueAccent,
        metricType: "water",
        isJoined: true,
        leaderboard: [
          LeaderboardPlayer(name: "Alex Mercer", progress: 6.0, progressTextPattern: "%s days"),
          LeaderboardPlayer(name: "Sarah Connor", progress: 6.0, progressTextPattern: "%s days"),
          LeaderboardPlayer(name: "You", progress: 5.0, progressTextPattern: "%s days", isUser: true),
          LeaderboardPlayer(name: "David Beckham", progress: 5.0, progressTextPattern: "%s days"),
          LeaderboardPlayer(name: "Emma Watson", progress: 4.0, progressTextPattern: "%s days"),
        ],
      ),
      Challenge(
        id: "steps",
        title: "10K Steps Master Routine",
        desc: "Achieve a minimum of 10,000 steps daily for 5 days this week.",
        progress: 3.0,
        target: 5.0,
        progressTextPattern: "Progress: %s/5 days completed",
        points: 200,
        timeLeft: "4 days left",
        color: Colors.green,
        metricType: "steps",
        isJoined: true,
        leaderboard: [
          LeaderboardPlayer(name: "Usain Bolt", progress: 5.0, progressTextPattern: "%s days"),
          LeaderboardPlayer(name: "Eliud Kipchoge", progress: 4.0, progressTextPattern: "%s days"),
          LeaderboardPlayer(name: "You", progress: 3.0, progressTextPattern: "%s days", isUser: true),
          LeaderboardPlayer(name: "Serena Williams", progress: 3.0, progressTextPattern: "%s days"),
          LeaderboardPlayer(name: "LeBron James", progress: 2.0, progressTextPattern: "%s days"),
        ],
      ),
      Challenge(
        id: "sleep",
        title: "Consistent Sleep Schedule",
        desc: "Maintain 7.5+ hours of sleep duration daily for 5 consecutive nights.",
        progress: 0.0,
        target: 5.0,
        progressTextPattern: "Progress: %s/5 nights completed",
        points: 180,
        timeLeft: "5-Day Duration",
        color: Colors.purple,
        metricType: "sleep",
        isJoined: false,
        leaderboard: [
          LeaderboardPlayer(name: "Sleeping Beauty", progress: 4.0, progressTextPattern: "%s nights"),
          LeaderboardPlayer(name: "Arianna Huffington", progress: 3.0, progressTextPattern: "%s nights"),
          LeaderboardPlayer(name: "You", progress: 0.0, progressTextPattern: "%s nights", isUser: true),
          LeaderboardPlayer(name: "Elon Musk", progress: 1.0, progressTextPattern: "%s nights"),
          LeaderboardPlayer(name: "Bill Gates", progress: 1.0, progressTextPattern: "%s nights"),
        ],
      ),
      Challenge(
        id: "calories",
        title: "Calorie Burn Streak",
        desc: "Burn at least 500 active calories daily through logged exercises for 3 days.",
        progress: 0.0,
        target: 3.0,
        progressTextPattern: "Progress: %s/3 days completed",
        points: 120,
        timeLeft: "3-Day Duration",
        color: Colors.orange,
        metricType: "calories",
        isJoined: false,
        leaderboard: [
          LeaderboardPlayer(name: "Arnold Schwarzenegger", progress: 3.0, progressTextPattern: "%s days"),
          LeaderboardPlayer(name: "Michael Phelps", progress: 2.0, progressTextPattern: "%s days"),
          LeaderboardPlayer(name: "You", progress: 0.0, progressTextPattern: "%s days", isUser: true),
          LeaderboardPlayer(name: "Chris Hemsworth", progress: 1.0, progressTextPattern: "%s days"),
          LeaderboardPlayer(name: "Dwayne Johnson", progress: 1.0, progressTextPattern: "%s days"),
        ],
      ),
    ];
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String name = "User";
    final localName = prefs.getString('user_name');
    if (localName != null && localName.isNotEmpty) {
      name = localName;
    } else {
      final jsonStr = prefs.getString('onboarding_data');
      if (jsonStr != null) {
        try {
          final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
          final n = onboarding['auth']?['name'];
          if (n != null && n.isNotEmpty) {
            name = n;
          }
        } catch (e) {
          debugPrint("Error parsing onboarding data: $e");
        }
      }
    }

    HealthData healthData = HealthData();
    try {
      healthData = await HealthService.instance.fetchHealthData();
    } catch (e) {
      debugPrint("Error fetching health data: $e");
    }

    if (mounted) {
      setState(() {
        _userName = name;
        _healthData = healthData;
        _isLoading = false;
        _updateChallengeProgressWithRealData();
      });
    }
  }

  void _updateChallengeProgressWithRealData() {
    for (var c in _challenges) {
      if (c.id == 'hydration') {
        final isWaterGoalMetToday = _healthData.waterIntake >= 2000.0;
        c.progress = isWaterGoalMetToday ? 6.0 : 5.0;
      } else if (c.id == 'steps') {
        final isStepGoalMetToday = _healthData.steps >= 10000.0;
        c.progress = isStepGoalMetToday ? 4.0 : 3.0;
      } else if (c.id == 'sleep' && c.isJoined) {
        final isSleepGoalMetToday = _healthData.sleepDuration >= 7.5;
        c.progress = isSleepGoalMetToday ? 1.0 : 0.0;
      } else if (c.id == 'calories' && c.isJoined) {
        final isCalorieGoalMetToday = _healthData.activeCalories >= 500.0;
        c.progress = isCalorieGoalMetToday ? 1.0 : 0.0;
      }

      // Update the "You" player in leaderboard
      for (var player in c.leaderboard) {
        if (player.isUser) {
          player.name = "$_userName (You)";
          player.progress = c.progress;
        }
      }

      // Sort leaderboard: descending by progress
      c.leaderboard.sort((a, b) => b.progress.compareTo(a.progress));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    if (_isLoading) {
      return Scaffold(
        body: Container(
          color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          ),
        ),
      );
    }

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
            top: -50,
            left: -50,
            width: 250,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withValues(alpha: isDark ? 0.15 : 0.1),
                    Colors.blue.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Area
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Challenges 🏆",
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            "Push your limits & earn rewards",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Points Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text("🪙 ", style: TextStyle(fontSize: 14)),
                            Text(
                              "$_userPoints Pts",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Progress Rings Chart
                  _buildProgressCard(isDark),
                  const SizedBox(height: 24),

                  // Active Challenges Section Header
                  Text(
                    "Active Challenges",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Active challenges list
                  ..._challenges
                      .where((c) => c.isJoined)
                      .map((c) => Column(
                            children: [
                              _buildChallengeCard(c, isDark),
                              const SizedBox(height: 14),
                            ],
                          )),

                  const SizedBox(height: 12),

                  // Explore Section Header
                  Text(
                    "Explore New Challenges",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Explore/Upcoming challenges list
                  if (_challenges.where((c) => !c.isJoined).isEmpty)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Center(
                        child: Column(
                          children: [
                            const Text(
                              "🎉",
                              style: TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "You have joined all challenges!",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Stay tuned for new weekly events.",
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._challenges
                        .where((c) => !c.isJoined)
                        .map((c) => Column(
                              children: [
                                _buildUpcomingChallengeCard(c, isDark),
                                const SizedBox(height: 14),
                              ],
                            )),

                  const SizedBox(height: 80), // Padding to clear bottom navigation bar
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark) {
    final activeChallenges = _challenges.where((c) => c.isJoined).toList();
    final ringsData = activeChallenges.map((c) {
      return ConcentricRingData(
        value: (c.progress / c.target).clamp(0.0, 1.0),
        color: c.color,
        label: c.title,
      );
    }).toList();

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CHALLENGES OVERVIEW",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white60 : Colors.black54,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${activeChallenges.length} ACTIVE",
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Centered Stack combining the concentric rings chart and points inside the gap
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
                  left: 82, // Positioned inside the bottom-right gap (x > 70, y > 70)
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
                            "$_userPoints",
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            "pts",
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
                        "Total Points",
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
            children: activeChallenges.map((c) {
              final pct = ((c.progress / c.target) * 100).round();
              return _buildLegendItem(
                "${c.title.split(' ').first}: $pct%",
                c.color,
                isDark,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(Challenge challenge, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final color = challenge.color;

    final progressVal = (challenge.progress / challenge.target).clamp(0.0, 1.0);
    final formattedProgressText = challenge.progressTextPattern
        .replaceAll('%s', challenge.progress.round().toString());

    // Calculate user rank
    final userRankIndex = challenge.leaderboard.indexWhere((p) => p.isUser);
    final userRank = userRankIndex != -1 ? userRankIndex + 1 : 1;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  challenge.timeLeft,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.desc,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("🏆 ", style: TextStyle(fontSize: 12)),
                  Text(
                    "Rank #$userRank of ${challenge.leaderboard.length}",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text("🪙 ", style: TextStyle(fontSize: 12)),
                  Text(
                    "+${challenge.points} pts",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressVal,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedProgressText,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 11,
                ),
              ),
              Text(
                "${(progressVal * 100).round()}%",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 8),
          // View Leaderboard Button
          InkWell(
            onTap: () {
              setState(() {
                challenge.isExpanded = !challenge.isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    challenge.isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.emoji_events_outlined,
                    color: color,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    challenge.isExpanded ? "Hide Leaderboard" : "View Leaderboard",
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (challenge.isExpanded) ...[
            const SizedBox(height: 12),
            Text(
              "Leaderboard Competition",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: challenge.leaderboard.length,
              itemBuilder: (context, index) {
                final player = challenge.leaderboard[index];
                final isCurrentUser = player.isUser;
                
                Widget rankWidget;
                if (index == 0) {
                  rankWidget = const Text("🥇", style: TextStyle(fontSize: 14));
                } else if (index == 1) {
                  rankWidget = const Text("🥈", style: TextStyle(fontSize: 14));
                } else if (index == 2) {
                  rankWidget = const Text("🥉", style: TextStyle(fontSize: 14));
                } else {
                  rankWidget = Text(
                    "#${index + 1}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? color.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isCurrentUser
                        ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Center(child: rankWidget),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isCurrentUser
                            ? color.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.2),
                        child: Text(
                          player.name.isNotEmpty ? player.name[0].toUpperCase() : "?",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCurrentUser ? color : textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          player.name,
                          style: TextStyle(
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentUser ? textColor : textColor.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        player.progressText,
                        style: TextStyle(
                          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentUser ? color : secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingChallengeCard(Challenge challenge, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final color = challenge.color;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                challenge.timeLeft,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.desc,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("🪙 ", style: TextStyle(fontSize: 12)),
                  Text(
                    "Earn ${challenge.points} pts",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                ),
                onPressed: () {
                  setState(() {
                    challenge.isJoined = true;
                    _updateChallengeProgressWithRealData();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Joined ${challenge.title} challenge!"),
                      backgroundColor: color,
                    ),
                  );
                },
                child: const Text(
                  "Join Challenge",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
