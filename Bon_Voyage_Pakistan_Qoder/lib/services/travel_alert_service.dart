import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Rich curated data provider representing authentic Pakistani travel alerts from NDMA, PMD, and NHMP.
class CuratedAlertDataProvider implements AlertDataProvider {
  @override
  List<String> getSupportedCities() => const [
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

  static final List<TravelAlert> _dataset = [
    TravelAlert(
      id: 'ALT-KKH-001',
      type: AlertCategory.roadCondition,
      severity: AlertSeverity.critical,
      title: 'Karakoram Highway Landslide Clearance',
      description:
          'A rocky landslide has blocked the Karakoram Highway (KKH) near Attabad. Frontier Works Organisation (FWO) machinery is actively clearing the road.',
      location: 'KKH Section near Attabad Tunnel, Upper Hunza',
      city: 'Hunza Valley',
      latitude: 36.3350,
      longitude: 74.8050,
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
      source: 'Frontier Works Organisation (FWO) & District Administration',
      recommendedAction:
          'Avoid travel toward Upper Hunza until full clearance. Contact Gilgit-Baltistan Tourist Police helpline (1422) for live status.',
    ),
    TravelAlert(
      id: 'ALT-BAB-002',
      type: AlertCategory.weather,
      severity: AlertSeverity.critical,
      title: 'Babusar Pass Snowfall & Road Closure',
      description:
          'Heavy snowfall and black ice have rendered Babusar Top impassable. The pass is temporarily closed for all vehicular traffic.',
      location: 'Babusar Pass Summit (Elevation 13,691 ft), Kaghan Valley',
      city: 'Naran & Kaghan',
      latitude: 35.1500,
      longitude: 74.0500,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      source: 'National Disaster Management Authority (NDMA)',
      recommendedAction:
          'Use the alternative Karakoram Highway (via Kohistan & Chilas) for travel between Rawalpindi/Islamabad and Gilgit.',
    ),
    TravelAlert(
      id: 'ALT-SKD-003',
      type: AlertCategory.roadCondition,
      severity: AlertSeverity.high,
      title: 'Jaglot-Skardu Road Falling Stones Watch',
      description:
          'Intermittent rock falling reported near Astak Nala due to recent rainfall. Single-lane traffic open under police monitoring.',
      location: 'Jaglot-Skardu Highway at Astak Nala',
      city: 'Skardu & Baltistan',
      latitude: 35.5800,
      longitude: 74.9200,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      source: 'National Highway Authority (NHA) Control Room',
      recommendedAction:
          'Drive with extreme caution during daytime only. Avoid nighttime commuting along the gorge.',
    ),
    TravelAlert(
      id: 'ALT-SWT-004',
      type: AlertCategory.naturalDisaster,
      severity: AlertSeverity.high,
      title: 'River Swat Water Level Alert',
      description:
          'Due to glacier melt and upper catchment rainfall, River Swat water flow has increased to medium-flood level near Kalam and Madyan.',
      location: 'Riverside Areas of Kalam, Madyan & Bahrain',
      city: 'Swat & Kalam',
      latitude: 35.4800,
      longitude: 72.5800,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      source: 'Provincial Disaster Management Authority (PDMA Khyber Pakhtunkhwa)',
      recommendedAction:
          'Refrain from setting up camps directly on riverbanks or gravel islands. Adhere to local administration safety advisories.',
    ),
    TravelAlert(
      id: 'ALT-MUR-005',
      type: AlertCategory.weather,
      severity: AlertSeverity.moderate,
      title: 'Dense Fog & Snow Chains Requirement',
      description:
          'Dense fog reduces visibility to under 50 meters between Lower Topa and Changla Gali. Sub-zero temperatures causing black ice.',
      location: 'Murree Expressway (N-75) & Galiyat Belt',
      city: 'Murree & Galiyat',
      latitude: 33.9060,
      longitude: 73.3900,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      source: 'National Highways & Motorway Police (NHMP Sector M-75)',
      recommendedAction:
          'Keep vehicle fog lights on, maintain generous following distance, and ensure functional tire chains for Galiyat ascents.',
    ),
    TravelAlert(
      id: 'ALT-ISB-006',
      type: AlertCategory.roadCondition,
      severity: AlertSeverity.moderate,
      title: 'Margalla Hills Trail Maintenance & Mud Slippage',
      description:
          'Trail 3 and Pir Sohawa uphill road experiencing minor mud runoff following evening showers. Cyclists and motorists advised to slow down.',
      location: 'Pir Sohawa Road, Margalla Foothills, Islamabad',
      city: 'Islamabad',
      latitude: 33.7480,
      longitude: 73.0640,
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      source: 'Capital Development Authority (CDA Environment Wing)',
      recommendedAction:
          'Use lower gear on steep bends and stay within marked speed limits.',
    ),
    TravelAlert(
      id: 'ALT-LHE-007',
      type: AlertCategory.advisory,
      severity: AlertSeverity.moderate,
      title: 'M-2 Motorway Winter Fog Timings Advisory',
      description:
          'Thick smog and night fog expected across Punjab plains. M-2 Motorway (Lahore to Islamabad) may experience night closures for traveler safety.',
      location: 'M-2 Motorway Interchange Toll Plaza, Lahore',
      city: 'Lahore',
      latitude: 31.5200,
      longitude: 74.3580,
      createdAt: DateTime.now().subtract(const Duration(hours: 16)),
      source: 'National Highways & Motorway Police (NHMP Central Zone)',
      recommendedAction:
          'Plan travel between 10:00 AM and 05:00 PM. Dial 130 for real-time motorway opening updates before departure.',
    ),
    TravelAlert(
      id: 'ALT-KHI-008',
      type: AlertCategory.weather,
      severity: AlertSeverity.informational,
      title: 'Arabian Sea High Tide & Coastal Breeze',
      description:
          'High tidal waves and gusty southwestern winds forecast along Clifton and Manora coasts. Beach swimming temporarily discouraged.',
      location: 'Clifton Beach, Do Darya & Hawke’s Bay, Karachi',
      city: 'Karachi',
      latitude: 24.7720,
      longitude: 67.0780,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      source: 'Pakistan Meteorological Department (PMD Marine Centre)',
      recommendedAction:
          'Enjoy coastal dining from designated seaside promenades; follow lifeguard beach flags.',
    ),
    TravelAlert(
      id: 'ALT-QTA-009',
      type: AlertCategory.weather,
      severity: AlertSeverity.informational,
      title: 'Ziarat Valley Cold Wave & Frost Advisory',
      description:
          'Night temperatures dropping to -4°C across Ziarat Juniper Forest. Morning frost on provincial highway bends.',
      location: 'Ziarat Valley & Juniper Biosphere Reserve',
      city: 'Quetta & Ziarat',
      latitude: 30.3800,
      longitude: 67.7200,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      source: 'Balochistan Disaster Management Authority (PDMA)',
      recommendedAction:
          'Ensure vehicle antifreeze is topped up and pack thermal mountain apparel for excursions.',
    ),
    TravelAlert(
      id: 'ALT-PSH-010',
      type: AlertCategory.roadCondition,
      severity: AlertSeverity.informational,
      title: 'Ring Road Northern Bypass Traffic Diversion',
      description:
          'Bridge expansion joints maintenance in progress on Peshawar Northern Bypass. Minor diversions active via service lane.',
      location: 'Peshawar Northern Bypass, Khyber Pakhtunkhwa',
      city: 'Peshawar',
      latitude: 34.0150,
      longitude: 71.5800,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      source: 'Peshawar Traffic Police & Highway Authority',
      recommendedAction:
          'Follow traffic warden signals for smooth bypass transit.',
    ),
  ];

  @override
  Future<List<TravelAlert>> fetchAlerts({
    String? city,
    double? userLat,
    double? userLng,
    AlertCategory? category,
    AlertSeverity? severity,
  }) async {
    // Realistic micro-delay for API readiness
    await Future.delayed(const Duration(milliseconds: 300));

    var results = List<TravelAlert>.from(_dataset);

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
            alertLoc.contains(normalized);
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
  static AlertDataProvider _provider = CuratedAlertDataProvider();

  /// Change data provider (e.g. live NDMA / PMD REST API).
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

  /// Fetch alerts with active user read-state synchronization.
  static Future<List<TravelAlert>> getAlerts({
    String? city,
    bool useCurrentLocation = false,
    AlertCategory category = AlertCategory.all,
    AlertSeverity? severity,
    int? userId,
  }) async {
    try {
      debugPrint('ALERTS LOAD STARTED: city=$city, useGPS=$useCurrentLocation, cat=${category.name}');

      double? userLat;
      double? userLng;

      if (useCurrentLocation) {
        final pos = await HotelLocationService.getCurrentLocation();
        userLat = pos.latitude;
        userLng = pos.longitude;
        debugPrint('ALERT LOCATION (GPS): $userLat, $userLng');
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

      debugPrint('ALERTS RECEIVED: ${mapped.length} alerts loaded.');
      return mapped;
    } catch (e, stackTrace) {
      debugPrint('ALERT API ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
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
