import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_plan_model.dart';
import 'auth_service.dart';

/// Handles persistent local storage of AI Tour Plans with user-specific isolation.
class TripHistoryService {
  static String _storageKeyFor(int? userId) {
    if (userId != null) {
      return 'bvp_saved_trip_plans_user_$userId';
    }
    return 'bvp_saved_trip_plans_guest';
  }

  /// Save a new or updated trip plan to persistent storage for the current user.
  static Future<bool> saveTripPlan(TripPlan plan, {int? userId}) async {
    try {
      final currentUserId = userId ?? plan.userId ?? await AuthService.getUserId();
      final planToSave = plan.userId != null ? plan : plan.copyWith(userId: currentUserId);

      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyFor(currentUserId);
      final plans = await getSavedTripPlans(userId: currentUserId);

      // Replace existing plan if found, otherwise add to front of list
      final index = plans.indexWhere((p) => p.id == planToSave.id);
      if (index != -1) {
        plans[index] = planToSave;
      } else {
        plans.insert(0, planToSave);
      }

      final jsonList = plans.map((p) => p.toJson()).toList();
      return await prefs.setString(key, jsonEncode(jsonList));
    } catch (_) {
      return false;
    }
  }

  /// Retrieve all saved trip plans for the current authenticated user sorted by newest first.
  static Future<List<TripPlan>> getSavedTripPlans({int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyFor(currentUserId);

      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map((item) => TripPlan.fromJson(item as Map<String, dynamic>))
          .toList();

      if (currentUserId != null) {
        return list.where((p) => p.userId == null || p.userId == currentUserId).toList();
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Retrieve the single latest finalized trip plan for the user, if one exists.
  static Future<TripPlan?> getLatestFinalizedPlan({int? userId}) async {
    try {
      final plans = await getSavedTripPlans(userId: userId);
      final finalizedPlans = plans.where((p) => p.isFinalized).toList();
      if (finalizedPlans.isEmpty) {
        return null;
      }
      // Sort by creation date descending to ensure newest
      finalizedPlans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return finalizedPlans.first;
    } catch (_) {
      return null;
    }
  }


  /// Delete a saved trip plan by id for the current user.
  static Future<bool> deleteTripPlan(String planId, {int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyFor(currentUserId);

      final plans = await getSavedTripPlans(userId: currentUserId);
      plans.removeWhere((p) => p.id == planId);

      final jsonList = plans.map((p) => p.toJson()).toList();
      return await prefs.setString(key, jsonEncode(jsonList));
    } catch (_) {
      return false;
    }
  }

  /// Clear all saved trip plans for the current user.
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
