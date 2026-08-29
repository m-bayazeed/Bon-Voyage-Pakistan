import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/translation_model.dart';
import 'auth_service.dart';

/// Manages local persistence of user translation history and favorites per user.
class TranslationHistoryService {
  static String _storageKeyFor(int? userId) {
    if (userId != null) {
      return 'bvp_translation_history_user_$userId';
    }
    return 'bvp_translation_history_guest';
  }

  /// Save a new translation to history for the current user.
  static Future<bool> saveTranslation(TranslationItem item, {int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyFor(currentUserId);
      final history = await getHistory(userId: currentUserId);

      // Avoid duplicates with the same source text and target
      history.removeWhere((i) =>
          i.sourceText.trim().toLowerCase() ==
              item.sourceText.trim().toLowerCase() &&
          i.targetLanguageCode == item.targetLanguageCode);

      history.insert(0, item);

      // Keep up to 50 items
      if (history.length > 50) {
        history.removeRange(50, history.length);
      }

      final jsonList = history.map((i) => i.toJson()).toList();
      return await prefs.setString(key, jsonEncode(jsonList));
    } catch (_) {
      return false;
    }
  }

  /// Retrieve all translation history sorted newest first for the current user.
  static Future<List<TranslationItem>> getHistory({int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyFor(currentUserId);

      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => TranslationItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Toggle favorite status of a translation item for the current user.
  static Future<bool> toggleFavorite(String id, {int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyFor(currentUserId);
      final history = await getHistory(userId: currentUserId);

      final index = history.indexWhere((i) => i.id == id);
      if (index != -1) {
        history[index] =
            history[index].copyWith(isFavorite: !history[index].isFavorite);
        final jsonList = history.map((i) => i.toJson()).toList();
        return await prefs.setString(key, jsonEncode(jsonList));
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Delete a single translation record for the current user.
  static Future<bool> deleteItem(String id, {int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyFor(currentUserId);
      final history = await getHistory(userId: currentUserId);

      history.removeWhere((i) => i.id == id);

      final jsonList = history.map((i) => i.toJson()).toList();
      return await prefs.setString(key, jsonEncode(jsonList));
    } catch (_) {
      return false;
    }
  }

  /// Clear all translation history for the current user.
  static Future<bool> clearAll({int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyFor(currentUserId);
      return await prefs.remove(key);
    } catch (_) {
      return false;
    }
  }
}
