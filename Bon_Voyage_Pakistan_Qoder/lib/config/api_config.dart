/// Central API configuration for Bon Voyage Pakistan.
///
/// Change [baseUrl] when deploying or switching environments.
/// For Android Emulator talking to Flask on the host machine, use 10.0.2.2.
class ApiConfig {
  ApiConfig._(); // Prevent instantiation

  /// Base URL of the Flask backend.
  /// - Android Emulator: http://10.0.2.2:5000
  /// - Physical device on LAN: http://<your-pc-ip>:5000
  /// - Production: https://your-domain.com
  static const String baseUrl = 'http://192.168.100.12:5000';

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
}
