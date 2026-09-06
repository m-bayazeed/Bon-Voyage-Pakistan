import 'package:flutter/material.dart';

/// Data model representing live real-time weather and situational road travel conditions.
class WeatherData {
  final bool success;
  final String city;
  final double temperature;
  final double feelsLike;
  final String condition;
  final String description;
  final String iconUrl;
  final int humidity;
  final double windSpeedKmh;
  final int? pressure;
  final String travelAdvisory;
  final bool isFavorable;
  final String advisoryLevel;
  final double? latitude;
  final double? longitude;

  const WeatherData({
    required this.success,
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.description,
    required this.iconUrl,
    required this.humidity,
    required this.windSpeedKmh,
    this.pressure,
    required this.travelAdvisory,
    this.isFavorable = true,
    this.advisoryLevel = 'favorable',
    this.latitude,
    this.longitude,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      success: json['success'] as bool? ?? true,
      city: json['city'] as String? ?? 'Pakistan',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 25.0,
      feelsLike: (json['feels_like'] as num?)?.toDouble() ?? 25.0,
      condition: json['condition'] as String? ?? 'Clear',
      description: json['description'] as String? ?? 'Clear sky',
      iconUrl: json['icon_url'] as String? ??
          'https://openweathermap.org/img/wn/01d@2x.png',
      humidity: (json['humidity'] as num?)?.toInt() ?? 50,
      windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble() ?? 10.0,
      pressure: (json['pressure'] as num?)?.toInt(),
      travelAdvisory: json['travel_advisory'] as String? ??
          'Optimal road visibility and favorable travel conditions across highways and scenic routes.',
      isFavorable: json['is_favorable'] as bool? ?? true,
      advisoryLevel: json['advisory_level'] as String? ?? 'favorable',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Color accents based on condition
  Color get conditionColor {
    final c = condition.toLowerCase();
    if (c.contains('rain') || c.contains('drizzle')) return const Color(0xFF0284C7);
    if (c.contains('thunder')) return const Color(0xFFDC2626);
    if (c.contains('snow')) return const Color(0xFF38BDF8);
    if (c.contains('cloud')) return const Color(0xFF64748B);
    if (c.contains('fog') || c.contains('mist') || c.contains('haze')) return const Color(0xFFD97706);
    return const Color(0xFFEAB308); // Sunny / Clear
  }

  /// Advisory badge accent color
  Color get advisoryColor {
    switch (advisoryLevel.toLowerCase()) {
      case 'alert':
        return const Color(0xFFDC2626); // Red
      case 'moderate':
        return const Color(0xFFD97706); // Amber
      case 'favorable':
      default:
        return const Color(0xFF059669); // Emerald Green
    }
  }

  /// Advisory badge background color
  Color get advisoryBackgroundColor {
    switch (advisoryLevel.toLowerCase()) {
      case 'alert':
        return const Color(0xFFFEF2F2); // Soft red
      case 'moderate':
        return const Color(0xFFFFFBEB); // Soft amber
      case 'favorable':
      default:
        return const Color(0xFFECFDF5); // Soft green
    }
  }
}
