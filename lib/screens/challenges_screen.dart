import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../widgets/glass_card.dart';
import '../widgets/concentric_rings_chart.dart';
import '../services/health_service.dart';
import '../services/auth_service.dart';

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
  final int participantsCount;
  bool completed;
  final String? infoText;

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
    required this.participantsCount,
    required this.completed,
    this.isExpanded = false,
    this.infoText,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String? ?? 'steps';
    final target = (json['targetValue'] as num?)?.toDouble() ?? 1.0;
    final unit = json['unit'] as String? ?? '';

    Color cColor = Colors.blue;
    if (category == 'water')
      cColor = Colors.blueAccent;
    else if (category == 'steps')
      cColor = Colors.green;
    else if (category == 'sleep')
      cColor = Colors.purple;
    else if (category == 'calories')
      cColor = Colors.orange;

    final endStr = json['endDate'] as String? ?? '';
    String timeRemaining = "Active";
    if (endStr.isNotEmpty) {
      final end = DateTime.tryParse(endStr);
      if (end != null) {
        final diff = end.difference(DateTime.now());
        timeRemaining = diff.inDays > 0
            ? "${diff.inDays} days left"
            : "Ends today";
      }
    }

    return Challenge(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      desc:
          json['shortDescription'] as String? ??
          json['description'] as String? ??
          '',
      progress: (json['currentProgress'] as num?)?.toDouble() ?? 0.0,
      target: target,
      progressTextPattern: "Progress: %s/${target.round()} $unit",
      points: json['rewardPoints'] as int? ?? 0,
      timeLeft: timeRemaining,
      color: cColor,
      metricType: category,
      isJoined: json['joined'] as bool? ?? false,
      leaderboard: [],
      participantsCount: json['participantsCount'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
      isExpanded: false,
      infoText: json['infoText'] as String?,
    );
  }
}

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  int _userPoints = 0;
  String _userName = "User";
  bool _isLoading = true;
  String? _errorMessage;
  HealthData _healthData = HealthData();
  List<Challenge> _challenges = [];
  final Map<String, bool> _leaderboardLoading = {};
  List<String> _claimedRewards = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _updateUserPoints() {
    int total = 0;
    for (var c in _challenges) {
      if (_claimedRewards.contains(c.id)) {
        total += c.points;
      }
    }
    setState(() {
      _userPoints = total;
    });
  }

  Future<void> _loadData({
    bool showLoadingIndicator = true,
    bool forceRefresh = false,
  }) async {
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

    final claimed = prefs.getStringList('claimed_challenge_rewards') ?? [];

    HealthData healthData = HealthData();
    try {
      healthData = await HealthService.instance.fetchHealthData(
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint("Error fetching health data: $e");
    }

    if (mounted) {
      setState(() {
        _userName = name;
        _healthData = healthData;
        _claimedRewards = claimed;
      });
      await _fetchChallenges(
        showLoadingIndicator: showLoadingIndicator,
        forceRefresh: forceRefresh,
      );
    }
  }

  Future<void> _waitForHomeSync() async {
    if (HealthService.instance.homeSyncFuture != null) {
      debugPrint(
        "Merged Home Sync is in progress. Waiting for completion before calling other APIs...",
      );
      await HealthService.instance.homeSyncFuture;
      debugPrint("Merged Home Sync completed. Resuming API request flow.");
    }
  }

  Future<void> _fetchChallenges({
    bool preventSync = false,
    bool showLoadingIndicator = true,
    bool forceRefresh = false,
  }) async {
    await _waitForHomeSync();
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = await AuthService.instance.getAccessToken();
      final url = '${AuthService.apiBaseUrl}/api/challenges';

      debugPrint(
        "================ GET CHALLENGES API REQUEST ================",
      );
      debugPrint("URL: $url");
      debugPrint("Method: GET");
      debugPrint(
        "Headers: ${token != null ? 'Authorization: Bearer [$token]' : 'None'}",
      );
      debugPrint(
        "============================================================",
      );

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

      debugPrint(
        "================ GET CHALLENGES API RESPONSE ================",
      );
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");
      debugPrint(
        "=============================================================",
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        final fetched = list.map((json) => Challenge.fromJson(json)).toList();
        setState(() {
          _challenges = fetched;
        });
        _updateUserPoints();
        if (!preventSync) {
          await _calculateAndSyncProgress(forceRefresh: forceRefresh);
        }
      } else {
        setState(() {
          _errorMessage =
              "Failed to load challenges from server (${response.statusCode})";
        });
      }
    } catch (e) {
      debugPrint("Error loading challenges: $e");
      setState(() {
        _errorMessage = "Failed to connect to server: $e";
      });
    } finally {
      if (showLoadingIndicator) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _calculateAndSyncProgress({bool forceRefresh = false}) async {
    await _waitForHomeSync();
    final dailyRecords = await HealthService.instance
        .fetchDailyHealthDataForPeriod(days: 7, forceRefresh: forceRefresh);

    bool didSyncAny = false;
    for (var challenge in _challenges) {
      if (!challenge.isJoined) continue;

      double calculatedProgress = 0.0;

      if (challenge.metricType == 'water') {
        calculatedProgress = dailyRecords
            .where((r) {
              final waterVal = ((r['water_intake_ml'] ?? 0) as num).toDouble();
              return waterVal >= 2000.0;
            })
            .length
            .toDouble();
      } else if (challenge.metricType == 'steps') {
        calculatedProgress = dailyRecords
            .where((r) {
              final stepsVal = ((r['steps'] ?? 0) as num).toDouble();
              return stepsVal >= 10000.0;
            })
            .length
            .toDouble();
      } else if (challenge.metricType == 'sleep') {
        calculatedProgress = dailyRecords
            .where((r) {
              final sleepVal = ((r['sleep_duration_hours'] ?? 0.0) as num)
                  .toDouble();
              return sleepVal >= 7.5;
            })
            .length
            .toDouble();
      } else if (challenge.metricType == 'calories') {
        calculatedProgress = dailyRecords
            .where((r) {
              final calVal = ((r['calories'] ?? 0) as num).toDouble();
              return calVal >= 500.0;
            })
            .length
            .toDouble();
      }

      if (calculatedProgress > challenge.target) {
        calculatedProgress = challenge.target;
      }

      setState(() {
        challenge.progress = calculatedProgress;
      });

      try {
        final token = await AuthService.instance.getAccessToken();
        final syncUrl =
            '${AuthService.apiBaseUrl}/api/challenges/${challenge.id}/progress';

        debugPrint(
          "================ UPDATE PROGRESS API REQUEST ================",
        );
        debugPrint("URL: $syncUrl");
        debugPrint("Method: POST");
        debugPrint(
          "Headers: ${token != null ? 'Authorization: Bearer [token]' : 'None'}",
        );
        debugPrint("Body: {'progress': $calculatedProgress}");
        debugPrint(
          "=============================================================",
        );

        final response = await http.post(
          Uri.parse(syncUrl),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'progress': calculatedProgress}),
        );

        debugPrint(
          "================ UPDATE PROGRESS API RESPONSE ================",
        );
        debugPrint("Challenge: ${challenge.title}");
        debugPrint("Status Code: ${response.statusCode}");
        debugPrint("Response Body: ${response.body}");
        debugPrint(
          "=============================================================",
        );

        if (response.statusCode == 200) {
          didSyncAny = true;
        }
      } catch (e) {
        debugPrint("Failed to sync progress for ${challenge.title}: $e");
      }
    }

    if (didSyncAny) {
      // Re-fetch challenges to update state from server (completed flags, rank, participantsCount, etc.)
      await _fetchChallenges(preventSync: true, showLoadingIndicator: false);
    }
  }

  Future<void> _joinChallenge(Challenge challenge) async {
    await _waitForHomeSync();
    setState(() {
      _isLoading = true;
    });
    try {
      final token = await AuthService.instance.getAccessToken();
      final url =
          '${AuthService.apiBaseUrl}/api/challenges/${challenge.id}/join';

      debugPrint(
        "================ JOIN CHALLENGE API REQUEST ================",
      );
      debugPrint("URL: $url");
      debugPrint("Method: POST");
      debugPrint(
        "Headers: ${token != null ? 'Authorization: Bearer [token]' : 'None'}",
      );
      debugPrint(
        "============================================================",
      );

      var response = await http.post(
        Uri.parse(url),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        await AuthService.instance.refreshSessionToken();
        final newToken = await AuthService.instance.getAccessToken();
        response = await http.post(
          Uri.parse(url),
          headers: {if (newToken != null) 'Authorization': 'Bearer $newToken'},
        );
      }

      debugPrint(
        "================ JOIN CHALLENGE API RESPONSE ================",
      );
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");
      debugPrint(
        "=============================================================",
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          challenge.isJoined = true;
        });
        await _calculateAndSyncProgress();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Joined ${challenge.title} challenge!"),
            backgroundColor: challenge.color,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to join challenge: ${response.statusCode}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error joining challenge: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network error: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLeaderboard(Challenge challenge) async {
    await _waitForHomeSync();
    setState(() {
      _leaderboardLoading[challenge.id] = true;
    });
    try {
      final token = await AuthService.instance.getAccessToken();
      final url =
          '${AuthService.apiBaseUrl}/api/challenges/${challenge.id}/leaderboard?page=1&limit=10&leaderboardType=GLOBAL';

      debugPrint(
        "================ GET LEADERBOARD API REQUEST ================",
      );
      debugPrint("URL: $url");
      debugPrint("Method: GET");
      debugPrint(
        "Headers: ${token != null ? 'Authorization: Bearer [token]' : 'None'}",
      );
      debugPrint(
        "=============================================================",
      );

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

      debugPrint(
        "================ GET LEADERBOARD API RESPONSE ================",
      );
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");
      debugPrint(
        "=============================================================",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> leadersJson = data['leaders'] ?? [];

        final List<LeaderboardPlayer> players = leadersJson.map((l) {
          final name = l['name'] as String? ?? 'User';
          final progress = (l['progress'] as num?)?.toDouble() ?? 0.0;
          return LeaderboardPlayer(
            name: name == _userName ? "$name (You)" : name,
            progress: progress,
            progressTextPattern:
                "%s ${challenge.progressTextPattern.split(' ').last}",
            isUser: name == _userName,
          );
        }).toList();

        players.sort((a, b) => b.progress.compareTo(a.progress));

        setState(() {
          challenge.leaderboard = players;
        });
      }
    } catch (e) {
      debugPrint("Error fetching leaderboard: $e");
    } finally {
      setState(() {
        _leaderboardLoading[challenge.id] = false;
      });
    }
  }

  Future<void> _claimReward(Challenge challenge) async {
    await _waitForHomeSync();
    setState(() {
      _isLoading = true;
    });
    try {
      final token = await AuthService.instance.getAccessToken();
      final url =
          '${AuthService.apiBaseUrl}/api/challenges/${challenge.id}/claim-reward';

      debugPrint("================ CLAIM REWARD API REQUEST ================");
      debugPrint("URL: $url");
      debugPrint("Method: POST");
      debugPrint(
        "Headers: ${token != null ? 'Authorization: Bearer [token]' : 'None'}",
      );
      debugPrint("==========================================================");

      var response = await http.post(
        Uri.parse(url),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        await AuthService.instance.refreshSessionToken();
        final newToken = await AuthService.instance.getAccessToken();
        response = await http.post(
          Uri.parse(url),
          headers: {if (newToken != null) 'Authorization': 'Bearer $newToken'},
        );
      }

      debugPrint("================ CLAIM REWARD API RESPONSE ================");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");
      debugPrint("===========================================================");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int rewardPoints = data['rewardPoints'] ?? challenge.points;

        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _claimedRewards.add(challenge.id);
        });

        await prefs.setStringList('claimed_challenge_rewards', _claimedRewards);
        _updateUserPoints();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "🎉 Claimed $rewardPoints points for completing ${challenge.title}!",
            ),
            backgroundColor: Colors.amber,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to claim reward: ${response.statusCode}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error claiming reward: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network error: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    if (_errorMessage != null) {
      return Scaffold(
        body: Container(
          color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("⚠️", style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
            child: RefreshIndicator(
              color: Colors.blueAccent,
              onRefresh: () async {
                await _loadData(
                  showLoadingIndicator: false,
                  forceRefresh: true,
                );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
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
                    if (_challenges.where((c) => c.isJoined).isEmpty)
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Text(
                                "🧗‍♂️",
                                style: TextStyle(fontSize: 36),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No Active Challenges",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Join a challenge below to start tracking your progress & earning rewards!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._challenges
                          .where((c) => c.isJoined)
                          .map(
                            (c) => Column(
                              children: [
                                _buildChallengeCard(c, isDark),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),

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
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Text("🎉", style: TextStyle(fontSize: 32)),
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
                          .map(
                            (c) => Column(
                              children: [
                                _buildUpcomingChallengeCard(c, isDark),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),

                    const SizedBox(
                      height: 80,
                    ), // Padding to clear bottom navigation bar
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark) {
    final activeChallenges = _challenges.where((c) => c.isJoined).toList();
    final ringsData = activeChallenges.isEmpty
        ? [
            ConcentricRingData(
              value: 0.0,
              color: Colors.grey.withValues(alpha: 0.2),
              label: "No active challenges",
            ),
          ]
        : activeChallenges.map((c) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    final formattedProgressText = challenge.progressTextPattern.replaceAll(
      '%s',
      challenge.progress.round().toString(),
    );

    // Calculate user rank
    final userRankIndex = challenge.leaderboard.indexWhere((p) => p.isUser);
    final userRank = userRankIndex != -1 ? userRankIndex + 1 : 1;
    final isClaimed = _claimedRewards.contains(challenge.id);

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
                    challenge.leaderboard.isNotEmpty
                        ? "Rank #$userRank of ${challenge.participantsCount}"
                        : "${challenge.participantsCount} participants",
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
              backgroundColor: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedProgressText,
                style: TextStyle(color: secondaryTextColor, fontSize: 11),
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
          if (challenge.progress >= challenge.target) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isClaimed
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.amber,
                foregroundColor: isClaimed ? Colors.green : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: isClaimed ? null : () => _claimReward(challenge),
              icon: Icon(
                isClaimed ? Icons.check_circle_outline : Icons.card_giftcard,
              ),
              label: Text(
                isClaimed
                    ? "Reward Claimed"
                    : "Claim Reward (${challenge.points} Pts) 🎉",
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 12),
          ],
          InkWell(
            onTap: () {
              setState(() {
                challenge.isExpanded = !challenge.isExpanded;
              });
              if (challenge.isExpanded && challenge.leaderboard.isEmpty) {
                _fetchLeaderboard(challenge);
              }
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
                    challenge.isExpanded
                        ? "Hide Leaderboard"
                        : "View Leaderboard",
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
            if (_leaderboardLoading[challenge.id] ?? false)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                ),
              )
            else if (challenge.leaderboard.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    "No competition data available yet.",
                    style: TextStyle(color: secondaryTextColor, fontSize: 11),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: challenge.leaderboard.length,
                itemBuilder: (context, index) {
                  final player = challenge.leaderboard[index];
                  final isCurrentUser = player.isUser;

                  Widget rankWidget;
                  if (index == 0) {
                    rankWidget = const Text(
                      "🥇",
                      style: TextStyle(fontSize: 14),
                    );
                  } else if (index == 1) {
                    rankWidget = const Text(
                      "🥈",
                      style: TextStyle(fontSize: 14),
                    );
                  } else if (index == 2) {
                    rankWidget = const Text(
                      "🥉",
                      style: TextStyle(fontSize: 14),
                    );
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? color.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isCurrentUser
                          ? Border.all(
                              color: color.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 24, child: Center(child: rankWidget)),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isCurrentUser
                              ? color.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          child: Text(
                            player.name.isNotEmpty
                                ? player.name[0].toUpperCase()
                                : "?",
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
                              fontWeight: isCurrentUser
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrentUser
                                  ? textColor
                                  : textColor.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          player.progressText,
                          style: TextStyle(
                            fontWeight: isCurrentUser
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        challenge.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (challenge.infoText != null &&
                        challenge.infoText!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            challenge.isExpanded = !challenge.isExpanded;
                          });
                        },
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: color,
                        ),
                      ),
                    ],
                  ],
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
          if (challenge.isExpanded &&
              challenge.infoText != null &&
              challenge.infoText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      challenge.infoText!,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.9),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                ),
                onPressed: () => _joinChallenge(challenge),
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
