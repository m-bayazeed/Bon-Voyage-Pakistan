import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../config/api_config.dart';
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
        confidenceScore: 0.0,
        shortDescription: 'Analyzing image with AI...',
        historicalStory: '',
        keyFacts: const [],
        recommendedActivities: const [],
        bestTimeToVisit: 'All year round',
        timestamp: DateTime.now(),
        scanType: scanType,
        imagePath: permanentPath ?? rawImagePath,
        searchStatus: 'Pending',
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

  /// Discovers the active running backend endpoint (FastAPI on Port 8000 or Flask on Port 5000)
  /// using a fast 1.5-second parallel health check across candidate hosts.
  static Future<String> _resolveActiveScanEndpoint() async {
    final candidateBases = <String>[];
    for (final host in ApiConfig.candidateHosts) {
      final h = host.trim();
      if (h.isNotEmpty) {
        if (!candidateBases.contains('http://$h:8000')) candidateBases.add('http://$h:8000');
        if (!candidateBases.contains('http://$h:5000')) candidateBases.add('http://$h:5000');
      }
    }

    // Fast parallel probe on /health (1500ms max)
    final probeFutures = candidateBases.map((base) async {
      try {
        final res = await http.get(Uri.parse('$base/health')).timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) {
          return '$base/api/v1/landmarks/scan';
        }
      } catch (_) {}
      return null;
    }).toList();

    final results = await Future.wait(probeFutures);
    for (final r in results) {
      if (r != null) {
        debugPrint('[SCAN] Active backend endpoint discovered: $r');
        return r;
      }
    }

    debugPrint('[SCAN] Using configured default endpoint: ${ApiConfig.landmarksScan}');
    return ApiConfig.landmarksScan;
  }

  /// AI Landmark Recognition using Gemini Multimodal Vision through FastAPI backend.
  static Future<ScanItem> simulateAiRecognition({
    required bool isUpload,
    String? imagePath,
    ScanItem? existingItem,
    int? userId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // 1. Copy image file to permanent app directory if provided and not already saved
      String? permanentImagePath = imagePath;
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          (existingItem?.imagePath == null || !existingItem!.imagePath!.contains('scans'))) {
        permanentImagePath = await saveImagePermanently(imagePath);
      }

      final activePath = permanentImagePath ?? imagePath ?? existingItem?.imagePath;
      if (activePath == null || !await File(activePath).exists()) {
        throw Exception('Image file not found on disk at $activePath');
      }

      final currentUserId = userId ?? existingItem?.userId ?? await AuthService.getUserId();
      final endpoint = await _resolveActiveScanEndpoint();
      final file = File(activePath);
      final fileSizeKb = (await file.length()) / 1024.0;

      debugPrint('[SCAN] Source: ${isUpload ? 'GALLERY' : 'CAMERA'}');
      debugPrint('[SCAN] Endpoint: $endpoint');
      debugPrint('[SCAN] Image filename: ${p.basename(activePath)}');
      debugPrint('[SCAN] Image size: ${fileSizeKb.toStringAsFixed(1)} KB');
      debugPrint('[SCAN] Uploading image to FastAPI Gemini backend...');

      Map<String, dynamic>? responseData;
      String lastError = '';

      // 2. Call FastAPI backend with a generous 120s timeout for Gemini Multimodal Vision
      try {
        final request = http.MultipartRequest('POST', Uri.parse(endpoint));
        request.files.add(await http.MultipartFile.fromPath('image', activePath));
        if (latitude != null) request.fields['latitude'] = latitude.toString();
        if (longitude != null) request.fields['longitude'] = longitude.toString();

        final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
        final response = await http.Response.fromStream(streamedResponse);

        debugPrint('[SCAN] Backend response HTTP status: ${response.statusCode}');
        if (response.statusCode == 200) {
          responseData = jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          try {
            final errJson = jsonDecode(response.body) as Map<String, dynamic>;
            lastError = errJson['error'] ?? errJson['detail'] ?? 'HTTP ${response.statusCode}';
          } catch (_) {
            lastError = 'HTTP ${response.statusCode} from server';
          }
          debugPrint('[SCAN] Backend returned error: $lastError');
        }
      } catch (e) {
        debugPrint('[SCAN] Network request error: $e');
        lastError = e.toString();
      }

      // 3. Process Real Response
      if (responseData != null && responseData['success'] == true) {
        final isIdentified = responseData['identified'] == true;
        final confidence = (responseData['confidence'] as num?)?.toDouble() ?? (isIdentified ? 0.95 : 0.0);

        List<String> parseList(dynamic val) {
          if (val == null) return [];
          if (val is List) return val.map((e) => e.toString()).toList();
          if (val is String) {
            try {
              final d = jsonDecode(val);
              if (d is List) return d.map((e) => e.toString()).toList();
            } catch (_) {}
          }
          return [];
        }

        final facts = parseList(responseData['interesting_facts']);
        final events = parseList(responseData['historical_events']);
        final thingsToDo = parseList(responseData['things_to_do']);
        final archSignificance = responseData['architectural_significance']?.toString();
        final travelTip = responseData['travel_tip']?.toString();
        final historyOverview = responseData['history_overview']?.toString() ?? '';
        final landmarkName = responseData['landmark_name']?.toString();

        // Combine architectural significance, facts, and historical milestones under keyFacts
        final combinedFacts = <String>[...facts];
        if (archSignificance != null && archSignificance.isNotEmpty && !combinedFacts.contains(archSignificance)) {
          combinedFacts.insert(0, archSignificance);
        }
        for (final ev in events) {
          if (ev.isNotEmpty && !combinedFacts.contains(ev)) {
            combinedFacts.add(ev);
          }
        }

        // Actionable visitor activities for "Top Things to Do" (NEVER historical events)
        List<String> activities = [];
        if (thingsToDo.isNotEmpty) {
          activities = thingsToDo;
        } else if (isIdentified && landmarkName != null && landmarkName.isNotEmpty) {
          final loc = responseData['city_or_region']?.toString() ?? 'the area';
          activities = [
            'Explore the iconic architecture, courtyards, and grounds of $landmarkName.',
            'Capture panoramic photos during early morning or sunset golden hour.',
            'Discover the heritage exhibits and cultural displays on site.',
            'Sample traditional regional delicacies and tea at local eateries in $loc.',
          ];
          if (travelTip != null && travelTip.isNotEmpty && !travelTip.toLowerCase().contains('year round')) {
            activities.add(travelTip);
          }
        }

        debugPrint('[SCAN] Result: identified=$isIdentified, landmark=$landmarkName, confidence=$confidence');

        final item = ScanItem(
          id: existingItem?.id ?? 'SCAN-RECOG-${DateTime.now().millisecondsSinceEpoch}',
          userId: currentUserId,
          title: landmarkName ?? (isIdentified ? 'Pakistani Landmark' : 'Unidentified Landmark'),
          identifiedLocation: landmarkName,
          location: responseData['city_or_region']?.toString() ?? 'Pakistan',
          category: responseData['historical_era']?.toString() ??
              (isIdentified ? 'Pakistani Heritage Site' : 'Unidentified'),
          confidenceScore: confidence,
          shortDescription: historyOverview.isNotEmpty
              ? historyOverview
              : (responseData['message']?.toString() ?? ''),
          historicalStory: historyOverview,
          keyFacts: combinedFacts,
          recommendedActivities: activities,
          bestTimeToVisit: travelTip ?? 'All year round',
          timestamp: DateTime.now(),
          scanType: isUpload ? ScanType.upload : ScanType.camera,
          imagePath: activePath,
          searchStatus: isIdentified ? 'Identified' : 'Not Identified',
          imagePlaceholderAsset: 'assets/images/onboarding1.png',
        );

        await saveScanItem(item);
        return item;
      }

      // 4. In case of failure or network error, surface actual failure state without fake recognition
      final errorMsg = lastError.isNotEmpty
          ? 'Recognition unavailable ($lastError)'
          : (responseData?['message']?.toString() ?? 'The landmark could not be identified reliably.');

      debugPrint('[SCAN] Failed to identify: $errorMsg');

      final fallbackItem = ScanItem(
        id: existingItem?.id ?? 'SCAN-RECOG-${DateTime.now().millisecondsSinceEpoch}',
        userId: currentUserId,
        title: 'Unidentified Landmark',
        identifiedLocation: null,
        location: 'Pakistan',
        category: 'Unidentified',
        confidenceScore: 0.0,
        shortDescription: errorMsg,
        historicalStory: '',
        keyFacts: const [],
        recommendedActivities: const [],
        bestTimeToVisit: 'All year round',
        timestamp: DateTime.now(),
        scanType: isUpload ? ScanType.upload : ScanType.camera,
        imagePath: activePath,
        searchStatus: 'Error',
        imagePlaceholderAsset: 'assets/images/onboarding1.png',
      );

      await saveScanItem(fallbackItem);
      return fallbackItem;
    } catch (e, stackTrace) {
      debugPrint('[SCAN] AI RECOGNITION ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // ────────────────────────────────────────────
  // AI AUDIO STORY (GROQ / NEURAL TTS)
  // ────────────────────────────────────────────
  static final Map<String, String> _audioCache = {};

  /// Synthesizes and caches an AI audio story from the backend using Groq / Neural TTS.
  static Future<String?> fetchStoryAudio({
    required String storyText,
    required String itemId,
    String language = 'en',
  }) async {
    // 1. Check in-memory session cache
    if (_audioCache.containsKey(itemId)) {
      final cachedPath = _audioCache[itemId]!;
      if (File(cachedPath).existsSync() && File(cachedPath).lengthSync() > 0) {
        debugPrint('[TTS] Reusing cached audio for $itemId at $cachedPath');
        return cachedPath;
      }
    }

    try {
      final scanEndpoint = await _resolveActiveScanEndpoint();
      final uri = Uri.parse(scanEndpoint);
      final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';
      final ttsUrl = '$baseUrl/api/v1/tts/story';

      debugPrint('[TTS] Requesting story audio from $ttsUrl');
      final response = await http.post(
        Uri.parse(ttsUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': storyText,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('[TTS] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final b64 = data['audio_base64']?.toString();
        if (b64 != null && b64.isNotEmpty) {
          final bytes = base64Decode(b64);
          final tempDir = await getTemporaryDirectory();
          final safeName = 'story_${itemId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.mp3';
          final audioFile = File(p.join(tempDir.path, safeName));
          await audioFile.writeAsBytes(bytes);
          _audioCache[itemId] = audioFile.path;
          debugPrint('[TTS] Saved audio story (${bytes.length} bytes) to ${audioFile.path}');
          return audioFile.path;
        }
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('[TTS] Story audio generation error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
