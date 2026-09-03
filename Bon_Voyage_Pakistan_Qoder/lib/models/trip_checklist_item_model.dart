import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Categories of trip checklist items.
enum ChecklistCategory {
  task,
  hotel,
  food,
  plan,
}

extension ChecklistCategoryExtension on ChecklistCategory {
  String get displayName {
    switch (this) {
      case ChecklistCategory.task:
        return 'Task & Note';
      case ChecklistCategory.hotel:
        return 'Hotel & Stay';
      case ChecklistCategory.food:
        return 'Food & Dining';
      case ChecklistCategory.plan:
        return 'Plan Activity';
    }
  }

  String get originTag {
    switch (this) {
      case ChecklistCategory.task:
        return '[🏷 Task]';
      case ChecklistCategory.hotel:
        return '[🏨 Hotel]';
      case ChecklistCategory.food:
        return '[🍲 Food]';
      case ChecklistCategory.plan:
        return '[📌 Plan]';
    }
  }

  IconData get icon {
    switch (this) {
      case ChecklistCategory.task:
        return Icons.task_alt_rounded;
      case ChecklistCategory.hotel:
        return Icons.hotel_rounded;
      case ChecklistCategory.food:
        return Icons.restaurant_rounded;
      case ChecklistCategory.plan:
        return Icons.place_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ChecklistCategory.task:
        return const Color(0xFF5A7328);
      case ChecklistCategory.hotel:
        return const Color(0xFF0288D1);
      case ChecklistCategory.food:
        return const Color(0xFFE65100);
      case ChecklistCategory.plan:
        return const Color(0xFF7B1FA2);
    }
  }
}

/// Represents an individual item in the user's plan-aware trip checklist.
class TripChecklistItem {
  final String id;
  final String planId;
  final String title;
  final ChecklistCategory category;
  final String? referenceId;
  final int? dayNumber; // 1-based day index (1 = Day 1), null = General / Trip-wide
  final String? dayTitle; // e.g. "Islamabad ➔ Naran"
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripChecklistItem({
    required this.id,
    required this.planId,
    required this.title,
    required this.category,
    this.referenceId,
    this.dayNumber,
    this.dayTitle,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get originTag => category.originTag;
  IconData get originIcon => category.icon;
  Color get originColor => category.color;

  TripChecklistItem copyWith({
    String? id,
    String? planId,
    String? title,
    ChecklistCategory? category,
    String? referenceId,
    int? dayNumber,
    String? dayTitle,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripChecklistItem(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      title: title ?? this.title,
      category: category ?? this.category,
      referenceId: referenceId ?? this.referenceId,
      dayNumber: dayNumber ?? this.dayNumber,
      dayTitle: dayTitle ?? this.dayTitle,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_id': planId,
      'title': title,
      'category': category.name,
      'reference_id': referenceId,
      'day_number': dayNumber,
      'day_title': dayTitle,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TripChecklistItem.fromMap(Map<String, dynamic> map) {
    return TripChecklistItem(
      id: map['id'] as String,
      planId: map['plan_id'] as String,
      title: map['title'] as String,
      category: _parseCategory(map['category'] as String?),
      referenceId: map['reference_id'] as String?,
      dayNumber: map['day_number'] as int?,
      dayTitle: map['day_title'] as String?,
      isCompleted: (map['is_completed'] == 1 || map['is_completed'] == true),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory TripChecklistItem.fromJson(Map<String, dynamic> json) =>
      TripChecklistItem.fromMap(json);

  static ChecklistCategory _parseCategory(String? raw) {
    if (raw == null) return ChecklistCategory.task;
    return ChecklistCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == raw.toLowerCase(),
      orElse: () => ChecklistCategory.task,
    );
  }
}
