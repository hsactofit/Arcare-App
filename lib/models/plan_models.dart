enum PlanKind { workout, nutrition }

// ── Shared helpers ──────────────────────────────────────────────

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

// ── Workout models ──────────────────────────────────────────────

class WorkoutExercise {
  final String name;
  final String howTo;
  final int? sets;
  final String? reps;
  final double? durationMinutes;
  final int? restSeconds;
  final String? equipment;
  final List<String> muscleGroups;
  final String? imageUrl;

  const WorkoutExercise({
    required this.name,
    required this.howTo,
    this.sets,
    this.reps,
    this.durationMinutes,
    this.restSeconds,
    this.equipment,
    this.muscleGroups = const [],
    this.imageUrl,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      name: json['name']?.toString() ?? 'Exercise',
      howTo: json['how_to']?.toString() ?? '',
      sets: (json['sets'] as num?)?.toInt(),
      reps: json['reps']?.toString(),
      durationMinutes: (json['duration_minutes'] as num?)?.toDouble(),
      restSeconds: (json['rest_seconds'] as num?)?.toInt(),
      equipment: json['equipment']?.toString(),
      muscleGroups: (json['muscle_groups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      imageUrl: json['image_url']?.toString(),
    );
  }

  String get dosageLabel {
    final parts = <String>[];
    if (sets != null) parts.add('${sets}×');
    if (reps != null && reps!.isNotEmpty) {
      parts.add(parts.isEmpty ? '$reps reps' : reps!);
    }
    if (durationMinutes != null) {
      parts.add('${durationMinutes!.round()} min');
    }
    if (restSeconds != null) parts.add('${restSeconds}s rest');
    return parts.isEmpty ? 'See details' : parts.join(' · ');
  }
}

class WorkoutDay {
  final String date;
  final String? focus;
  final bool isRestDay;
  final String? notes;
  final List<WorkoutExercise> exercises;

  const WorkoutDay({
    required this.date,
    this.focus,
    this.isRestDay = false,
    this.notes,
    this.exercises = const [],
  });

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      date: json['date']?.toString() ?? '',
      focus: json['focus']?.toString(),
      isRestDay: json['is_rest_day'] as bool? ?? false,
      notes: json['notes']?.toString(),
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) =>
                  WorkoutExercise.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  int get exerciseCount => exercises.length;
}

class WorkoutDaySchedule {
  final String date;
  final int? planId;
  final String? planTitle;
  final String? focus;
  final bool isRestDay;
  final String? notes;
  final List<WorkoutExercise> exercises;

  const WorkoutDaySchedule({
    required this.date,
    this.planId,
    this.planTitle,
    this.focus,
    this.isRestDay = false,
    this.notes,
    this.exercises = const [],
  });

  factory WorkoutDaySchedule.fromJson(Map<String, dynamic> json) {
    return WorkoutDaySchedule(
      date: json['date']?.toString() ?? '',
      planId: (json['plan_id'] as num?)?.toInt(),
      planTitle: json['plan_title']?.toString(),
      focus: json['focus']?.toString(),
      isRestDay: json['is_rest_day'] as bool? ?? false,
      notes: json['notes']?.toString(),
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) =>
                  WorkoutExercise.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  bool get hasContent =>
      planId != null || exercises.isNotEmpty || isRestDay || (focus != null);
}

class WorkoutPlan {
  final int id;
  final int userId;
  final String title;
  final String? goal;
  final String? notes;
  final String startDate;
  final String endDate;
  final List<WorkoutDay> days;
  final String createdAt;
  final String? updatedAt;

  const WorkoutPlan({
    required this.id,
    required this.userId,
    required this.title,
    this.goal,
    this.notes,
    required this.startDate,
    required this.endDate,
    this.days = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Workout Plan',
      goal: json['goal']?.toString(),
      notes: json['notes']?.toString(),
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      days: (json['days'] as List<dynamic>?)
              ?.map((d) =>
                  WorkoutDay.fromJson(Map<String, dynamic>.from(d as Map)))
              .toList() ??
          const [],
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString(),
    );
  }

  int get dayCount => days.length;
  int get totalExercises =>
      days.fold(0, (sum, d) => sum + d.exercises.length);

  String get dateRangeLabel {
    if (startDate.isEmpty) return '';
    if (startDate == endDate) return startDate;
    return '$startDate → $endDate';
  }

  String get preview {
    if (goal != null && goal!.trim().isNotEmpty) return goal!.trim();
    if (notes != null && notes!.trim().isNotEmpty) return notes!.trim();
    return '$dayCount days · $totalExercises exercises';
  }

  bool coversDate(String date) {
    final d = _parseDate(date);
    final s = _parseDate(startDate);
    final e = _parseDate(endDate);
    if (d == null || s == null || e == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    final start = DateTime(s.year, s.month, s.day);
    final end = DateTime(e.year, e.month, e.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  WorkoutDay? dayFor(String date) {
    for (final d in days) {
      if (d.date == date) return d;
    }
    return null;
  }
}

// ── Nutrition models ────────────────────────────────────────────

class NutritionMeal {
  final String mealType;
  final String name;
  final String? howTo;
  final String? portion;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final List<String> ingredients;
  final String? imageUrl;

  const NutritionMeal({
    required this.mealType,
    required this.name,
    this.howTo,
    this.portion,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.ingredients = const [],
    this.imageUrl,
  });

  factory NutritionMeal.fromJson(Map<String, dynamic> json) {
    return NutritionMeal(
      mealType: json['meal_type']?.toString() ?? 'meal',
      name: json['name']?.toString() ?? 'Meal',
      howTo: json['how_to']?.toString(),
      portion: json['portion']?.toString(),
      calories: (json['calories'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      imageUrl: json['image_url']?.toString(),
    );
  }

  String get mealTypeLabel {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return mealType;
    }
  }

  String get mealEmoji {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return '🌅';
      case 'lunch':
        return '☀️';
      case 'dinner':
        return '🌙';
      case 'snack':
        return '🍎';
      default:
        return '🍽️';
    }
  }

  String get macrosLabel {
    final parts = <String>[];
    if (calories != null) parts.add('${calories!.round()} kcal');
    if (proteinG != null) parts.add('P ${proteinG!.round()}g');
    if (carbsG != null) parts.add('C ${carbsG!.round()}g');
    if (fatG != null) parts.add('F ${fatG!.round()}g');
    return parts.join(' · ');
  }
}

class NutritionDay {
  final String date;
  final String? notes;
  final List<NutritionMeal> meals;

  const NutritionDay({
    required this.date,
    this.notes,
    this.meals = const [],
  });

  factory NutritionDay.fromJson(Map<String, dynamic> json) {
    return NutritionDay(
      date: json['date']?.toString() ?? '',
      notes: json['notes']?.toString(),
      meals: (json['meals'] as List<dynamic>?)
              ?.map((m) =>
                  NutritionMeal.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          const [],
    );
  }

  double get totalCalories =>
      meals.fold(0.0, (s, m) => s + (m.calories ?? 0));
}

class NutritionDaySchedule {
  final String date;
  final int? planId;
  final String? planTitle;
  final String? notes;
  final List<NutritionMeal> meals;

  const NutritionDaySchedule({
    required this.date,
    this.planId,
    this.planTitle,
    this.notes,
    this.meals = const [],
  });

  factory NutritionDaySchedule.fromJson(Map<String, dynamic> json) {
    return NutritionDaySchedule(
      date: json['date']?.toString() ?? '',
      planId: (json['plan_id'] as num?)?.toInt(),
      planTitle: json['plan_title']?.toString(),
      notes: json['notes']?.toString(),
      meals: (json['meals'] as List<dynamic>?)
              ?.map((m) =>
                  NutritionMeal.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          const [],
    );
  }

  bool get hasContent => planId != null || meals.isNotEmpty;

  double get totalCalories =>
      meals.fold(0.0, (s, m) => s + (m.calories ?? 0));
}

class NutritionPlan {
  final int id;
  final int userId;
  final String title;
  final String? goal;
  final String? notes;
  final String startDate;
  final String endDate;
  final int? dailyCaloriesTarget;
  final List<NutritionDay> days;
  final String createdAt;
  final String? updatedAt;

  const NutritionPlan({
    required this.id,
    required this.userId,
    required this.title,
    this.goal,
    this.notes,
    required this.startDate,
    required this.endDate,
    this.dailyCaloriesTarget,
    this.days = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory NutritionPlan.fromJson(Map<String, dynamic> json) {
    return NutritionPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Nutrition Plan',
      goal: json['goal']?.toString(),
      notes: json['notes']?.toString(),
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      dailyCaloriesTarget: (json['daily_calories_target'] as num?)?.toInt(),
      days: (json['days'] as List<dynamic>?)
              ?.map((d) =>
                  NutritionDay.fromJson(Map<String, dynamic>.from(d as Map)))
              .toList() ??
          const [],
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString(),
    );
  }

  int get dayCount => days.length;
  int get totalMeals => days.fold(0, (s, d) => s + d.meals.length);

  String get dateRangeLabel {
    if (startDate.isEmpty) return '';
    if (startDate == endDate) return startDate;
    return '$startDate → $endDate';
  }

  String get preview {
    if (goal != null && goal!.trim().isNotEmpty) return goal!.trim();
    if (dailyCaloriesTarget != null) {
      return '$dailyCaloriesTarget kcal/day · $dayCount days';
    }
    return '$dayCount days · $totalMeals meals';
  }

  bool coversDate(String date) {
    final d = _parseDate(date);
    final s = _parseDate(startDate);
    final e = _parseDate(endDate);
    if (d == null || s == null || e == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    final start = DateTime(s.year, s.month, s.day);
    final end = DateTime(e.year, e.month, e.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

/// Dashboard-friendly snapshot for either plan type.
class TodayPlanSnapshot {
  final PlanKind kind;
  final int? planId;
  final String? planTitle;
  final String? subtitle;
  final int itemCount;
  final bool isRestDay;
  final bool hasPlan;

  const TodayPlanSnapshot({
    required this.kind,
    this.planId,
    this.planTitle,
    this.subtitle,
    this.itemCount = 0,
    this.isRestDay = false,
    this.hasPlan = false,
  });

  String get title =>
      planTitle ?? (kind == PlanKind.workout ? 'Workout Plan' : 'Meal Plan');

  String get preview {
    if (!hasPlan) {
      return kind == PlanKind.workout
          ? 'Build a plan for today'
          : 'Plan meals & macros';
    }
    if (isRestDay) return 'Rest day — recover well';
    if (subtitle != null && subtitle!.isNotEmpty) return subtitle!;
    if (kind == PlanKind.workout) {
      return itemCount == 0
          ? 'View today\'s session'
          : '$itemCount exercises lined up';
    }
    return itemCount == 0
        ? 'View today\'s meals'
        : '$itemCount meals planned';
  }

  factory TodayPlanSnapshot.fromWorkout(WorkoutDaySchedule? day) {
    if (day == null || !day.hasContent) {
      return const TodayPlanSnapshot(kind: PlanKind.workout);
    }
    return TodayPlanSnapshot(
      kind: PlanKind.workout,
      planId: day.planId,
      planTitle: day.planTitle,
      subtitle: day.focus ??
          (day.isRestDay ? 'Rest day' : null),
      itemCount: day.exercises.length,
      isRestDay: day.isRestDay,
      hasPlan: true,
    );
  }

  factory TodayPlanSnapshot.fromNutrition(NutritionDaySchedule? day) {
    if (day == null || !day.hasContent) {
      return const TodayPlanSnapshot(kind: PlanKind.nutrition);
    }
    final kcal = day.totalCalories;
    return TodayPlanSnapshot(
      kind: PlanKind.nutrition,
      planId: day.planId,
      planTitle: day.planTitle,
      subtitle: kcal > 0
          ? '${kcal.round()} kcal across ${day.meals.length} meals'
          : null,
      itemCount: day.meals.length,
      hasPlan: true,
    );
  }
}

String todayDateString() => _dateOnly(DateTime.now());
