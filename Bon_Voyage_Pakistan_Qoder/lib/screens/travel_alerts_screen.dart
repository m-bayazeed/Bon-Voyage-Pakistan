import 'package:flutter/material.dart';
import 'weather_screen.dart';

/// Travel Notifications & Emergency Alerts Screen for Bon Voyage Pakistan.
/// Migrated to live, real-time OpenWeatherMap weather and travel road conditions.
class TravelAlertsScreen extends StatelessWidget {
  final String? initialCity;

  const TravelAlertsScreen({super.key, this.initialCity});

  @override
  Widget build(BuildContext context) {
    return WeatherScreen(initialCity: initialCity);
  }
}
