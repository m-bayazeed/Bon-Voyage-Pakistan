import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/food_place_model.dart';
import 'hotel_location_service.dart';

/// Abstract interface for food & dining data providers.
abstract class FoodDataProvider {
  Future<List<FoodPlace>> fetchFoodPlaces({
    String? city,
    double? userLat,
    double? userLng,
    double? searchLat,
    double? searchLng,
    FoodCategory? category,
    String? query,
    FoodSortOption sortOption = FoodSortOption.rating,
  });

  List<String> getSupportedCities();
}

/// Production FastAPI + Flask Backend Food Data Provider.
/// Connects to `/api/v1/food/search` with candidate host fallback (e.g. 127.0.0.1, 10.0.2.2, LAN IP),
/// performing Google Places (New) 30km discovery & Google Routes real driving road distance & duration.
class BackendFoodDataProvider implements FoodDataProvider {
  static String? _cachedWorkingHost;
  static int? _cachedWorkingPort;

  @override
  List<String> getSupportedCities() => const [
        'Islamabad',
        'Lahore',
        'Karachi',
        'Hunza Valley',
        'Skardu',
        'Swat & Kalam',
        'Naran & Kaghan',
        'Murree & Galiyat',
        'Peshawar',
        'Quetta & Ziarat',
        'Multan',
      ];

  @override
  Future<List<FoodPlace>> fetchFoodPlaces({
    String? city,
    double? userLat,
    double? userLng,
    double? searchLat,
    double? searchLng,
    FoodCategory? category,
    String? query,
    FoodSortOption sortOption = FoodSortOption.rating,
  }) async {
    final locationName = city ?? 'Current Location (GPS)';
    final isGpsMode = locationName.contains('Current Location') || locationName.contains('GPS');

    // 1. Resolve search center coordinates
    double centerLat;
    double centerLon;

    if (isGpsMode) {
      if (searchLat != null && searchLng != null) {
        centerLat = searchLat;
        centerLon = searchLng;
      } else if (userLat != null && userLng != null) {
        centerLat = userLat;
        centerLon = userLng;
      } else {
        final gps = await HotelLocationService.getCurrentLocation();
        centerLat = gps.latitude;
        centerLon = gps.longitude;
      }
    } else {
      if (searchLat != null && searchLng != null) {
        centerLat = searchLat;
        centerLon = searchLng;
      } else {
        final point = await HotelLocationService.resolveDestination(locationName);
        centerLat = point.latitude;
        centerLon = point.longitude;
      }
    }

    // 2. User device GPS origin for routing distance & ETA
    double? gpsOriginLat = userLat;
    double? gpsOriginLon = userLng;

    if (gpsOriginLat == null || gpsOriginLon == null) {
      if (isGpsMode) {
        gpsOriginLat = centerLat;
        gpsOriginLon = centerLon;
      }
    }

    final catKey = category == null || category == FoodCategory.all ? 'all' : category.name;
    final sortKey = sortOption.name;

    final payload = {
      'city': locationName,
      'location_name': locationName,
      'latitude': centerLat,
      'longitude': centerLon,
      'user_latitude': gpsOriginLat,
      'user_longitude': gpsOriginLon,
      'radius_km': 30.0,
      'category': catKey,
      'sort_by': sortKey,
      'search_query': query,
    };

    debugPrint('\n=================== FOOD API REQUEST ===================');
    debugPrint('Location: $locationName');
    debugPrint('Search Center: $centerLat, $centerLon (Radius: 30 km)');
    debugPrint('User Device GPS: $gpsOriginLat, $gpsOriginLon');
    debugPrint('Category: $catKey | Sort: $sortKey');
    debugPrint('========================================================\n');

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
        final url = Uri.parse('http://$host:$port/api/v1/food/search');
        try {
          debugPrint('[Food] POST $url (Payload: $payload)...');
          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data is Map<String, dynamic> && data['success'] == true) {
              _cachedWorkingHost = host;
              _cachedWorkingPort = port;
              final rawPlaces = data['places'] as List<dynamic>? ?? [];
              final places = rawPlaces
                  .map((item) => FoodPlace.fromJson(item as Map<String, dynamic>))
                  .toList();

              debugPrint('[Food] Live API returned ${places.length} places for $locationName from $host:$port');
              return places;
            }
          }
        } catch (e) {
          debugPrint('[Food] Host $host:$port unreachable: $e');
        }
      }
    }

    debugPrint('[Food] All backend hosts unreachable.');
    throw Exception('Unable to load nearby places. Please check your connection and try again.');
  }
}

/// Central Repository coordinating Food Data, GPS resolution, sorting, and filtering.
class FoodService {
  static FoodDataProvider _provider = BackendFoodDataProvider();

  /// Change data provider (e.g. Google Places, OpenStreetMap, or custom REST API).
  static void setProvider(FoodDataProvider provider) {
    _provider = provider;
  }

  /// Get supported city destinations.
  static List<String> getSupportedCities() => _provider.getSupportedCities();

  /// Fetch and sort food spots according to user selections.
  static Future<List<FoodPlace>> searchFoodPlaces({
    String? city,
    bool useCurrentLocation = false,
    FoodCategory category = FoodCategory.all,
    FoodSortOption sortOption = FoodSortOption.rating,
    String? query,
    double? userLat,
    double? userLng,
    double? searchLat,
    double? searchLng,
  }) async {
    try {
      debugPrint('FOOD SEARCH STARTED: city=$city, useGPS=$useCurrentLocation, category=${category.name}');

      double? currentDeviceLat = userLat;
      double? currentDeviceLng = userLng;

      if (currentDeviceLat == null || currentDeviceLng == null) {
        try {
          final pos = await HotelLocationService.getCurrentLocation();
          currentDeviceLat = pos.latitude;
          currentDeviceLng = pos.longitude;
          debugPrint('FOOD LOCATION (GPS): $currentDeviceLat, $currentDeviceLng');
        } catch (e) {
          debugPrint('Could not fetch device GPS: $e');
        }
      }

      var places = await _provider.fetchFoodPlaces(
        city: useCurrentLocation ? null : city,
        userLat: currentDeviceLat,
        userLng: currentDeviceLng,
        searchLat: searchLat,
        searchLng: searchLng,
        category: category,
        query: query,
        sortOption: sortOption,
      );

      // Sort results
      switch (sortOption) {
        case FoodSortOption.nearest:
          places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
          break;
        case FoodSortOption.rating:
          places.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case FoodSortOption.reviews:
          places.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
          break;
        case FoodSortOption.priceLowToHigh:
          places.sort((a, b) => a.avgCostPerPersonPkr.compareTo(b.avgCostPerPersonPkr));
          break;
        case FoodSortOption.priceHighToLow:
          places.sort((a, b) => b.avgCostPerPersonPkr.compareTo(a.avgCostPerPersonPkr));
          break;
      }

      debugPrint('FOOD SEARCH COMPLETE: Found ${places.length} places');
      return places;
    } catch (e, stackTrace) {
      debugPrint('FOOD API ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
