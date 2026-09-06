import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Representation of geographical coordinates.
class GeoPoint {
  final double latitude;
  final double longitude;
  final String label;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.label = '',
  });

  @override
  String toString() => 'GeoPoint($label: $latitude, $longitude)';
}

/// Service managing device GPS acquisition with Geolocator, dynamic Gemini-based
/// coordinate resolution, and distance calculations across Pakistan.
class HotelLocationService {
  /// Default center if GPS is unavailable or permission denied (Islamabad Blue Area).
  static const GeoPoint defaultLocation = GeoPoint(
    latitude: 33.6844,
    longitude: 73.0479,
    label: 'Islamabad',
  );

  /// Verified geographic centers of all major Pakistani destinations and valleys.
  /// Used for instant offline resolution and cache initialization.
  static const Map<String, GeoPoint> knownDestinations = {
    'islamabad': GeoPoint(latitude: 33.6844, longitude: 73.0479, label: 'Islamabad'),
    'lahore': GeoPoint(latitude: 31.5204, longitude: 74.3587, label: 'Lahore'),
    'karachi': GeoPoint(latitude: 24.8607, longitude: 67.0011, label: 'Karachi'),
    'rawalpindi': GeoPoint(latitude: 33.5973, longitude: 73.0479, label: 'Rawalpindi'),
    'peshawar': GeoPoint(latitude: 34.0151, longitude: 71.5249, label: 'Peshawar'),
    'quetta': GeoPoint(latitude: 30.1798, longitude: 66.9750, label: 'Quetta'),
    'quetta & ziarat': GeoPoint(latitude: 30.1798, longitude: 66.9750, label: 'Quetta & Ziarat'),
    'ziarat': GeoPoint(latitude: 30.3824, longitude: 67.7256, label: 'Ziarat'),
    'multan': GeoPoint(latitude: 30.1575, longitude: 71.5249, label: 'Multan'),
    'faisalabad': GeoPoint(latitude: 31.4504, longitude: 73.1350, label: 'Faisalabad'),
    'murree': GeoPoint(latitude: 33.9062, longitude: 73.3903, label: 'Murree'),
    'murree & galiyat': GeoPoint(latitude: 33.9062, longitude: 73.3903, label: 'Murree & Galiyat'),
    'hunza': GeoPoint(latitude: 36.3167, longitude: 74.6500, label: 'Hunza'),
    'hunza / karimabad': GeoPoint(latitude: 36.3167, longitude: 74.6500, label: 'Hunza / Karimabad'),
    'karimabad': GeoPoint(latitude: 36.3167, longitude: 74.6500, label: 'Hunza / Karimabad'),
    'hunza valley': GeoPoint(latitude: 36.3167, longitude: 74.6500, label: 'Hunza Valley'),
    'skardu': GeoPoint(latitude: 35.2971, longitude: 75.6333, label: 'Skardu'),
    'gilgit': GeoPoint(latitude: 35.9208, longitude: 74.3144, label: 'Gilgit'),
    'swat': GeoPoint(latitude: 35.4859, longitude: 72.5855, label: 'Swat / Kalam'),
    'swat / kalam': GeoPoint(latitude: 35.4859, longitude: 72.5855, label: 'Swat / Kalam'),
    'swat & kalam': GeoPoint(latitude: 35.4859, longitude: 72.5855, label: 'Swat & Kalam'),
    'kalam': GeoPoint(latitude: 35.4859, longitude: 72.5855, label: 'Kalam'),
    'naran': GeoPoint(latitude: 34.9085, longitude: 73.6542, label: 'Naran / Kaghan'),
    'naran / kaghan': GeoPoint(latitude: 34.9085, longitude: 73.6542, label: 'Naran / Kaghan'),
    'naran & kaghan': GeoPoint(latitude: 34.9085, longitude: 73.6542, label: 'Naran & Kaghan'),
    'kaghan': GeoPoint(latitude: 34.9085, longitude: 73.6542, label: 'Kaghan'),
    'gwadar': GeoPoint(latitude: 25.1264, longitude: 62.3225, label: 'Gwadar'),
    'chitral': GeoPoint(latitude: 35.8510, longitude: 71.7864, label: 'Chitral'),
    'abbottabad': GeoPoint(latitude: 34.1688, longitude: 73.2215, label: 'Abbottabad'),
    'nathia gali': GeoPoint(latitude: 34.0700, longitude: 73.3800, label: 'Nathia Gali'),
    'passu': GeoPoint(latitude: 36.4883, longitude: 74.8875, label: 'Passu'),
    'katas raj': GeoPoint(latitude: 32.7247, longitude: 72.9537, label: 'Katas Raj'),
  };

  static final Map<String, GeoPoint> _resolvedCache = Map.of(knownDestinations);

  /// Calculate great-circle distance between two GPS coordinates using the Haversine formula.
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return double.parse((earthRadiusKm * c).toStringAsFixed(2));
  }

  static double _toRadians(double degree) => degree * (pi / 180.0);

  /// Convert distance in KM to user-friendly formatted string.
  static String formatDistance(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m away';
    }
    return '${km.toStringAsFixed(1)} km away';
  }

  /// Dynamically resolve coordinates for any Pakistani destination name using Gemini backend.
  static Future<GeoPoint> resolveDestination(String destination) async {
    final clean = destination.trim();
    if (clean.isEmpty) return defaultLocation;
    if (clean.contains('Current Location') || clean.contains('GPS')) {
      return getCurrentLocation();
    }

    final key = clean.toLowerCase();
    if (_resolvedCache.containsKey(key)) {
      debugPrint('[LocationService] Instant cache/predefined hit for "$clean": ${_resolvedCache[key]}');
      return _resolvedCache[key]!;
    }

    // Check partial matches for known destinations (e.g. "Skardu Valley" -> "skardu")
    for (final entry in knownDestinations.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        debugPrint('[LocationService] Matched "$clean" to known destination "${entry.key}": ${entry.value}');
        _resolvedCache[key] = entry.value;
        return entry.value;
      }
    }

    // Query backend Gemini resolver for unknown/custom destinations
    final candidateHosts = ApiConfig.candidateHosts;
    final ports = [5000, 8000];

    for (final host in candidateHosts) {
      for (final port in ports) {
        final url = Uri.parse('http://$host:$port/api/v1/hotels/resolve-location');
        try {
          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'destination': clean}),
              )
              .timeout(const Duration(seconds: 6));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data is Map<String, dynamic> && data['success'] == true) {
              final lat = (data['latitude'] as num).toDouble();
              final lon = (data['longitude'] as num).toDouble();
              final point = GeoPoint(latitude: lat, longitude: lon, label: clean);
              _resolvedCache[key] = point;
              debugPrint('[LocationService] Gemini resolved coordinates for "$clean" -> ($lat, $lon)');
              return point;
            }
          }
        } catch (e) {
          debugPrint('[LocationService] Host $host:$port resolver error: $e');
        }
      }
    }

    // Fallback if backend is unreachable
    debugPrint('[LocationService] Warning: Could not resolve "$clean". Defaulting to Islamabad.');
    return GeoPoint(latitude: 33.6844, longitude: 73.0479, label: clean);
  }

  static GeoPoint? _lastKnownGps;

  /// Retrieves current device GPS coordinates using Geolocator.
  static Future<GeoPoint> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] GPS service disabled. Returning last known or default.');
        return _lastKnownGps ?? defaultLocation;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] GPS permission denied.');
          return _lastKnownGps ?? defaultLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] GPS permission denied forever.');
        return _lastKnownGps ?? defaultLocation;
      }

      // 1. Try instant last known GPS position
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        final point = GeoPoint(
          latitude: lastPos.latitude,
          longitude: lastPos.longitude,
          label: 'Current Location (GPS)',
        );
        _lastKnownGps = point;
        debugPrint('[LocationService] Acquired instant lastKnownPosition GPS: $point');
        return point;
      }

      // 2. Query high-accuracy position with generous timeout
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final gpsPoint = GeoPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        label: 'Current Location (GPS)',
      );
      _lastKnownGps = gpsPoint;
      debugPrint('[LocationService] Acquired real fresh GPS: $gpsPoint');
      return gpsPoint;
    } catch (e) {
      debugPrint('[LocationService] GPS acquisition error: $e.');
      return _lastKnownGps ?? defaultLocation;
    }
  }
}
