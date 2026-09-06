/// Central API configuration for Bon Voyage Pakistan.
///
/// Can be configured dynamically via:
/// `--dart-define=WIFI_IP=<your_lan_ip>`
/// `--dart-define=BACKEND_HOST=<host_or_ip>`
/// `--dart-define=FASTAPI_PORT=8000` (or 8080)
class ApiConfig {
  ApiConfig._(); // Prevent instantiation

  static const String _envHost = String.fromEnvironment(
    'BACKEND_HOST',
    defaultValue: String.fromEnvironment('WIFI_IP', defaultValue: ''),
  );

  static const int port = int.fromEnvironment(
    'FASTAPI_PORT',
    defaultValue: 8000,
  );

  /// Primary default host
  static String get host {
    if (_envHost.isNotEmpty) return _envHost;
    // Default to 127.0.0.1 (optimal for adb reverse, macOS, Windows, Linux, iOS)
    return '127.0.0.1';
  }

  /// Candidate host list for multi-target fallback:
  /// 1. 127.0.0.1 (Fast-path for USB ADB Reverse, Desktop, iOS Simulator, Web)
  /// 2. Configured Host / Wi-Fi IP (via --dart-define=WIFI_IP=... or BACKEND_HOST=...)
  /// 3. 10.0.2.2 (Works for Android Emulator)
  static List<String> get candidateHosts {
    final list = <String>[];
    void addHost(String h) {
      final clean = h.trim();
      if (clean.isNotEmpty && !list.contains(clean)) {
        list.add(clean);
      }
    }

    // 1. Fast-path for USB (adb reverse) & local machine
    addHost('127.0.0.1');

    // 2. Configured Host / Wi-Fi IP
    if (_envHost.isNotEmpty && _envHost != '127.0.0.1') {
      addHost(_envHost);
    }

    // 3. Android Emulator fallback
    addHost('10.0.2.2');

    return list;
  }

  /// Candidate ports to try for backend connectivity (Primary port first, then fallback port)
  static List<int> get candidatePorts {
    if (port == 8000) {
      return const [8000, 8080];
    } else if (port == 8080) {
      return const [8080, 8000];
    }
    return [port, 8000, 8080];
  }

  /// Base URL of the Flask backend (Auth & Trip planning on Port 5000).
  static String get baseUrl => 'http://${host}:5000';

  // ── Auth endpoints ──
  static String get signup => '$baseUrl/auth/signup';
  static String get login => '$baseUrl/auth/login';
  static String get me => '$baseUrl/auth/me';
  static String get changeUsername => '$baseUrl/auth/change-username';
  static String get changePassword => '$baseUrl/auth/change-password';
  static String get logout => '$baseUrl/auth/logout';

  // ── AI Trip Planning endpoints (Groq AI) ──
  static String get generateTripPlan => '$baseUrl/trip/generate-plan';
  static String get chatTripPlan => '$baseUrl/trip/chat';

  // ── Translator endpoints (FastAPI on Port 8000/8080) ──
  static String get translatorBaseUrl => 'http://${host}:$port';
  static String get translateText => '$translatorBaseUrl/api/v1/translate/text';
  static String get translateVoice => '$translatorBaseUrl/api/v1/translate/voice';
  static String get translateSynthesize => '$translatorBaseUrl/api/v1/translate/synthesize';

  // ── Hotels & Stays endpoints (FastAPI on Port 8000/8080) ──
  static String get hotelsBaseUrl => 'http://${host}:$port';
  static String get hotelsSearch => '$hotelsBaseUrl/api/v1/hotels/search';
  static String get hotelsCities => '$hotelsBaseUrl/api/v1/hotels/cities';
  static String get hotelsGeocode => '$hotelsBaseUrl/api/v1/hotels/geocode';
  static String get hotelsResolveLocation => '$hotelsBaseUrl/api/v1/hotels/resolve-location';

  // ── Food & Dining endpoints (FastAPI on Port 8000/8080) ──
  static String get foodBaseUrl => 'http://${host}:$port';
  static String get foodSearch => '$foodBaseUrl/api/v1/food/search';

  // ── First Aid & Medical Help endpoints (FastAPI on Port 8000/8080) ──
  static String get helpBaseUrl => 'http://${host}:$port';
  static String get helpSearch => '$helpBaseUrl/api/v1/help/search';

  // ── Central Google Routes endpoint (FastAPI on Port 8000/8080) ──
  static String get routesBaseUrl => 'http://${host}:$port';
  static String get routesCompute => '$routesBaseUrl/api/v1/routes';

  // ── Scan & Search Landmarks endpoint (FastAPI on Port 8000/8080) ──
  static String get landmarksBaseUrl => 'http://${host}:$port';
  static String get landmarksScan => '$landmarksBaseUrl/api/v1/landmarks/scan';
  static String get landmarksStoryAudio => '$landmarksBaseUrl/api/v1/tts/story';

  // ── Notifications & Travel Advisories endpoints (FastAPI on Port 8000/8080) ──
  static String get notificationsBaseUrl => 'http://${host}:$port';
  static String get notificationsFeed => '$notificationsBaseUrl/api/v1/notifications';
  static String get notificationsSync => '$notificationsBaseUrl/api/v1/notifications/sync';
}
