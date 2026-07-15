import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/plan_models.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

/// Workout or Nutrition plans: today's schedule, AI generate, plan browser.
class PlanScreen extends StatefulWidget {
  final PlanKind kind;
  final VoidCallback? onPlanChanged;

  const PlanScreen({
    super.key,
    required this.kind,
    this.onPlanChanged,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;
  String? _email;

  // Views: home | create | detail
  String _view = 'home';
  int _createStep = 0;

  WorkoutDaySchedule? _workoutToday;
  NutritionDaySchedule? _nutritionToday;
  List<WorkoutPlan> _workoutPlans = [];
  List<NutritionPlan> _nutritionPlans = [];

  WorkoutPlan? _selectedWorkout;
  NutritionPlan? _selectedNutrition;
  int _selectedDayIndex = 0;

  // Create form
  int _durationDays = 7;
  String? _goal;
  String? _experience;
  String? _location;
  final Set<String> _equipment = {};
  final Set<String> _focusAreas = {};
  int _sessionMinutes = 45;
  String? _dietary;
  final Set<String> _allergies = {};
  int _mealsPerDay = 3;
  String? _cuisine;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _caloriesCtrl = TextEditingController();

  final Set<int> _expandedItems = {};

  late AnimationController _pulseCtrl;

  bool get _isWorkout => widget.kind == PlanKind.workout;

  Color get _accent =>
      _isWorkout ? const Color(0xFF5B8CFF) : const Color(0xFFFF9F43);
  Color get _accentDeep =>
      _isWorkout ? const Color(0xFF3D6FE0) : const Color(0xFFE67E22);
  Color get _glow =>
      _isWorkout ? const Color(0xFF8F6BFF) : const Color(0xFFFF6D55);

  String get _title => _isWorkout ? 'Workout Plans' : 'Nutrition Plans';
  String get _emoji => _isWorkout ? '💪' : '🥗';
  String get _subtitle =>
      _isWorkout ? 'Train with a clear daily path' : 'Meals, portions & macros';

  int get _createTotalSteps => _isWorkout ? 4 : 4;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _loadAll();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _caloriesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = await ApiService.instance.getUserEmail();
      final today = todayDateString();

      if (_isWorkout) {
        final listRes = await ApiService.instance.listWorkoutPlans(email);
        final plans = (listRes['plans'] as List<dynamic>? ?? [])
            .map((p) =>
                WorkoutPlan.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();

        WorkoutDaySchedule? day;
        try {
          final raw =
              await ApiService.instance.getWorkoutForDay(email, today);
          if (raw != null) day = WorkoutDaySchedule.fromJson(raw);
        } catch (e) {
          debugPrint('Workout day: $e');
        }

        if (!mounted) return;
        setState(() {
          _email = email;
          _workoutPlans = plans;
          _workoutToday = day;
          _isLoading = false;
        });
      } else {
        final listRes = await ApiService.instance.listNutritionPlans(email);
        final plans = (listRes['plans'] as List<dynamic>? ?? [])
            .map((p) =>
                NutritionPlan.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();

        NutritionDaySchedule? day;
        try {
          final raw =
              await ApiService.instance.getNutritionForDay(email, today);
          if (raw != null) day = NutritionDaySchedule.fromJson(raw);
        } catch (e) {
          debugPrint('Nutrition day: $e');
        }

        if (!mounted) return;
        setState(() {
          _email = email;
          _nutritionPlans = plans;
          _nutritionToday = day;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Plan load: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _openCreate() {
    setState(() {
      _view = 'create';
      _createStep = 0;
      _durationDays = 7;
      _goal = null;
      _experience = null;
      _location = null;
      _equipment.clear();
      _focusAreas.clear();
      _sessionMinutes = 45;
      _dietary = null;
      _allergies.clear();
      _mealsPerDay = 3;
      _cuisine = null;
      _titleCtrl.clear();
      _notesCtrl.clear();
      _caloriesCtrl.clear();
    });
  }

  Future<void> _openPlanDetail(int planId) async {
    if (_email == null) return;
    setState(() => _isLoading = true);
    try {
      if (_isWorkout) {
        final raw =
            await ApiService.instance.getWorkoutPlan(_email!, planId);
        final plan = WorkoutPlan.fromJson(raw);
        final today = todayDateString();
        var idx = plan.days.indexWhere((d) => d.date == today);
        if (idx < 0) idx = 0;
        if (!mounted) return;
        setState(() {
          _selectedWorkout = plan;
          _selectedDayIndex = idx;
          _view = 'detail';
          _isLoading = false;
          _expandedItems.clear();
        });
      } else {
        final raw =
            await ApiService.instance.getNutritionPlan(_email!, planId);
        final plan = NutritionPlan.fromJson(raw);
        final today = todayDateString();
        var idx = plan.days.indexWhere((d) => d.date == today);
        if (idx < 0) idx = 0;
        if (!mounted) return;
        setState(() {
          _selectedNutrition = plan;
          _selectedDayIndex = idx;
          _view = 'detail';
          _isLoading = false;
          _expandedItems.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _deletePlan(int planId) async {
    if (_email == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete plan?',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      if (_isWorkout) {
        await ApiService.instance.deleteWorkoutPlan(_email!, planId);
      } else {
        await ApiService.instance.deleteNutritionPlan(_email!, planId);
      }
      setState(() => _view = 'home');
      widget.onPlanChanged?.call();
      await _loadAll();
      _snack('Plan deleted');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _generate() async {
    if (_email == null) return;
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: _durationDays - 1));
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    try {
      Map<String, dynamic> planRaw;
      if (_isWorkout) {
        final body = <String, dynamic>{
          'start_date': fmt(start),
          'end_date': fmt(end),
          if (_titleCtrl.text.trim().isNotEmpty) 'title': _titleCtrl.text.trim(),
          if (_goal != null) 'goal': _goal,
          if (_experience != null) 'experience_level': _experience,
          if (_location != null) 'location': _location,
          if (_equipment.isNotEmpty) 'equipment': _equipment.toList(),
          if (_focusAreas.isNotEmpty) 'focus_areas': _focusAreas.toList(),
          'session_duration_minutes': _sessionMinutes,
          if (_notesCtrl.text.trim().isNotEmpty)
            'notes': _notesCtrl.text.trim(),
        };
        planRaw =
            await ApiService.instance.generateWorkoutPlan(_email!, body);
        final plan = WorkoutPlan.fromJson(planRaw);
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _selectedWorkout = plan;
          _selectedDayIndex = 0;
          _view = 'detail';
        });
      } else {
        final cal = int.tryParse(_caloriesCtrl.text.trim());
        final body = <String, dynamic>{
          'start_date': fmt(start),
          'end_date': fmt(end),
          if (_titleCtrl.text.trim().isNotEmpty) 'title': _titleCtrl.text.trim(),
          if (_goal != null) 'goal': _goal,
          if (_dietary != null) 'dietary_preference': _dietary,
          if (_allergies.isNotEmpty) 'allergies': _allergies.toList(),
          'meals_per_day': _mealsPerDay,
          if (_cuisine != null) 'cuisine': _cuisine,
          if (cal != null) 'daily_calories_target': cal,
          if (_notesCtrl.text.trim().isNotEmpty)
            'notes': _notesCtrl.text.trim(),
        };
        planRaw =
            await ApiService.instance.generateNutritionPlan(_email!, body);
        final plan = NutritionPlan.fromJson(planRaw);
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _selectedNutrition = plan;
          _selectedDayIndex = 0;
          _view = 'detail';
        });
      }

      widget.onPlanChanged?.call();
      await _loadAll();
      _snack('Your plan is ready! 🎉');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: error ? Colors.redAccent : const Color(0xFF2EE5A3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _onBack() {
    if (_view == 'create') {
      if (_createStep > 0) {
        setState(() => _createStep--);
      } else {
        setState(() => _view = 'home');
      }
      return;
    }
    if (_view == 'detail') {
      setState(() {
        _view = 'home';
        _selectedWorkout = null;
        _selectedNutrition = null;
      });
      return;
    }
    Navigator.pop(context);
  }

  bool _canAdvanceCreate() {
    if (_createStep == 0) return true; // duration
    if (_createStep == 1) return _goal != null;
    if (_createStep == 2) {
      if (_isWorkout) return _experience != null && _location != null;
      return _dietary != null;
    }
    return true; // extras optional
  }

  void _nextCreate() {
    if (!_canAdvanceCreate()) {
      _snack('Pick an option to continue', error: true);
      return;
    }
    if (_createStep < _createTotalSteps - 1) {
      setState(() => _createStep++);
    } else {
      _generate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondary = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          // Morph blobs
          Positioned(
            top: -100,
            right: -80,
            width: 300,
            height: 300,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withOpacity(
                          (isDark ? 0.26 : 0.16) * (0.7 + _pulseCtrl.value * 0.3)),
                      _accent.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -90,
            width: 280,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _glow.withOpacity(isDark ? 0.16 : 0.10),
                    _glow.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _accent))
                : Column(
                    children: [
                      _buildHeader(isDark, textColor, secondary),
                      Expanded(
                        child: _error != null &&
                                _view == 'home' &&
                                (_isWorkout
                                    ? _workoutPlans.isEmpty
                                    : _nutritionPlans.isEmpty) &&
                                !(_isWorkout
                                    ? (_workoutToday?.hasContent ?? false)
                                    : (_nutritionToday?.hasContent ?? false))
                            ? _buildError(textColor, secondary)
                            : _view == 'create'
                                ? _buildCreateFlow(
                                    isDark, textColor, secondary)
                                : _view == 'detail'
                                    ? _buildDetail(
                                        isDark, textColor, secondary)
                                    : _buildHome(
                                        theme, isDark, textColor, secondary),
                      ),
                    ],
                  ),
          ),
          if (_isGenerating) _buildGeneratingOverlay(isDark, textColor, secondary),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor, Color? secondary) {
    String heading = _title;
    String sub = _subtitle;
    if (_view == 'create') {
      heading = 'Create plan';
      sub = 'Step ${_createStep + 1} of $_createTotalSteps';
    } else if (_view == 'detail') {
      heading = _isWorkout
          ? (_selectedWorkout?.title ?? 'Plan')
          : (_selectedNutrition?.title ?? 'Plan');
      sub = _isWorkout
          ? (_selectedWorkout?.dateRangeLabel ?? '')
          : (_selectedNutrition?.dateRangeLabel ?? '');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _MorphIcon(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: _onBack,
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [_accent.withOpacity(0.28), _glow.withOpacity(0.10)],
              ),
              border: Border.all(color: _accent.withOpacity(0.22)),
            ),
            child: Center(
              child: Text(_emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: textColor,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: secondary,
                  ),
                ),
              ],
            ),
          ),
          if (_view == 'home')
            _MorphIcon(
              icon: Icons.refresh_rounded,
              isDark: isDark,
              onTap: _loadAll,
            ),
          if (_view == 'detail')
            _MorphIcon(
              icon: Icons.delete_outline_rounded,
              isDark: isDark,
              onTap: () {
                final id = _isWorkout
                    ? _selectedWorkout?.id
                    : _selectedNutrition?.id;
                if (id != null) _deletePlan(id);
              },
            ),
        ],
      ),
    );
  }

  // ─── HOME ──────────────────────────────────────────────────────

  Widget _buildHome(
    ThemeData theme,
    bool isDark,
    Color textColor,
    Color? secondary,
  ) {
    final hasToday = _isWorkout
        ? (_workoutToday?.hasContent ?? false)
        : (_nutritionToday?.hasContent ?? false);

    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroCard(isDark, textColor, secondary, hasToday),
            const SizedBox(height: 16),
            if (hasToday) ...[
              _buildTodayContent(isDark, textColor, secondary),
              const SizedBox(height: 20),
            ] else
              _buildEmptyToday(isDark, textColor, secondary),
            const SizedBox(height: 8),
            _buildSectionLabel("MY PLANS", theme),
            const SizedBox(height: 10),
            if ((_isWorkout ? _workoutPlans.isEmpty : _nutritionPlans.isEmpty))
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No plans yet. Create your first one and stay consistent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary, height: 1.4),
                ),
              )
            else if (_isWorkout)
              ..._workoutPlans.map(
                (plan) => _planListTile(
                  isDark: isDark,
                  textColor: textColor,
                  secondary: secondary,
                  title: plan.title,
                  subtitle: plan.preview,
                  meta: plan.dateRangeLabel,
                  onTap: () => _openPlanDetail(plan.id),
                ),
              )
            else
              ..._nutritionPlans.map(
                (plan) => _planListTile(
                  isDark: isDark,
                  textColor: textColor,
                  secondary: secondary,
                  title: plan.title,
                  subtitle: plan.preview,
                  meta: plan.dateRangeLabel,
                  onTap: () => _openPlanDetail(plan.id),
                ),
              ),
            const SizedBox(height: 20),
            _primaryButton(
              label: hasToday ? 'Create new plan' : 'Create my plan',
              icon: Icons.auto_awesome_rounded,
              onTap: _openCreate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    bool isDark,
    Color textColor,
    Color? secondary,
    bool hasToday,
  ) {
    final planTitle = _isWorkout
        ? (_workoutToday?.planTitle ?? 'Today\'s Workout')
        : (_nutritionToday?.planTitle ?? 'Today\'s Meals');
    final focus = _isWorkout
        ? (_workoutToday?.isRestDay == true
            ? 'Rest & recover'
            : (_workoutToday?.focus ??
                (hasToday
                    ? '${_workoutToday!.exercises.length} exercises'
                    : 'No session yet')))
        : (hasToday
            ? '${_nutritionToday!.meals.length} meals'
                '${_nutritionToday!.totalCalories > 0 ? ' · ${_nutritionToday!.totalCalories.round()} kcal' : ''}'
            : 'No meals planned');

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _accent.withOpacity(isDark ? 0.22 : 0.14),
              _glow.withOpacity(isDark ? 0.08 : 0.04),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: hasToday
                        ? const Color(0xFF2EE5A3).withOpacity(0.16)
                        : _accent.withOpacity(0.16),
                  ),
                  child: Text(
                    hasToday ? 'LIVE TODAY' : 'GET STARTED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: hasToday
                          ? const Color(0xFF2EE5A3)
                          : _accent,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  todayDateString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              planTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              focus,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: secondary,
              ),
            ),
            if (hasToday &&
                _isWorkout &&
                _workoutToday?.planId != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _openPlanDetail(_workoutToday!.planId!),
                child: Row(
                  children: [
                    Text(
                      'Open full plan',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _accent,
                        fontSize: 13,
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 16, color: _accent),
                  ],
                ),
              ),
            ],
            if (hasToday &&
                !_isWorkout &&
                _nutritionToday?.planId != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _openPlanDetail(_nutritionToday!.planId!),
                child: Row(
                  children: [
                    Text(
                      'Open full plan',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _accent,
                        fontSize: 13,
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 16, color: _accent),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyToday(
    bool isDark,
    Color textColor,
    Color? secondary,
  ) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      borderRadius: 22,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Transform.scale(
              scale: 1 + (_pulseCtrl.value * 0.04),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withOpacity(0.25),
                      _accent.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(color: _accent.withOpacity(0.25)),
                ),
                child: Center(
                  child: Text(_emoji, style: const TextStyle(fontSize: 36)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isWorkout
                ? 'Ready to train with purpose?'
                : 'Fuel your day with a real plan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isWorkout
                ? 'Tell us your goal, level, and gear. We\'ll build a multi-day workout with sets, reps, and how-to for each move.'
                : 'Set your goal, diet style, and calories. We\'ll schedule meals with portions and macros for every day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: secondary,
            ),
          ),
          const SizedBox(height: 20),
          _primaryButton(
            label: 'Generate with AI',
            icon: Icons.bolt_rounded,
            onTap: _openCreate,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayContent(
    bool isDark,
    Color textColor,
    Color? secondary,
  ) {
    if (_isWorkout) {
      final day = _workoutToday!;
      if (day.isRestDay) {
        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Text('😴', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rest day',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: textColor)),
                    Text(
                      day.notes ?? 'Recover, hydrate, and come back stronger.',
                      style: TextStyle(color: secondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          for (int i = 0; i < day.exercises.length; i++)
            _exerciseCard(day.exercises[i], i, isDark, textColor, secondary),
        ],
      );
    }

    final day = _nutritionToday!;
    return Column(
      children: [
        for (int i = 0; i < day.meals.length; i++)
          _mealCard(day.meals[i], i, isDark, textColor, secondary),
      ],
    );
  }

  Widget _exerciseCard(
    WorkoutExercise ex,
    int index,
    bool isDark,
    Color textColor,
    Color? secondary,
  ) {
    final expanded = _expandedItems.contains(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        borderRadius: 18,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedItems.remove(index);
              } else {
                _expandedItems.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withOpacity(0.14),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ex.dosageLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: secondary,
                    ),
                  ],
                ),
                if (ex.muscleGroups.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ex.muscleGroups
                        .map((m) => _miniChip(m, isDark))
                        .toList(),
                  ),
                ],
                if (expanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.03),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ex.howTo.isEmpty
                              ? 'Follow controlled form and full range of motion.'
                              : ex.howTo,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: textColor.withOpacity(0.85),
                          ),
                        ),
                        if (ex.equipment != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Equipment: ${ex.equipment}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mealCard(
    NutritionMeal meal,
    int index,
    bool isDark,
    Color textColor,
    Color? secondary,
  ) {
    final expanded = _expandedItems.contains(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        borderRadius: 18,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedItems.remove(index);
              } else {
                _expandedItems.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(meal.mealEmoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.mealTypeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: _accent,
                            ),
                          ),
                          Text(
                            meal.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (meal.calories != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _accent.withOpacity(0.12),
                        ),
                        child: Text(
                          '${meal.calories!.round()}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: _accent,
                          ),
                        ),
                      ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: secondary,
                    ),
                  ],
                ),
                if (meal.macrosLabel.isNotEmpty || meal.portion != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (meal.portion != null) meal.portion!,
                      if (meal.macrosLabel.isNotEmpty) meal.macrosLabel,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondary,
                    ),
                  ),
                ],
                if (expanded) ...[
                  const SizedBox(height: 12),
                  if (meal.howTo != null && meal.howTo!.isNotEmpty)
                    Text(
                      meal.howTo!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: textColor.withOpacity(0.85),
                      ),
                    ),
                  if (meal.ingredients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: meal.ingredients
                          .map((i) => _miniChip(i, isDark))
                          .toList(),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── CREATE FLOW ───────────────────────────────────────────────

  Widget _buildCreateFlow(bool isDark, Color textColor, Color? secondary) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_createStep + 1) / _createTotalSteps,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(_accent),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_createStep),
                child: _buildCreateStep(isDark, textColor, secondary),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _primaryButton(
            label: _createStep == _createTotalSteps - 1
                ? 'Generate plan'
                : 'Continue',
            icon: _createStep == _createTotalSteps - 1
                ? Icons.auto_awesome_rounded
                : Icons.arrow_forward_rounded,
            onTap: _nextCreate,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateStep(bool isDark, Color textColor, Color? secondary) {
    switch (_createStep) {
      case 0:
        return _createDurationStep(isDark, textColor, secondary);
      case 1:
        return _createGoalStep(isDark, textColor, secondary);
      case 2:
        return _isWorkout
            ? _createWorkoutPrefsStep(isDark, textColor, secondary)
            : _createNutritionPrefsStep(isDark, textColor, secondary);
      default:
        return _createExtrasStep(isDark, textColor, secondary);
    }
  }

  Widget _createDurationStep(
      bool isDark, Color textColor, Color? secondary) {
    final options = [
      (7, '1 week', 'Perfect starter'),
      (14, '2 weeks', 'Build a habit'),
      (21, '3 weeks', 'Deeper results'),
      (30, '30 days', 'Full transformation'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('How long should this plan run?', textColor),
        const SizedBox(height: 6),
        Text(
          'We\'ll schedule every day from today through the end date.',
          style: TextStyle(color: secondary, height: 1.35),
        ),
        const SizedBox(height: 20),
        ...options.map((o) {
          final selected = _durationDays == o.$1;
          return _selectCard(
            isDark: isDark,
            selected: selected,
            title: o.$2,
            subtitle: o.$3,
            trailing: '${o.$1}d',
            onTap: () => setState(() => _durationDays = o.$1),
            textColor: textColor,
            secondary: secondary,
          );
        }),
      ],
    );
  }

  Widget _createGoalStep(bool isDark, Color textColor, Color? secondary) {
    final goals = _isWorkout
        ? [
            'Lose weight',
            'Build muscle',
            'Improve endurance',
            'General fitness',
            'Increase flexibility',
            'Athletic performance',
          ]
        : [
            'Lose weight',
            'Gain muscle / bulk',
            'Maintain weight',
            'Improve energy',
            'Better digestion',
            'Athletic performance',
            'General healthy eating',
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          _isWorkout
              ? 'What\'s your primary fitness goal?'
              : 'What\'s your nutrition goal?',
          textColor,
        ),
        const SizedBox(height: 6),
        Text(
          'This shapes intensity, volume, and food choices.',
          style: TextStyle(color: secondary),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: goals
              .map((g) => _chip(
                    label: g,
                    selected: _goal == g,
                    onTap: () => setState(() => _goal = g),
                    isDark: isDark,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _createWorkoutPrefsStep(
      bool isDark, Color textColor, Color? secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Your training setup', textColor),
        const SizedBox(height: 16),
        Text('Experience',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Beginner', 'Intermediate', 'Advanced']
              .map((e) => _chip(
                    label: e,
                    selected: _experience == e,
                    onTap: () => setState(() => _experience = e),
                    isDark: isDark,
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('Location',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Home', 'Gym', 'Outdoor', 'Mixed']
              .map((e) => _chip(
                    label: e,
                    selected: _location == e,
                    onTap: () => setState(() => _location = e),
                    isDark: isDark,
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('Session length',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [20, 30, 45, 60, 90]
              .map((m) => _chip(
                    label: '$m min',
                    selected: _sessionMinutes == m,
                    onTap: () => setState(() => _sessionMinutes = m),
                    isDark: isDark,
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('Equipment',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'None (bodyweight only)',
            'Dumbbells',
            'Barbell',
            'Resistance bands',
            'Pull-up bar',
            'Kettlebells',
            'Machines',
            'Cardio machines',
          ]
              .map((e) => _chip(
                    label: e,
                    selected: _equipment.contains(e),
                    multi: true,
                    onTap: () => setState(() {
                      if (_equipment.contains(e)) {
                        _equipment.remove(e);
                      } else {
                        if (e.startsWith('None')) {
                          _equipment
                            ..clear()
                            ..add(e);
                        } else {
                          _equipment.removeWhere((x) => x.startsWith('None'));
                          _equipment.add(e);
                        }
                      }
                    }),
                    isDark: isDark,
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('Focus areas',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Full body',
            'Upper body',
            'Lower body',
            'Core',
            'Cardio',
            'Mobility',
          ]
              .map((e) => _chip(
                    label: e,
                    selected: _focusAreas.contains(e),
                    multi: true,
                    onTap: () => setState(() {
                      if (_focusAreas.contains(e)) {
                        _focusAreas.remove(e);
                      } else {
                        _focusAreas.add(e);
                      }
                    }),
                    isDark: isDark,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _createNutritionPrefsStep(
      bool isDark, Color textColor, Color? secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Your eating style', textColor),
        const SizedBox(height: 16),
        Text('Dietary preference',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Omnivore (no restrictions)',
            'Vegetarian',
            'Vegan',
            'Pescatarian',
            'Eggetarian',
            'Keto / low carb',
            'High protein',
            'Mediterranean',
          ]
              .map((e) => _chip(
                    label: e,
                    selected: _dietary == e,
                    onTap: () => setState(() => _dietary = e),
                    isDark: isDark,
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('Allergies / intolerances',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'None',
            'Dairy / lactose',
            'Gluten / wheat',
            'Nuts',
            'Peanuts',
            'Shellfish',
            'Eggs',
            'Soy',
          ]
              .map((e) => _chip(
                    label: e,
                    selected: _allergies.contains(e),
                    multi: true,
                    onTap: () => setState(() {
                      if (_allergies.contains(e)) {
                        _allergies.remove(e);
                      } else {
                        if (e == 'None') {
                          _allergies
                            ..clear()
                            ..add(e);
                        } else {
                          _allergies.remove('None');
                          _allergies.add(e);
                        }
                      }
                    }),
                    isDark: isDark,
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('Meals per day',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [2, 3, 4, 5, 6]
              .map((n) => _chip(
                    label: '$n',
                    selected: _mealsPerDay == n,
                    onTap: () => setState(() => _mealsPerDay = n),
                    isDark: isDark,
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('Daily calories (optional)',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _caloriesCtrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          decoration: _fieldDeco(isDark, 'e.g. 2000'),
        ),
      ],
    );
  }

  Widget _createExtrasStep(bool isDark, Color textColor, Color? secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Final touches', textColor),
        const SizedBox(height: 6),
        Text(
          'Optional — skip anything you don\'t need.',
          style: TextStyle(color: secondary),
        ),
        const SizedBox(height: 18),
        Text('Plan title',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          decoration: _fieldDeco(
            isDark,
            _isWorkout ? 'e.g. Summer Strength' : 'e.g. Clean Eating Week',
          ),
        ),
        if (!_isWorkout) ...[
          const SizedBox(height: 16),
          Text('Cuisine preference',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Indian',
              'Mediterranean',
              'Asian',
              'Western',
              'Mixed',
            ]
                .map((e) => _chip(
                      label: e,
                      selected: _cuisine == e,
                      onTap: () => setState(() => _cuisine = e),
                      isDark: isDark,
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        Text('Notes for the planner',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: secondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          decoration: _fieldDeco(
            isDark,
            _isWorkout
                ? 'Injuries, preferences, busy days…'
                : 'Foods you love or hate…',
          ),
        ),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to generate',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_durationDays days · ${_goal ?? 'Your goal'}'
                '${_isWorkout ? ' · ${_experience ?? ''} · $_sessionMinutes min' : ' · $_mealsPerDay meals/day'}',
                style: TextStyle(color: secondary, height: 1.35, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── DETAIL ────────────────────────────────────────────────────

  Widget _buildDetail(bool isDark, Color textColor, Color? secondary) {
    if (_isWorkout) {
      final plan = _selectedWorkout;
      if (plan == null) return const SizedBox.shrink();
      final days = plan.days;
      final day = days.isEmpty
          ? null
          : days[_selectedDayIndex.clamp(0, days.length - 1)];

      return Column(
        children: [
          if (plan.goal != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 18, color: _accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.goal!,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (days.isNotEmpty)
            SizedBox(
              height: 78,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: days.length,
                itemBuilder: (ctx, i) {
                  final d = days[i];
                  final selected = i == _selectedDayIndex;
                  final label = _shortDay(d.date);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedDayIndex = i;
                        _expandedItems.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [_accent, _accentDeep],
                                )
                              : null,
                          color: selected
                              ? null
                              : (isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.white.withOpacity(0.7)),
                          border: Border.all(
                            color: selected
                                ? _accent
                                : (isDark
                                    ? Colors.white12
                                    : Colors.black12),
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: _accent.withOpacity(0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label.$1,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: selected ? Colors.white70 : secondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label.$2,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: selected ? Colors.white : textColor,
                              ),
                            ),
                            if (d.isRestDay)
                              Text(
                                'REST',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: selected
                                      ? Colors.white70
                                      : _accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: day == null
                ? Center(
                    child: Text('No days in this plan',
                        style: TextStyle(color: secondary)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                    children: [
                      if (day.focus != null) ...[
                        Text(
                          day.focus!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (day.isRestDay)
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            day.notes ?? 'Rest day — recover well.',
                            style: TextStyle(color: secondary, height: 1.4),
                          ),
                        )
                      else
                        for (int i = 0; i < day.exercises.length; i++)
                          _exerciseCard(
                            day.exercises[i],
                            i,
                            isDark,
                            textColor,
                            secondary,
                          ),
                    ],
                  ),
          ),
        ],
      );
    }

    // Nutrition detail
    final plan = _selectedNutrition;
    if (plan == null) return const SizedBox.shrink();
    final days = plan.days;
    final day =
        days.isEmpty ? null : days[_selectedDayIndex.clamp(0, days.length - 1)];

    return Column(
      children: [
        if (plan.goal != null || plan.dailyCaloriesTarget != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: GlassCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.restaurant_menu_rounded,
                      size: 18, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (plan.goal != null) plan.goal!,
                        if (plan.dailyCaloriesTarget != null)
                          '${plan.dailyCaloriesTarget} kcal/day',
                      ].join(' · '),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (days.isNotEmpty)
          SizedBox(
            height: 78,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: days.length,
              itemBuilder: (ctx, i) {
                final d = days[i];
                final selected = i == _selectedDayIndex;
                final label = _shortDay(d.date);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedDayIndex = i;
                      _expandedItems.clear();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: selected
                            ? LinearGradient(colors: [_accent, _accentDeep])
                            : null,
                        color: selected
                            ? null
                            : (isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.white.withOpacity(0.7)),
                        border: Border.all(
                          color: selected
                              ? _accent
                              : (isDark ? Colors.white12 : Colors.black12),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label.$1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white70 : secondary,
                            ),
                          ),
                          Text(
                            label.$2,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: selected ? Colors.white : textColor,
                            ),
                          ),
                          Text(
                            '${d.meals.length}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white70 : _accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: day == null
              ? Center(
                  child: Text('No days in this plan',
                      style: TextStyle(color: secondary)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  children: [
                    if (day.totalCalories > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${day.totalCalories.round()} kcal today',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    for (int i = 0; i < day.meals.length; i++)
                      _mealCard(
                          day.meals[i], i, isDark, textColor, secondary),
                  ],
                ),
        ),
      ],
    );
  }

  // ─── SHARED UI ─────────────────────────────────────────────────

  Widget _buildError(Color textColor, Color? secondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, color: _accent, size: 40),
              const SizedBox(height: 12),
              Text('Could not load plans',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 8),
              Text(_error ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary, fontSize: 13)),
              const SizedBox(height: 16),
              _primaryButton(label: 'Retry', onTap: _loadAll),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratingOverlay(
      bool isDark, Color textColor, Color? secondary) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: 260,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF16161C).withOpacity(0.92)
                      : Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: _accent,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Crafting your plan…',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Building day-by-day ${_isWorkout ? 'workouts' : 'meals'}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepTitle(String t, Color textColor) => Text(
        t,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.4,
          height: 1.25,
          color: textColor,
        ),
      );

  Widget _buildSectionLabel(String t, ThemeData theme) => Text(
        t,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: theme.colorScheme.primary,
        ),
      );

  Widget _primaryButton({
    required String label,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [_accent, _accentDeep]),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectCard({
    required bool isDark,
    required bool selected,
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback onTap,
    required Color textColor,
    required Color? secondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? _accent.withOpacity(isDark ? 0.18 : 0.12)
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.75)),
              border: Border.all(
                color: selected
                    ? _accent.withOpacity(0.55)
                    : (isDark ? Colors.white12 : Colors.black12),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: textColor)),
                      Text(subtitle,
                          style: TextStyle(color: secondary, fontSize: 12.5)),
                    ],
                  ),
                ),
                Text(
                  trailing,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selected ? _accent : secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
    bool multi = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected
              ? LinearGradient(colors: [_accent, _accentDeep])
              : null,
          color: selected
              ? null
              : (isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.8)),
          border: Border.all(
            color: selected
                ? _accent
                : (isDark ? Colors.white12 : Colors.black12),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _accent.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: _accent.withOpacity(0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _accent,
        ),
      ),
    );
  }

  Widget _planListTile({
    required bool isDark,
    required Color textColor,
    required Color? secondary,
    required String title,
    required String subtitle,
    required String meta,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        borderRadius: 18,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _accent.withOpacity(0.14),
                  ),
                  child: Center(
                    child: Text(_emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              fontSize: 14)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      Text(meta,
                          style: TextStyle(
                              color: _accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.black38,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  (String, String) _shortDay(String date) {
    try {
      final d = DateTime.parse(date);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return (days[d.weekday - 1], '${d.day}');
    } catch (_) {
      return ('Day', date.length >= 2 ? date.substring(date.length - 2) : date);
    }
  }
}

class _MorphIcon extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback? onTap;

  const _MorphIcon({
    required this.icon,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }
}
