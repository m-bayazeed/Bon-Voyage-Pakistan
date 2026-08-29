import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/scan_item_model.dart';
import 'auth_service.dart';

/// Service to handle persistent SQLite storage, local image persistence,
/// and AI recognition for Scan n Search landmarks with user ownership.
class ScanHistoryService {
  static const String _dbName = 'bon_voyage_scans.db';
  static const String _tableName = 'scan_history';
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docsDir.path, _dbName);

      return await openDatabase(
        dbPath,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_tableName (
              id TEXT PRIMARY KEY,
              userId INTEGER,
              title TEXT,
              identifiedLocation TEXT,
              location TEXT,
              category TEXT,
              confidenceScore REAL,
              shortDescription TEXT,
              historicalStory TEXT,
              keyFacts TEXT,
              recommendedActivities TEXT,
              bestTimeToVisit TEXT,
              timestamp TEXT,
              scanType TEXT,
              imagePath TEXT,
              searchStatus TEXT,
              imagePlaceholderAsset TEXT,
              isFavorite INTEGER
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            try {
              await db.execute('ALTER TABLE $_tableName ADD COLUMN userId INTEGER;');
            } catch (_) {}
          }
        },
      );
    } catch (e, stackTrace) {
      debugPrint('DATABASE INIT ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Copies a temporary camera/gallery image file to permanent app storage.
  static Future<String?> saveImagePermanently(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('IMAGE SAVE WARNING: Source file does not exist at $sourcePath');
        return null;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory(p.join(docsDir.path, 'scans'));
      if (!await scansDir.exists()) {
        await scansDir.create(recursive: true);
      }

      final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}$ext';
      final targetPath = p.join(scansDir.path, fileName);

      final savedFile = await sourceFile.copy(targetPath);
      debugPrint('IMAGE SAVED PERMANENTLY: ${savedFile.path}');
      return savedFile.path;
    } catch (e, stackTrace) {
      debugPrint('IMAGE PERSISTENCE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      return sourcePath;
    }
  }

  /// Retrieve saved scan history for the currently authenticated user.
  static Future<List<ScanItem>> getScanHistory({int? userId}) async {
    try {
      final db = await database;
      final currentUserId = userId ?? await AuthService.getUserId();

      List<Map<String, dynamic>> maps;
      if (currentUserId != null) {
        maps = await db.query(
          _tableName,
          where: 'userId = ?',
          whereArgs: [currentUserId],
          orderBy: 'timestamp DESC',
        );
      } else {
        maps = await db.query(
          _tableName,
          where: 'userId IS NULL',
          orderBy: 'timestamp DESC',
        );
      }

      return maps.map((e) => ScanItem.fromMap(e)).toList();
    } catch (e, stackTrace) {
      debugPrint('HISTORY FETCH ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      return [];
    }
  }

  /// Create and save a new scan record bound to the current user immediately upon image acquisition.
  static Future<ScanItem> createAndSaveScan({
    required String rawImagePath,
    required ScanType scanType,
    String? title,
    String? identifiedLocation,
    String? location,
    String? category,
    int? userId,
  }) async {
    try {
      // 1. Copy image to permanent directory
      final permanentPath = await saveImagePermanently(rawImagePath);
      final currentUserId = userId ?? await AuthService.getUserId();

      final uniqueId = 'SCAN-${DateTime.now().millisecondsSinceEpoch}';
      final item = ScanItem(
        id: uniqueId,
        userId: currentUserId,
        title: title ?? (scanType == ScanType.camera ? 'Camera Discovery' : 'Gallery Upload'),
        identifiedLocation: identifiedLocation,
        location: location ?? 'Pakistan',
        category: category ?? 'Landmark Scan',
        confidenceScore: 0.95,
        shortDescription: 'Saved image discovery awaiting detailed AI analysis.',
        historicalStory: '',
        keyFacts: const [],
        recommendedActivities: const [],
        bestTimeToVisit: 'All year round',
        timestamp: DateTime.now(),
        scanType: scanType,
        imagePath: permanentPath ?? rawImagePath,
        searchStatus: 'Saved',
        imagePlaceholderAsset: 'assets/images/onboarding1.png',
        isFavorite: false,
      );

      await saveScanItem(item);
      return item;
    } catch (e, stackTrace) {
      debugPrint('HISTORY SAVE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Save a scan item to SQLite history bound to the current user.
  static Future<void> saveScanItem(ScanItem item) async {
    try {
      final db = await database;
      final currentUserId = item.userId ?? await AuthService.getUserId();
      final itemToSave = item.userId != null ? item : item.copyWith(userId: currentUserId);

      await db.insert(
        _tableName,
        itemToSave.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('HISTORY SAVED: ${itemToSave.id} for user ${itemToSave.userId}');
    } catch (e, stackTrace) {
      debugPrint('HISTORY SAVE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Delete a scan item by ID from SQLite for the current user.
  static Future<void> deleteScanItem(String id, {int? userId}) async {
    try {
      final db = await database;
      final currentUserId = userId ?? await AuthService.getUserId();
      if (currentUserId != null) {
        await db.delete(
          _tableName,
          where: 'id = ? AND userId = ?',
          whereArgs: [id, currentUserId],
        );
      } else {
        await db.delete(
          _tableName,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      debugPrint('HISTORY DELETED: $id');
    } catch (e, stackTrace) {
      debugPrint('HISTORY DELETE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Toggle favorite status of a scan item in SQLite for the current user.
  static Future<void> toggleFavorite(String id, {int? userId}) async {
    try {
      final db = await database;
      final currentUserId = userId ?? await AuthService.getUserId();
      List<Map<String, dynamic>> maps;
      if (currentUserId != null) {
        maps = await db.query(
          _tableName,
          where: 'id = ? AND userId = ?',
          whereArgs: [id, currentUserId],
          limit: 1,
        );
      } else {
        maps = await db.query(
          _tableName,
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
      }

      if (maps.isNotEmpty) {
        final currentFav = maps.first['isFavorite'] == 1;
        await db.update(
          _tableName,
          {'isFavorite': currentFav ? 0 : 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        debugPrint('HISTORY FAVORITE TOGGLED: $id -> ${!currentFav}');
      }
    } catch (e, stackTrace) {
      debugPrint('HISTORY FAVORITE TOGGLE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Clear scan history for the current user from SQLite.
  static Future<void> clearHistory({int? userId}) async {
    try {
      final db = await database;
      final currentUserId = userId ?? await AuthService.getUserId();
      if (currentUserId != null) {
        await db.delete(
          _tableName,
          where: 'userId = ?',
          whereArgs: [currentUserId],
        );
        debugPrint('HISTORY CLEARED FOR USER $currentUserId');
      } else {
        await db.delete(_tableName);
        debugPrint('HISTORY CLEARED');
      }
    } catch (e, stackTrace) {
      debugPrint('HISTORY CLEAR ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// AI Recognition of a landmark with permanent image persistence and user association.
  static Future<ScanItem> simulateAiRecognition({
    required bool isUpload,
    String? imagePath,
    ScanItem? existingItem,
    int? userId,
  }) async {
    try {
      // 1. Copy image file to permanent app directory if provided and not already saved
      String? permanentImagePath = imagePath;
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          (existingItem?.imagePath == null || !existingItem!.imagePath!.contains('scans'))) {
        permanentImagePath = await saveImagePermanently(imagePath);
      }

      final currentUserId = userId ?? existingItem?.userId ?? await AuthService.getUserId();

      // 2. Realistic neural network extraction delay
      await Future.delayed(const Duration(milliseconds: 1200));

      final possibleDiscoveries = [
        ScanItem(
          id: existingItem?.id ?? 'SCAN-RECOG-${DateTime.now().millisecondsSinceEpoch}',
          userId: currentUserId,
          title: 'Passu Cones (Cathedral Ridge)',
          identifiedLocation: 'Passu Cones, Upper Hunza',
          location: 'Upper Hunza, Gilgit-Baltistan',
          category: 'Geological Wonder & Karakoram Peaks',
          confidenceScore: 0.985,
          shortDescription:
              'Iconic serrated crown-shaped peaks rising sharply above the Karakoram Highway and Hunza River.',
          historicalStory:
              'Known locally as Tupopdan ("Sun-Drenched Peak"), the Passu Cones rise to an elevation of 6,106 m (20,033 ft). Their dramatic pointed needle spires are among the most photographed natural formations on the Ancient Silk Road.',
          keyFacts: const [
            'Peak Altitude: 6,106 meters (20,033 ft)',
            'Valley: Gojal, Upper Hunza',
            'Nearby Attractions: Hussaini Suspension Bridge & Borith Lake',
          ],
          recommendedActivities: const [
            'Photograph golden morning light kissing the sharp cones',
            'Cross the thrilling Hussaini Hanging Bridge nearby',
            'Trek toward the white tongues of Passu Glacier',
          ],
          bestTimeToVisit: 'April - October (Morning Golden Hour)',
          timestamp: DateTime.now(),
          scanType: isUpload ? ScanType.upload : ScanType.camera,
          imagePath: permanentImagePath ?? existingItem?.imagePath,
          searchStatus: 'Identified',
          imagePlaceholderAsset: 'assets/images/onboarding1.png',
        ),
        ScanItem(
          id: existingItem?.id ?? 'SCAN-RECOG-${DateTime.now().millisecondsSinceEpoch}',
          userId: currentUserId,
          title: 'Derawar Fort',
          identifiedLocation: 'Derawar Fort, Cholistan Desert',
          location: 'Cholistan Desert, Bahawalpur, Punjab',
          category: 'Ancient Desert Fortress',
          confidenceScore: 0.978,
          shortDescription:
              'Gigantic 9th-century square fortress with 40 towering bastions rising majestically in the Cholistan sands.',
          historicalStory:
              'Derawar Fort was originally built in the 9th century by the Rajput ruler Rai Jajja Bhatti and later rebuilt in 1732 by the Nawabs of Bahawalpur. Its 40 monumental cylindrical bastions rise 30 meters high, dominating the desert horizon for miles.',
          keyFacts: const [
            'Bastions: 40 massive rounded brick bastions',
            'Circumference: 1,500 meters of towering mud-brick walls',
            'Location: Heart of Cholistan Desert near Abbasi Royal Tombs',
          ],
          recommendedActivities: const [
            'Attend the annual Cholistan Jeep Desert Rally in winter',
            'Visit the nearby marble Abbasi Royal Tombs and Shahi Mosque',
            'Experience desert sunset photography against the bastions',
          ],
          bestTimeToVisit: 'November to February for pleasant desert climate',
          timestamp: DateTime.now(),
          scanType: isUpload ? ScanType.upload : ScanType.camera,
          imagePath: permanentImagePath ?? existingItem?.imagePath,
          searchStatus: 'Identified',
          imagePlaceholderAsset: 'assets/images/onboarding2.png',
        ),
        ScanItem(
          id: existingItem?.id ?? 'SCAN-RECOG-${DateTime.now().millisecondsSinceEpoch}',
          userId: currentUserId,
          title: 'Katas Raj Temples',
          identifiedLocation: 'Katas Raj Temples, Chakwal',
          location: 'Potohar Plateau, Chakwal, Punjab',
          category: 'Ancient Sacred Heritage Complex',
          confidenceScore: 0.982,
          shortDescription:
              'Sacred temple complex surrounding a mystical spring pond, rooted in millennia of ancient folklore.',
          historicalStory:
              'According to Hindu mythology, the pond of Katas was formed from the tears of Lord Shiva. The complex features shrines dating from the 6th to 11th centuries CE alongside Buddhist stupa remains and medieval Havelis, showcasing Pakistan’s deep interfaith heritage.',
          keyFacts: const [
            'Origins: Shrines spanning 6th – 11th Century CE (Kashmirian Architecture)',
            'Significance: One of the holiest pilgrimage sites in the subcontinent',
            'Site: Features the famous Ramachandra, Hanuman, and Shiva temples',
          ],
          recommendedActivities: const [
            'Explore ancient temple carvings and subterranean walkways',
            'Reflect beside the sacred natural pond',
            'Visit the nearby ancient Khewra Salt Mines',
          ],
          bestTimeToVisit: 'September to March',
          timestamp: DateTime.now(),
          scanType: isUpload ? ScanType.upload : ScanType.camera,
          imagePath: permanentImagePath ?? existingItem?.imagePath,
          searchStatus: 'Identified',
          imagePlaceholderAsset: 'assets/images/onboarding1.png',
        ),
      ];

      // Pick a discovery and save to SQLite history
      final chosen = possibleDiscoveries[DateTime.now().second % possibleDiscoveries.length];
      await saveScanItem(chosen);
      return chosen;
    } catch (e, stackTrace) {
      debugPrint('AI RECOGNITION ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
