import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/trip_checklist_item_model.dart';
import '../models/trip_plan_model.dart';
import 'auth_service.dart';
import 'trip_history_service.dart';


/// Comprehensive local-first, plan-aware Trip Checklist & Notes repository.
/// 
/// Stores checklist items in SQLite with foreign plan association, day groupings,
/// smart origin tags, and reactive cross-screen state broadcast.
class TripChecklistService {
  static const String _dbName = 'bon_voyage_checklists.db';
  static const String _tableName = 'trip_checklists';
  static Database? _database;

  // Reactive state manager for live cross-screen synchronization
  static final StreamController<List<TripChecklistItem>> _streamController =
      StreamController<List<TripChecklistItem>>.broadcast();
  static Stream<List<TripChecklistItem>> get checklistStream =>
      _streamController.stream;

  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _dbName);

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            plan_id TEXT NOT NULL,
            user_id INTEGER,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            custom_tag TEXT,
            reference_id TEXT,
            day_number INTEGER,
            day_title TEXT,
            is_completed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_checklist_plan_id ON $_tableName(plan_id);',
        );
      },
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN custom_tag TEXT;');
        } catch (_) {
          // Column already exists or table freshly created
        }
      },
    );
  }

  /// Get the active finalized plan ID if one exists.
  static Future<String?> getActivePlanId({int? userId}) async {
    final plan = await TripHistoryService.getLatestFinalizedPlan(userId: userId);
    return plan?.id;
  }

  /// Load active checklist for the user's latest finalized trip plan.
  static Future<List<TripChecklistItem>> getActiveChecklist({int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final latestPlan = await TripHistoryService.getLatestFinalizedPlan(userId: currentUserId);

      if (latestPlan == null) {
        pendingCountNotifier.value = 0;
        _streamController.add([]);
        return [];
      }

      final db = await database;
      final rows = await db.query(
        _tableName,
        where: 'plan_id = ?',
        whereArgs: [latestPlan.id],
      );

      // If no checklist exists yet for this plan, auto-initialize from plan itinerary
      if (rows.isEmpty) {
        return await initializeChecklistForPlan(latestPlan, userId: currentUserId);
      }

      final items = rows.map((r) => TripChecklistItem.fromMap(r)).toList();
      _sortItems(items);

      final pending = items.where((i) => !i.isCompleted).length;
      pendingCountNotifier.value = pending;
      _streamController.add(items);

      return items;
    } catch (e) {
      debugPrint('Error getting active checklist: $e');
      return [];
    }
  }

  /// Initializes day-by-day checklist items from a newly finalized TripPlan.
  static Future<List<TripChecklistItem>> initializeChecklistForPlan(
    TripPlan plan, {
    int? userId,
  }) async {
    try {
      final db = await database;
      final currentUserId = userId ?? plan.userId ?? await AuthService.getUserId();

      // Check if already initialized to prevent duplicate initialization
      final existingRows = await db.query(
        _tableName,
        where: 'plan_id = ?',
        whereArgs: [plan.id],
      );

      if (existingRows.isNotEmpty) {
        final existing = existingRows.map((r) => TripChecklistItem.fromMap(r)).toList();
        _sortItems(existing);
        final pending = existing.where((i) => !i.isCompleted).length;
        pendingCountNotifier.value = pending;
        _streamController.add(existing);
        return existing;
      }

      final itemsToInsert = <TripChecklistItem>[];
      final now = DateTime.now();

      // 1. Generate items strictly from itinerary days
      for (final day in plan.daysPlan) {
        final dayNum = day.dayNumber;
        final dayTitle = _cleanHtml(day.title.isNotEmpty ? day.title : 'Day $dayNum');

        // Activities & Attractions (Places to Visit)
        for (final act in day.activities) {
          final cleanAct = _cleanHtml(act);
          if (cleanAct.isNotEmpty) {
            itemsToInsert.add(TripChecklistItem(
              id: 'CHK-${now.millisecondsSinceEpoch}-${itemsToInsert.length}',
              planId: plan.id,
              title: cleanAct,
              category: ChecklistCategory.placesToVisit,
              customTag: 'Places to Visit',
              dayNumber: dayNum,
              dayTitle: dayTitle,
              isCompleted: false,
              createdAt: now,
              updatedAt: now,
            ));
          }
        }

        // Stays / Hotels recommended in the plan
        final cleanStay = _cleanHtml(day.stayRecommendation);
        if (cleanStay.isNotEmpty &&
            !cleanStay.toLowerCase().contains('none') &&
            !cleanStay.toLowerCase().contains('n/a')) {
          itemsToInsert.add(TripChecklistItem(
            id: 'CHK-${now.millisecondsSinceEpoch}-${itemsToInsert.length}',
            planId: plan.id,
            title: cleanStay,
            category: ChecklistCategory.hotel,
            customTag: 'Hotel',
            dayNumber: dayNum,
            dayTitle: dayTitle,
            isCompleted: false,
            createdAt: now,
            updatedAt: now,
          ));
        }

        // Food recommendations in the plan
        final cleanFood = _cleanHtml(day.foodRecommendation);
        if (cleanFood.isNotEmpty &&
            !cleanFood.toLowerCase().contains('none') &&
            !cleanFood.toLowerCase().contains('n/a')) {
          itemsToInsert.add(TripChecklistItem(
            id: 'CHK-${now.millisecondsSinceEpoch}-${itemsToInsert.length}',
            planId: plan.id,
            title: cleanFood,
            category: ChecklistCategory.food,
            customTag: 'Food',
            dayNumber: dayNum,
            dayTitle: dayTitle,
            isCompleted: false,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      // Batch insert into SQLite

      final batch = db.batch();
      for (final item in itemsToInsert) {
        final map = item.toMap();
        map['user_id'] = currentUserId;
        batch.insert(_tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      _sortItems(itemsToInsert);
      final pending = itemsToInsert.where((i) => !i.isCompleted).length;
      pendingCountNotifier.value = pending;
      _streamController.add(itemsToInsert);

      debugPrint('Initialized checklist for plan ${plan.id} with ${itemsToInsert.length} items.');
      return itemsToInsert;
    } catch (e) {
      debugPrint('Error initializing checklist: $e');
      return [];
    }
  }

  /// Add a manual task or specific item to the active trip checklist.
  static Future<TripChecklistItem?> addItem({
    required String title,
    ChecklistCategory? category,
    String? customTag,
    int? dayNumber,
    String? dayTitle,
    String? referenceId,
    String? explicitPlanId,
  }) async {
    try {
      final currentUserId = await AuthService.getUserId();
      final planId = explicitPlanId ?? await getActivePlanId(userId: currentUserId);

      if (planId == null) {
        debugPrint('Cannot add checklist item: No active finalized trip plan.');
        return null;
      }

      final db = await database;

      final effectiveTag = customTag ?? TripChecklistItem.inferTagFromContent(title);
      ChecklistCategory effectiveCategory = category ?? ChecklistCategory.task;
      if (category == null) {
        final lower = effectiveTag.toLowerCase();
        if (lower.contains('place') || lower.contains('visit')) {
          effectiveCategory = ChecklistCategory.placesToVisit;
        } else if (lower.contains('hotel') || lower.contains('stay')) {
          effectiveCategory = ChecklistCategory.hotel;
        } else if (lower.contains('food') || lower.contains('dining')) {
          effectiveCategory = ChecklistCategory.food;
        }
      }

      // Duplicate check: prevent duplicate reference or title for same category & plan
      final existing = await db.query(
        _tableName,
        where: 'plan_id = ? AND category = ? AND (reference_id = ? OR title = ?)',
        whereArgs: [planId, effectiveCategory.name, referenceId ?? '', title.trim()],
      );

      if (existing.isNotEmpty) {
        debugPrint('Item already exists in checklist: $title');
        return TripChecklistItem.fromMap(existing.first);
      }

      final now = DateTime.now();
      final newItem = TripChecklistItem(
        id: 'CHK-${now.millisecondsSinceEpoch}-${now.microsecond}',
        planId: planId,
        title: title.trim(),
        category: effectiveCategory,
        customTag: effectiveTag,
        referenceId: referenceId,
        dayNumber: dayNumber,
        dayTitle: dayTitle,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = newItem.toMap();
      map['user_id'] = currentUserId;

      await db.insert(_tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);

      // Trigger reactive refresh
      await getActiveChecklist(userId: currentUserId);
      return newItem;
    } catch (e) {
      debugPrint('Error adding checklist item: $e');
      return null;
    }
  }

  /// Toggle item completed status and persist to SQLite.
  static Future<bool> toggleCompleted(String itemId) async {
    try {
      final db = await database;
      final rows = await db.query(_tableName, where: 'id = ?', whereArgs: [itemId]);
      if (rows.isEmpty) return false;

      final current = TripChecklistItem.fromMap(rows.first);
      final newStatus = !current.isCompleted;
      final now = DateTime.now().toIso8601String();

      await db.update(
        _tableName,
        {'is_completed': newStatus ? 1 : 0, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [itemId],
      );

      final currentUserId = await AuthService.getUserId();
      await getActiveChecklist(userId: currentUserId);
      return true;
    } catch (e) {
      debugPrint('Error toggling checklist item: $e');
      return false;
    }
  }

  /// Remove item from checklist.
  static Future<bool> removeItem(String itemId) async {
    try {
      final db = await database;
      await db.delete(_tableName, where: 'id = ?', whereArgs: [itemId]);

      final currentUserId = await AuthService.getUserId();
      await getActiveChecklist(userId: currentUserId);
      return true;
    } catch (e) {
      debugPrint('Error removing checklist item: $e');
      return false;
    }
  }

  /// Move item to a different itinerary day or General.
  static Future<bool> moveItemToDay(String itemId, int? newDayNumber, {String? newDayTitle}) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      await db.update(
        _tableName,
        {
          'day_number': newDayNumber,
          'day_title': newDayTitle ?? (newDayNumber != null ? 'Day $newDayNumber' : 'General / Trip-wide'),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );

      final currentUserId = await AuthService.getUserId();
      await getActiveChecklist(userId: currentUserId);
      return true;
    } catch (e) {
      debugPrint('Error moving checklist item: $e');
      return false;
    }
  }

  /// Internal sorting: Day 1..N, then General/Trip-wide (null), then by creation date.
  /// Items stay in their exact position without moving to the bottom when completed.
  static void _sortItems(List<TripChecklistItem> items) {
    items.sort((a, b) {
      if (a.dayNumber == null && b.dayNumber != null) return 1;
      if (a.dayNumber != null && b.dayNumber == null) return -1;
      if (a.dayNumber != null && b.dayNumber != null) {
        final dayComp = a.dayNumber!.compareTo(b.dayNumber!);
        if (dayComp != 0) return dayComp;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
  }


  /// Clean and strip raw HTML tags and entities from strings
  static String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}



