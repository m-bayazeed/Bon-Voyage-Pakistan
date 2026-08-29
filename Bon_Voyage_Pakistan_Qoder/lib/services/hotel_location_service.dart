import 'dart:math';

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
}

/// Service managing location coordinate resolution, device GPS simulation,
/// and distance/travel time calculations across Pakistan.
class HotelLocationService {
  /// Known city center coordinates across Pakistan.
  static const Map<String, GeoPoint> cityCoordinates = {
    'Islamabad': GeoPoint(latitude: 33.6844, longitude: 73.0479, label: 'Islamabad'),
    'Hunza': GeoPoint(latitude: 36.3167, longitude: 74.6500, label: 'Hunza Valley'),
    'Skardu': GeoPoint(latitude: 35.2971, longitude: 75.6333, label: 'Skardu'),
    'Gilgit': GeoPoint(latitude: 35.9208, longitude: 74.3144, label: 'Gilgit'),
    'Lahore': GeoPoint(latitude: 31.5204, longitude: 74.3587, label: 'Lahore'),
    'Swat / Mingora': GeoPoint(latitude: 34.7717, longitude: 72.3602, label: 'Swat Valley'),
    'Kalam': GeoPoint(latitude: 35.4909, longitude: 72.5878, label: 'Kalam Valley'),
    'Naran / Kaghan': GeoPoint(latitude: 34.9085, longitude: 73.6542, label: 'Naran Valley'),
    'Murree': GeoPoint(latitude: 33.9062, longitude: 73.3903, label: 'Murree Hills'),
    'Karachi': GeoPoint(latitude: 24.8607, longitude: 67.0011, label: 'Karachi'),
    'Gwadar': GeoPoint(latitude: 25.1264, longitude: 62.3225, label: 'Gwadar Coast'),
  };

  /// Default center if none provided (Islamabad Blue Area).
  static const GeoPoint defaultLocation = GeoPoint(
    latitude: 33.7180,
    longitude: 73.0538,
    label: 'Current Location',
  );

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
    return earthRadiusKm * c;
  }

  static double _toRadians(double degree) => degree * (pi / 180.0);

  /// Convert distance in KM to user-friendly formatted string.
  static String formatDistance(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Estimate road travel time based on distance.
  static String estimateTravelTime(double km) {
    if (km < 0.5) return '2 mins';
    if (km < 1.5) return '5 mins';
    if (km < 3.0) return '8 mins';
    if (km < 6.0) return '14 mins';
    if (km < 12.0) return '22 mins';
    if (km < 25.0) return '35 mins';
    final hours = (km / 40).ceil();
    return '$hours hr${hours > 1 ? 's' : ''}';
  }

  /// Get center coordinates for a requested city.
  static GeoPoint getCityCenter(String city) {
    for (final entry in cityCoordinates.entries) {
      if (city.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return defaultLocation;
  }

  /// Simulates / retrieves current live device GPS coordinates.
  /// Designed to swap with geolocator / Google Location API seamlessly.
  static Future<GeoPoint> getCurrentLocation() async {
    // Realistic GPS lock simulation delay
    await Future.delayed(const Duration(milliseconds: 300));
    return defaultLocation;
  }
}
