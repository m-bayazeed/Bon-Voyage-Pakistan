import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/hotel_model.dart';
import 'hotel_location_service.dart';

/// Abstract Data Provider contract for hotel discovery.
abstract class HotelDataProvider {
  Future<List<Hotel>> fetchHotels({
    String? city,
    HotelCategory? category,
    HotelSortOption sortBy = HotelSortOption.nearness,
    String? searchQuery,
    double? userLat,
    double? userLng,
    double? deviceGpsLat,
    double? deviceGpsLng,
    double? radiusKm,
  });

  Future<List<String>> getSupportedCities();

  Future<GeoPoint?> geocodeCustomLocation(String query);
}

/// Production FastAPI + Flask Backend Hotel Data Provider.
/// Connects to `/api/v1/hotels/search`, `/api/v1/hotels/cities`, `/api/v1/hotels/resolve-location`,
/// and `/api/v1/hotels/geocode` with candidate host fallback (e.g. 127.0.0.1, 10.0.2.2, LAN Wi-Fi IP).
class BackendHotelDataProvider implements HotelDataProvider {
  static String? _cachedWorkingHost;
  static int? _cachedWorkingPort;

  @override
  Future<List<Hotel>> fetchHotels({
    String? city,
    HotelCategory? category,
    HotelSortOption sortBy = HotelSortOption.nearness,
    String? searchQuery,
    double? userLat,
    double? userLng,
    double? deviceGpsLat,
    double? deviceGpsLng,
    double? radiusKm,
  }) async {
    final locationName = city ?? 'Current Location (GPS)';
    final isGpsMode = locationName.contains('Current Location') || locationName.contains('GPS');

    // 1. Resolve search center coordinates
    double searchLat;
    double searchLon;

    if (isGpsMode) {
      if (userLat != null && userLng != null) {
        searchLat = userLat;
        searchLon = userLng;
      } else {
        final gps = await HotelLocationService.getCurrentLocation();
        searchLat = gps.latitude;
        searchLon = gps.longitude;
      }
    } else {
      // City selection / custom search: MUST use destination coordinates, NOT device GPS!
      final point = await HotelLocationService.resolveDestination(locationName);
      searchLat = point.latitude;
      searchLon = point.longitude;
    }

    // 2. Resolve device GPS origin for routing distance & ETA
    double? gpsOriginLat = deviceGpsLat;
    double? gpsOriginLon = deviceGpsLng;

    if (gpsOriginLat == null || gpsOriginLon == null) {
      if (isGpsMode) {
        gpsOriginLat = searchLat;
        gpsOriginLon = searchLon;
      }
    }

    // 3. Dynamic Search radius: 15km for Murree/Galyat, 20km for standard cities/GPS, 30km for mega cities
    final double defaultRadius;
    final locLower = locationName.toLowerCase();
    if (locLower.contains('murree') || locLower.contains('galyat') || locLower.contains('bhurban') || locLower.contains('nathia')) {
      defaultRadius = 15.0;
    } else if (locLower.contains('karachi') || locLower.contains('lahore')) {
      defaultRadius = 30.0;
    } else if (isGpsMode) {
      defaultRadius = 20.0;
    } else {
      defaultRadius = 20.0;
    }
    final searchRadius = radiusKm ?? defaultRadius;

    final categoryKey = category == null || category == HotelCategory.all
        ? 'all'
        : category.name.toLowerCase();

    final payload = {
      'city': locationName,
      'location_name': locationName,
      'latitude': searchLat,
      'longitude': searchLon,
      'user_latitude': gpsOriginLat,
      'user_longitude': gpsOriginLon,
      'radius_km': searchRadius,
      'category': categoryKey,
      'sort_by': sortBy.apiKey,
      'search_query': searchQuery,
    };

    debugPrint('\n=================== HOTEL API REQUEST ===================');
    debugPrint('City / Location: $locationName');
    debugPrint('Search Center Latitude: $searchLat');
    debugPrint('Search Center Longitude: $searchLon');
    debugPrint('User Device GPS: $gpsOriginLat, $gpsOriginLon');
    debugPrint('Search Radius: ${searchRadius}km');
    debugPrint('Category: $categoryKey');
    debugPrint('=========================================================\n');

    final candidateHosts = List<String>.from(ApiConfig.candidateHosts);
    if (_cachedWorkingHost != null && !candidateHosts.contains(_cachedWorkingHost)) {
      candidateHosts.insert(0, _cachedWorkingHost!);
    } else if (_cachedWorkingHost != null) {
      candidateHosts.remove(_cachedWorkingHost);
      candidateHosts.insert(0, _cachedWorkingHost!);
    }

    final ports = _cachedWorkingPort != null
        ? [_cachedWorkingPort!, if (_cachedWorkingPort == 5000) 8000 else 5000]
        : [5000, 8000];

    for (final host in candidateHosts) {
      for (final port in ports) {
        final url = Uri.parse(
          'http://$host:$port/api/v1/hotels/search?city=${Uri.encodeComponent(locationName)}',
        );
        try {
          debugPrint('[Hotels] POST $url (Payload: $payload)...');
          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data is Map<String, dynamic> && data['success'] == true) {
              _cachedWorkingHost = host;
              _cachedWorkingPort = port;
              final rawStays = data['stays'] as List<dynamic>? ?? [];
              final hotels = rawStays
                  .map((item) => Hotel.fromJson(item as Map<String, dynamic>))
                  .toList();

              debugPrint('[Hotels] Live API returned ${hotels.length} stays for $locationName from $host:$port');
              return hotels;
            }
          }
        } catch (e) {
          debugPrint('[Hotels] Host $host:$port unreachable: $e');
        }
      }
    }

    debugPrint('[Hotels] All backend hosts unreachable. Returning empty results.');
    return [];
  }

  static List<String> _cachedCities = [
    'Current Location (GPS)',
    'All Locations',
    'Islamabad',
    'Lahore',
    'Karachi',
    'Rawalpindi',
    'Murree',
    'Swat / Kalam',
    'Hunza',
    'Skardu',
    'Peshawar',
    'Gwadar',
    'Gilgit',
    'Naran / Kaghan',
    'Abbottabad',
  ];

  @override
  Future<List<String>> getSupportedCities() async {
    // Return cached destinations instantly (0ms delay for dropdown)
    _refreshCitiesInBackground();
    return _cachedCities;
  }

  void _refreshCitiesInBackground() async {
    final candidateHosts = ApiConfig.candidateHosts;
    final ports = [8000, 5000];

    for (final host in candidateHosts) {
      for (final port in ports) {
        final url = Uri.parse('http://$host:$port/api/v1/hotels/cities');
        try {
          final response = await http.get(url).timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data is Map<String, dynamic> && data['success'] == true) {
              final citiesRaw = data['cities'] as List<dynamic>? ?? [];
              final cityNames = citiesRaw
                  .map((c) => (c['name'] as String?) ?? '')
                  .where((n) => n.isNotEmpty)
                  .toList();

              if (cityNames.isNotEmpty) {
                _cachedCities = [
                  'Current Location (GPS)',
                  'All Locations',
                  ...cityNames,
                ];
                return;
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<GeoPoint?> geocodeCustomLocation(String query) async {
    if (query.trim().isEmpty) return null;

    final candidateHosts = ApiConfig.candidateHosts;
    final ports = [8000, 5000];

    for (final host in candidateHosts) {
      for (final port in ports) {
        final url = Uri.parse('http://$host:$port/api/v1/hotels/geocode');
        try {
          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'query': query.trim()}),
              )
              .timeout(const Duration(seconds: 6));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data is Map<String, dynamic> && data['success'] == true) {
              final results = data['results'] as List<dynamic>? ?? [];
              if (results.isNotEmpty) {
                final first = results.first as Map<String, dynamic>;
                return GeoPoint(
                  latitude: (first['latitude'] as num).toDouble(),
                  longitude: (first['longitude'] as num).toDouble(),
                  label: (first['name'] as String?) ?? query,
                );
              }
            }
          }
        } catch (_) {}
      }
    }

    return HotelLocationService.resolveDestination(query);
  }
}

/// Facade entry point for Hotel queries throughout the application.
class HotelService {
  static final HotelDataProvider _provider = BackendHotelDataProvider();

  static Future<List<Hotel>> getHotels({
    String? city,
    HotelCategory? category,
    HotelSortOption sortBy = HotelSortOption.nearness,
    String? searchQuery,
    double? userLat,
    double? userLng,
    double? deviceGpsLat,
    double? deviceGpsLng,
    double? radiusKm,
  }) {
    return _provider.fetchHotels(
      city: city,
      category: category,
      sortBy: sortBy,
      searchQuery: searchQuery,
      userLat: userLat,
      userLng: userLng,
      deviceGpsLat: deviceGpsLat,
      deviceGpsLng: deviceGpsLng,
      radiusKm: radiusKm,
    );
  }

  static Future<List<String>> getAvailableCities() {
    return _provider.getSupportedCities();
  }

  static Future<GeoPoint?> geocodeLocation(String query) {
    return _provider.geocodeCustomLocation(query);
  }
}
