import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/water/wave_painter.dart';

class WaterLoggingScreen extends StatefulWidget {
  final VoidCallback? onWaterLogged;
  const WaterLoggingScreen({super.key, this.onWaterLogged});

  @override
  State<WaterLoggingScreen> createState() => _WaterLoggingScreenState();
}

class _WaterLoggingScreenState extends State<WaterLoggingScreen> with TickerProviderStateMixin {
  final double _waterGoal = 2500.0; // Daily Goal in ml
  double _currentIntake = 0.0;
  bool _isSyncing = false;

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

  void _initializeBubbles() {
    for (int i = 0; i < 20; i++) {
      _bubbles.add(BubbleParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(), // Distribute vertically initially
        radius: 2.0 + _random.nextDouble() * 4.0,
        speed: 0.003 + _random.nextDouble() * 0.005,
      ));
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
        // Target progress represents current height percentage
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
    
    if (!mounted) return;
    
    if (success) {
      final oldIntake = _currentIntake;
      final newIntake = oldIntake + amount;
      
      // Setup level rise animation
      _startIntakeProgress = (oldIntake / _waterGoal).clamp(0.0, 1.0);
      _targetIntakeProgress = (newIntake / _waterGoal).clamp(0.0, 1.0);
      
      _levelAnimation = Tween<double>(
        begin: _startIntakeProgress,
        end: _targetIntakeProgress,
      ).animate(CurvedAnimation(
        parent: _levelController,
        curve: Curves.easeOutBack,
      ));
      
      setState(() {
        _currentIntake = newIntake;
      });

      _levelController.reset();
      _levelController.forward();

      // Trigger callback to refresh DashboardScreen stats
      if (widget.onWaterLogged != null) {
        widget.onWaterLogged!();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logged +$amount ml of water!"),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error logging water locally."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    
    setState(() => _isSyncing = false);
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
          // Glow Blob 1 (Top Left)
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
          // Glow Blob 2 (Bottom Right)
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
              padding: const EdgeInsets.only(bottom: 120), // Leave padding for floating bottom nav bar
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Screen Title
                    Row(
                      children: [
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
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 3. Custom Wave Beaker Cylinder
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Shadow/Outer Glow of beaker
                          Container(
                            width: 190,
                            height: 310,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(isDark ? 0.15 : 0.05),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
                          // The Clipped Glass Cylinder Beaker containing Wave Animation
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
                                    // Animated wave background & foreground
                                    AnimatedBuilder(
                                      animation: _waveController,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          painter: WavePainter(
                                            progress: currentVisualProgress,
                                            wavePhase: _waveController.value * 2 * pi,
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
                          
                          // Beaker Measurement ticks and label overlays (Overlaid on top of glass)
                          IgnorePointer(
                            child: Container(
                              width: 180,
                              height: 300,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                    // 4. Progress Summary Display
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
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 5. Preset quick log buttons
                    Text(
                      "Quick Logging",
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPresetCard("🥛 Cup", 250, isDark),
                        _buildPresetCard("🧴 Bottle", 500, isDark),
                        _buildPresetCard("🧉 Flask", 750, isDark),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 6. Custom Logger Input
                    Text(
                      "Custom Amount",
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: TextField(
                              controller: _customController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: "Enter volume (ml)",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                prefixIcon: const Icon(Icons.water_drop, color: Colors.blueAccent),
                                fillColor: isDark ? const Color(0xFF1E1E26) : Colors.white,
                                filled: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            shadowColor: Colors.blueAccent.withOpacity(0.3),
                          ),
                          onPressed: _isSyncing
                              ? null
                              : () {
                                  final val = int.tryParse(_customController.text) ?? 0;
                                  if (val > 0) {
                                    _logWater(val);
                                    _customController.clear();
                                    FocusScope.of(context).unfocus();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Please enter a valid volume amount")),
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

  Widget _buildPresetCard(String label, int amount, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: _isSyncing ? null : () => _logWater(amount),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  "+$amount ml",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
