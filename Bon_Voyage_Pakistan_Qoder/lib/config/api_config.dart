/// Central API configuration for Bon Voyage Pakistan.
///
/// Can be overridden dynamically via `--dart-define=WIFI_IP=<your_ip>`.
class ApiConfig {
  ApiConfig._(); // Prevent instantiation

  static const String _host = String.fromEnvironment(
    'WIFI_IP',
    defaultValue: '192.168.100.12',
  );

  /// Candidate host list for multi-target fallback:
  /// 1. Configured Host / Wi-Fi IP
  /// 2. 127.0.0.1 (Works for USB ADB Reverse, Desktop, iOS Simulator)
  /// 3. 10.0.2.2 (Works for Android Emulator)
  /// 4. 192.168.100.12 (Default LAN Wi-Fi IP)
  static List<String> get candidateHosts {
    final list = <String>[];
    void addHost(String h) {
      final clean = h.trim();
      if (clean.isNotEmpty && !list.contains(clean)) {
        list.add(clean);
      }
    }

    addHost(_host);
    addHost('127.0.0.1');
    addHost('10.0.2.2');
    addHost('192.168.100.12');
    return list;
  }

  /// Base URL of the Flask backend (Auth & Trip planning on Port 5000).
  static const String baseUrl = 'http://$_host:5000';

  // ── Auth endpoints ──
  static const String signup = '$baseUrl/auth/signup';
  static const String login = '$baseUrl/auth/login';
  static const String me = '$baseUrl/auth/me';
  static const String changeUsername = '$baseUrl/auth/change-username';
  static const String changePassword = '$baseUrl/auth/change-password';
  static const String logout = '$baseUrl/auth/logout';

  // ── AI Trip Planning endpoints (Groq AI) ──
  static const String generateTripPlan = '$baseUrl/trip/generate-plan';
  static const String chatTripPlan = '$baseUrl/trip/chat';

  // ── Translator endpoints (FastAPI on Port 8000 / Flask on Port 5000) ──
  static const String translatorBaseUrl = 'http://$_host:8000';
  static const String translateText = '$translatorBaseUrl/api/v1/translate/text';
  static const String translateVoice = '$translatorBaseUrl/api/v1/translate/voice';
  static const String translateSynthesize = '$translatorBaseUrl/api/v1/translate/synthesize';
}

