import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bon_voyage_pakistan/config/api_config.dart';
import 'package:bon_voyage_pakistan/models/travel_alert_model.dart';
import 'package:bon_voyage_pakistan/services/travel_alert_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TravelAlert Model & Static Offline Fallback Tests', () {
    test('Static offline fallback advisories are populated and valid', () {
      final fallbacks = BackendAlertDataProvider.staticOfflineAdvisories;
      expect(fallbacks, isNotEmpty);
      expect(fallbacks.length, greaterThanOrEqualTo(4));

      for (final a in fallbacks) {
        expect(a.id, isNotEmpty);
        expect(a.title, isNotEmpty);
        expect(a.description, isNotEmpty);
        expect(a.source, contains('Offline Fallback'));
        expect(a.details?['is_offline_fallback'], isTrue);
      }
    });

    test('loadCachedAlerts returns static offline advisories on cold start without backend', () async {
      SharedPreferences.setMockInitialValues({});

      final alerts = await BackendAlertDataProvider.loadCachedAlerts();
      expect(alerts, isNotEmpty);
      expect(alerts.length, greaterThanOrEqualTo(4));
      expect(alerts.any((a) => a.city == 'Hunza Valley'), isTrue);
    });

    test('loadCachedAlerts filters offline fallbacks by city correctly', () async {
      SharedPreferences.setMockInitialValues({});

      final hunzaAlerts = await BackendAlertDataProvider.loadCachedAlerts(city: 'Hunza Valley');
      expect(hunzaAlerts, isNotEmpty);
      // Includes Hunza and National bulletins
      expect(hunzaAlerts.every((a) => a.city == 'Hunza Valley' || a.city == 'All Pakistan' || a.city == 'National'), isTrue);
    });

    test('Candidate hosts list prioritizes 127.0.0.1 and 10.0.2.2 correctly', () {
      final hosts = ApiConfig.candidateHosts;
      expect(hosts, contains('127.0.0.1'));
      expect(hosts, contains('10.0.2.2'));
    });
  });

  group('Live FastAPI Backend Notifications Serialization Integration', () {
    test('Real FastAPI server responds with valid JSON matching Flutter model', () async {
      HttpOverrides.global = null;
      final provider = BackendAlertDataProvider();
      final alerts = await provider.fetchAlerts();


      expect(alerts, isNotEmpty);
      expect(alerts.length, greaterThanOrEqualTo(5));

      final first = alerts.first;
      expect(first.id, isNotEmpty);
      expect(first.title, isNotEmpty);
      expect(first.severity, isA<AlertSeverity>());
      expect(first.type, isA<AlertCategory>());
    });
  });
}
