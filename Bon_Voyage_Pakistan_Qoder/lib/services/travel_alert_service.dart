import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/travel_alert_model.dart';
import 'auth_service.dart';
import 'hotel_location_service.dart';

/// Abstract interface for Travel Alerts and Advisories data providers.
abstract class AlertDataProvider {
  Future<List<TravelAlert>> fetchAlerts({
    String? city,
    double? userLat,
    double? userLng,
    AlertCategory? category,
    AlertSeverity? severity,
  });

  List<String> getSupportedCities();
}

/// Production FastAPI Backend Alert Data Provider.
/// Connects to `/api/v1/notifications` (FastAPI on Port 8000) with SQLite caching,
/// live Open-Meteo weather hazards, USGS seismic feeds, and authentic corridor advisories.
/// Uses persistent local storage cache and authentic static offline fallbacks for instant startup.
class BackendAlertDataProvider implements AlertDataProvider {
  static const String _cacheKey = 'bvp_cached_authentic_alerts_v2';
  static const String _lastSyncKey = 'bvp_alerts_last_sync_timestamp';
  static String? _cachedWorkingHost;

  static const List<String> _supportedCities = [
    'All Pakistan',
    'Hunza Valley',
    'Naran & Kaghan',
    'Skardu & Baltistan',
    'Swat & Kalam',
    'Murree & Galiyat',
    'Islamabad',
    'Lahore',
    'Karachi',
    'Peshawar',
    'Quetta & Ziarat',
  ];

  /// Curated, authentic standing advisories safely served during offline cold starts.
  /// Clearly labeled as standing offline fallback advisories with real official helplines.
  static final List<TravelAlert> staticOfflineAdvisories = [
    TravelAlert(
      id: 'ALT-OFFLINE-001',
      type: AlertCategory.roadCondition,
      severity: AlertSeverity.critical,
      title: 'Karakoram Highway Landslide Clearance Protocol',
      description: 'Active rock slippage and debris clearance operations along mountain sections of KKH. Frontier Works Organisation (FWO) machinery on standby.',
      location: 'KKH Attabad & Kohistan Corridors',
      city: 'Hunza Valley',
      latitude: 36.3350,
      longitude: 74.8050,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      source: 'Frontier Works Organisation (FWO) & Tourist Police (Offline Fallback)',
      recommendedAction: 'Dial Gilgit-Baltistan Tourist Police Helpline (1422) for live convoy clearance status prior to departure.',
      isRead: false,
      details: const {
        'is_offline_fallback': true,
        'official_helpline': '1422',
        'agency': 'FWO / GB Police',
      },
    ),
    TravelAlert(
      id: 'ALT-OFFLINE-002',
      type: AlertCategory.weather,
      severity: AlertSeverity.high,
      title: 'Babusar Pass High-Altitude Snow & Ice Protocol',
      description: 'High altitude snowfall and sub-zero black ice render Babusar Top slippery. Seasonal pass timings apply.',
      location: 'Babusar Pass Summit (Elevation 13,691 ft)',
      city: 'Naran & Kaghan',
      latitude: 35.1500,
      longitude: 74.0500,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      source: 'National Disaster Management Authority - NDMA (Offline Fallback)',
      recommendedAction: 'Use the alternative Karakoram Highway via Kohistan/Chilas for heavy transport or during inclement weather.',
      isRead: false,
      details: const {
        'is_offline_fallback': true,
        'official_helpline': '051-9205037',
        'agency': 'NDMA',
      },
    ),
    TravelAlert(
      id: 'ALT-OFFLINE-003',
      type: AlertCategory.roadCondition,
      severity: AlertSeverity.high,
      title: 'Jaglot-Skardu Strategic Highway Precaution',
      description: 'Rock falling watch near Astak Nala due to temperature variations. Highway is monitored under police control.',
      location: 'Jaglot-Skardu Highway at Astak Nala',
      city: 'Skardu & Baltistan',
      latitude: 35.5800,
      longitude: 74.9200,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      source: 'National Highway Authority - NHA (Offline Fallback)',
      recommendedAction: 'Commute during daylight hours only. Maintain a safe distance from steep rock faces in the Indus gorge.',
      isRead: false,
      details: const {
        'is_offline_fallback': true,
        'official_helpline': '130',
        'agency': 'NHA',
      },
    ),
    TravelAlert(
      id: 'ALT-OFFLINE-004',
      type: AlertCategory.advisory,
      severity: AlertSeverity.moderate,
      title: 'Motorway Travel Advisory & Fog Guidelines',
      description: 'Smog and seasonal night fog affect visibility across Punjab plains. Night convoy timings may be activated by Motorway Police.',
      location: 'M-2, M-3 & M-5 Motorway Corridors',
      city: 'Lahore',
      latitude: 31.5200,
      longitude: 74.3580,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      source: 'National Highways & Motorway Police - NHMP (Offline Fallback)',
      recommendedAction: 'Plan journeys between 10:00 AM and 05:00 PM. Dial 130 for real-time motorway status before departure.',
      isRead: false,
      details: const {
        'is_offline_fallback': true,
        'official_helpline': '130',
        'agency': 'NHMP',
      },
    ),
    TravelAlert(
      id: 'ALT-OFFLINE-005',
      type: AlertCategory.publicSafety,
      severity: AlertSeverity.informational,
      title: 'Emergency Medical & Disaster Rescue Helpline 1122',
      description: 'Punjab, KP, and GB Emergency Ambulance and Rescue Services are active 24/7 across major travel hubs.',
      location: 'Nationwide Travel Corridors',
      city: 'All Pakistan',
      latitude: 33.6844,
      longitude: 73.0479,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      source: 'Emergency Rescue 1122 (Offline Fallback)',
      recommendedAction: 'Dial 1122 toll-free from any mobile or landline across Pakistan for emergency medical assistance.',
      isRead: false,
      details: const {
        'is_offline_fallback': true,
        'official_helpline': '1122',
        'agency': 'Rescue 1122',
      },
    ),
  ];

  @override
  List<String> getSupportedCities() => _supportedCities;

  /// Load cached authentic alerts from local storage, or return static offline advisories if cache is empty.
  static Future<List<TravelAlert>> loadCachedAlerts({
    String? city,
    double? userLat,
    double? userLng,
    AlertCategory? category,
    AlertSeverity? severity,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_cacheKey);
      
      List<TravelAlert> list;
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(rawJson) as List<dynamic>;
        list = decoded
            .map((item) => TravelAlert.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        // Cold-start seed: Serve authentic static offline advisories
        list = List<TravelAlert>.from(staticOfflineAdvisories);
      }

      return _filterAlerts(
        alerts: list,
        city: city,
        userLat: userLat,
        userLng: userLng,
        category: category,
        severity: severity,
      );
    } catch (e) {
      debugPrint('[Notifications] Local alert cache read error: $e');
      return _filterAlerts(
        alerts: staticOfflineAdvisories,
        city: city,
        userLat: userLat,
        userLng: userLng,
        category: category,
        severity: severity,
      );
    }
  }

  /// Save authentic alerts to local storage.
  static Future<void> saveToCache(List<TravelAlert> alerts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(alerts.map((a) => a.toJson()).toList());
      await prefs.setString(_cacheKey, encoded);
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[Notifications] Local alert cache save error: $e');
    }
  }

  /// Check whether the local cache is stale (>15 minutes old or empty).
  static Future<bool> isCacheStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_lastSyncKey);
      if (lastSync == null) return true;
      final diff = DateTime.now().millisecondsSinceEpoch - lastSync;
      return diff > (15 * 60 * 1000); // 15 minutes
    } catch (_) {
      return true;
    }
  }

  @override
  Future<List<TravelAlert>> fetchAlerts({
    String? city,
    double? userLat,
    double? userLng,
    AlertCategory? category,
    AlertSeverity? severity,
  }) async {
    final candidateHosts = ApiConfig.candidateHosts;
    final candidatePorts = ApiConfig.candidatePorts;
    final endpointsToTry = <String>[];

    // Try cached working endpoint first
    if (_cachedWorkingHost != null && _cachedWorkingHost!.startsWith('http')) {
      endpointsToTry.add(_cachedWorkingHost!);
    }

    for (final host in candidateHosts) {
      for (final port in candidatePorts) {
        final ep = 'http://$host:$port/api/v1/notifications';
        if (!endpointsToTry.contains(ep)) {
          endpointsToTry.add(ep);
        }
      }
    }

    final queryParams = <String, String>{};
    if (city != null &&
        city.isNotEmpty &&
        city.toLowerCase() != 'all pakistan' &&
        !city.toLowerCase().contains('current location') &&
        !city.toLowerCase().contains('gps')) {
      queryParams['city'] = city;
    }
    if (userLat != null && userLng != null) {
      queryParams['lat'] = userLat.toString();
      queryParams['lon'] = userLng.toString();
    }
    if (category != null && category != AlertCategory.all) {
      queryParams['category'] = category.name;
    }
    if (severity != null) {
      queryParams['severity'] = severity.name;
    }

    for (final endpoint in endpointsToTry) {
      final baseUri = Uri.parse(endpoint);
      final uri = queryParams.isEmpty ? baseUri : baseUri.replace(queryParameters: queryParams);

      try {
        debugPrint('[Notifications] Attempting backend: $uri');
        // Fast failover timeout (3s per candidate host)
        final response = await http.get(uri).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final rawList = data['alerts'] as List<dynamic>? ?? [];
          final alerts = rawList
              .map((item) => TravelAlert.fromJson(item as Map<String, dynamic>))
              .toList();

          _cachedWorkingHost = endpoint;
          debugPrint('[Notifications] Successfully loaded ${alerts.length} live alerts from FastAPI backend at $endpoint');

          // Persist the authentic live alerts in local cache
          if (queryParams.isEmpty && alerts.isNotEmpty) {
            await saveToCache(alerts);
          }

          return alerts;
        } else {
          debugPrint('[Notifications] Backend HTTP ${response.statusCode} at $endpoint: ${response.body}');
        }

      } on TimeoutException {
        debugPrint('[Notifications] Backend unavailable: Timeout (10s) at $endpoint');
      } on SocketException catch (e) {
        debugPrint('[Notifications] Backend unavailable: Socket error at $endpoint (${e.message})');
      } on http.ClientException catch (e) {
        debugPrint('[Notifications] Backend unavailable: Client connection error at $endpoint (${e.message})');
      } catch (e) {
        debugPrint('[Notifications] Backend alert fetch failed at $endpoint: $e');
      }
    }


    debugPrint('[Notifications] All backend hosts unreachable. Falling back to local cache / static offline advisories.');
    return loadCachedAlerts(
      city: city,
      userLat: userLat,
      userLng: userLng,
      category: category,
      severity: severity,
    );
  }

  /// Internal filtering for cached and offline alerts
  static List<TravelAlert> _filterAlerts({
    required List<TravelAlert> alerts,
    String? city,
    double? userLat,
    double? userLng,
    AlertCategory? category,
    AlertSeverity? severity,
  }) {
    var results = List<TravelAlert>.from(alerts);

    // Filter out expired alerts
    final now = DateTime.now();
    results = results.where((a) {
      if (a.expiresAt != null && a.expiresAt!.isBefore(now)) {
        return false;
      }
      return true;
    }).toList();

    // 1. City / Region filter
    if (city != null &&
        city.isNotEmpty &&
        city.toLowerCase() != 'all pakistan' &&
        city.toLowerCase() != 'all') {
      final normalized = city.toLowerCase().trim();
      results = results.where((a) {
        final alertCity = a.city.toLowerCase();
        final alertLoc = a.location.toLowerCase();
        return alertCity.contains(normalized) ||
            normalized.contains(alertCity) ||
            alertLoc.contains(normalized) ||
            alertCity == 'all pakistan' ||
            alertCity == 'national';
      }).toList();
    }

    // 2. Category filter
    if (category != null && category != AlertCategory.all) {
      results = results.where((a) => a.type == category).toList();
    }

    // 3. Severity filter
    if (severity != null) {
      results = results.where((a) => a.severity == severity).toList();
    }

    // Sort by severity (Critical first, then High, Moderate, Info) and newest
    results.sort((a, b) {
      final sevComp = a.severity.index.compareTo(b.severity.index);
      if (sevComp != 0) return sevComp;
      return b.createdAt.compareTo(a.createdAt);
    });

    return results;
  }
}

/// Service coordinating alert querying, user-scoped read tracking, and live location filtering.
class TravelAlertService {
  static AlertDataProvider _provider = BackendAlertDataProvider();

  /// Change data provider (e.g. live REST API).
  static void setProvider(AlertDataProvider provider) {
    _provider = provider;
  }

  /// Supported city destinations for filtering.
  static List<String> getSupportedCities() => _provider.getSupportedCities();

  static String _readKeyFor(int? userId) {
    if (userId != null) return 'bvp_read_alerts_user_$userId';
    return 'bvp_read_alerts_guest';
  }

  /// Get set of read alert IDs for the currently authenticated user.
  static Future<Set<String>> _getReadAlertIds({int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final key = _readKeyFor(currentUserId);
      final raw = prefs.getStringList(key);
      return raw != null ? raw.toSet() : <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  /// Save read alert IDs for the current user.
  static Future<void> _saveReadAlertIds(Set<String> ids, {int? userId}) async {
    try {
      final currentUserId = userId ?? await AuthService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final key = _readKeyFor(currentUserId);
      await prefs.setStringList(key, ids.toList());
    } catch (_) {}
  }

  /// Retrieve locally cached authentic alerts immediately without waiting for network.
  static Future<List<TravelAlert>> getCachedAlerts({
    String? city,
    double? userLat,
    double? userLng,
    AlertCategory category = AlertCategory.all,
    AlertSeverity? severity,
    int? userId,
  }) async {
    try {
      final cached = await BackendAlertDataProvider.loadCachedAlerts(
        city: city,
        userLat: userLat,
        userLng: userLng,
        category: category,
        severity: severity,
      );

      final currentUserId = userId ?? await AuthService.getUserId();
      final readIds = await _getReadAlertIds(userId: currentUserId);

      return cached.map((a) => a.copyWith(isRead: readIds.contains(a.id))).toList();
    } catch (e) {
      debugPrint('[Notifications] Error loading cached alerts: $e');
      return [];
    }
  }

  /// Triggers a non-blocking background refresh of notifications from backend.
  static Future<void> refreshAlertsInBackground() async {
    try {
      debugPrint('[Notifications] Background refresh started...');
      final candidateHosts = ApiConfig.candidateHosts;
      final candidatePorts = ApiConfig.candidatePorts;
      for (final host in candidateHosts) {
        for (final port in candidatePorts) {
          try {
            final uri = Uri.parse('http://$host:$port/api/v1/notifications');
            final response = await http.get(uri).timeout(const Duration(seconds: 3));

            if (response.statusCode == 200) {
              final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
              final rawList = data['alerts'] as List<dynamic>? ?? [];
              final alerts = rawList
                  .map((item) => TravelAlert.fromJson(item as Map<String, dynamic>))
                  .toList();
              if (alerts.isNotEmpty) {
                await BackendAlertDataProvider.saveToCache(alerts);
                debugPrint('[Notifications] Background refresh succeeded: ${alerts.length} alerts cached.');
                return;
              }
            }
          } catch (_) {}
        }
      }

    } catch (e) {
      debugPrint('[Notifications] Background refresh notice: $e');
    }
  }

  /// Fetch alerts with active user read-state synchronization.
  static Future<List<TravelAlert>> getAlerts({
    String? city,
    bool useCurrentLocation = false,
    AlertCategory category = AlertCategory.all,
    AlertSeverity? severity,
    int? userId,
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint('[Notifications] Fetch initiated: city=$city, useGPS=$useCurrentLocation, cat=${category.name}, forceRefresh=$forceRefresh');

      double? userLat;
      double? userLng;

      if (useCurrentLocation) {
        final pos = await HotelLocationService.getCurrentLocation();
        userLat = pos.latitude;
        userLng = pos.longitude;
        debugPrint('[Notifications] GPS Location: $userLat, $userLng');
      }

      final rawAlerts = await _provider.fetchAlerts(
        city: useCurrentLocation ? null : city,
        userLat: userLat,
        userLng: userLng,
        category: category,
        severity: severity,
      );

      final currentUserId = userId ?? await AuthService.getUserId();
      final readIds = await _getReadAlertIds(userId: currentUserId);

      final mapped = rawAlerts.map((a) {
        return a.copyWith(isRead: readIds.contains(a.id));
      }).toList();

      debugPrint('[Notifications] Total alerts available: ${mapped.length}');
      return mapped;
    } catch (e, stackTrace) {
      debugPrint('[Notifications] Alert service error: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Fail-safe: Always return cached or static offline fallback
      return getCachedAlerts(
        city: city,
        userLat: null,
        userLng: null,
        category: category,
        severity: severity,
        userId: userId,
      );
    }
  }

  /// Mark a single alert as read for the current user.
  static Future<void> markAsRead(String alertId, {int? userId}) async {
    final currentUserId = userId ?? await AuthService.getUserId();
    final readIds = await _getReadAlertIds(userId: currentUserId);
    readIds.add(alertId);
    await _saveReadAlertIds(readIds, userId: currentUserId);
  }

  /// Mark all alerts as read for the current user.
  static Future<void> markAllAsRead(List<TravelAlert> alerts, {int? userId}) async {
    final currentUserId = userId ?? await AuthService.getUserId();
    final readIds = await _getReadAlertIds(userId: currentUserId);
    for (final a in alerts) {
      readIds.add(a.id);
    }
    await _saveReadAlertIds(readIds, userId: currentUserId);
  }

  /// Get count of unread high/critical alerts.
  static Future<int> getUnreadCount({int? userId}) async {
    final currentUserId = userId ?? await AuthService.getUserId();
    final alerts = await getAlerts(userId: currentUserId);
    return alerts.where((a) => !a.isRead).length;
  }
}
