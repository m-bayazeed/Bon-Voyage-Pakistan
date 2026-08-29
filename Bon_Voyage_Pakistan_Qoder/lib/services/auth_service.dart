import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/user.dart';

/// Handles all authentication-related API calls and secure token storage.
///
/// Every HTTP request uses a 15-second timeout to prevent the app from
/// hanging indefinitely when the backend is unreachable.
class AuthService {
  // Secure on-device storage for the JWT token and cached user info.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Timeout applied to every HTTP request so the UI never hangs forever.
  static const Duration _requestTimeout = Duration(seconds: 15);

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';

  // ──────────────────────────────────────────
  // Token Storage Helpers
  // ──────────────────────────────────────────

  /// Retrieve the stored JWT token, or null if none exists.
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Store a JWT token securely on the device.
  static Future<void> _saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Save basic user info locally for quick display without a network call.
  static Future<void> saveUserLocally(User user) async {
    await _storage.write(key: _userIdKey, value: user.id.toString());
    await _storage.write(key: _userNameKey, value: user.name);
    await _storage.write(key: _userEmailKey, value: user.email);
  }

  /// Read the locally cached user ID.
  static Future<int?> getUserId() async {
    final idStr = await _storage.read(key: _userIdKey);
    return idStr != null ? int.tryParse(idStr) : null;
  }

  /// Read the locally cached user name.
  static Future<String?> getUserName() async {
    return await _storage.read(key: _userNameKey);
  }

  /// Read the locally cached user email.
  static Future<String?> getUserEmail() async {
    return await _storage.read(key: _userEmailKey);
  }

  /// Clear all locally stored auth data (token + cached user info).
  static Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _userEmailKey);
  }

  // ──────────────────────────────────────────
  // API Calls
  // ──────────────────────────────────────────

  /// Register a new user account.
  ///
  /// Sends name, email, and password to the backend.  On success the backend
  /// returns a JWT which is stored securely on-device together with the user
  /// profile.  Returns a map with {success, message, user?, token?}.
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      developer.log('POST ${ApiConfig.signup}', name: 'AuthService');

      final response = await http
          .post(
            Uri.parse(ApiConfig.signup),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // If signup succeeded, persist the token and user info locally.
      if (data['success'] == true && data['token'] != null) {
        await _saveToken(data['token'] as String);
        if (data['user'] != null) {
          final user = User.fromJson(data['user'] as Map<String, dynamic>);
          await saveUserLocally(user);
        }
      }

      return data;
    } on TimeoutException {
      developer.log('Signup request timed out', name: 'AuthService');
      return _timeoutError();
    } on http.ClientException catch (e) {
      developer.log('Signup connection error: $e', name: 'AuthService');
      return _connectionError();
    } catch (e) {
      developer.log('Signup error: $e', name: 'AuthService');
      return _genericError(e);
    }
  }

  /// Authenticate an existing user.
  ///
  /// Sends email + password, verifies against the backend hash, and on
  /// success stores the returned JWT.  Returns {success, message, user?, token?}.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      developer.log('POST ${ApiConfig.login}', name: 'AuthService');

      final response = await http
          .post(
            Uri.parse(ApiConfig.login),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // If login succeeded, persist the token and user info locally.
      if (data['success'] == true && data['token'] != null) {
        await _saveToken(data['token'] as String);
        if (data['user'] != null) {
          final user = User.fromJson(data['user'] as Map<String, dynamic>);
          await saveUserLocally(user);
        }
      }

      return data;
    } on TimeoutException {
      developer.log('Login request timed out', name: 'AuthService');
      return _timeoutError();
    } on http.ClientException catch (e) {
      developer.log('Login connection error: $e', name: 'AuthService');
      return _connectionError();
    } catch (e) {
      developer.log('Login error: $e', name: 'AuthService');
      return _genericError(e);
    }
  }

  /// Verify the stored token by calling GET /auth/me.
  ///
  /// Returns the [User] if the token is still valid, or `null` when the
  /// token is missing, expired, or invalid.  On network errors the token
  /// is NOT cleared so the user can retry later.
  static Future<User?> verifyToken() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.me),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true && data['user'] != null) {
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        await saveUserLocally(user);
        return user;
      }

      // Token is invalid or expired — remove it locally.
      await clearAll();
      return null;
    } on TimeoutException {
      // Network timeout — keep token so user can retry later.
      developer.log('Token verification timed out', name: 'AuthService');
      return null;
    } catch (e) {
      developer.log('Token verification error: $e', name: 'AuthService');
      return null;
    }
  }

  /// Update the authenticated user's display name.
  ///
  /// Sends the new name to the backend and updates local secure storage.
  static Future<Map<String, dynamic>> updateUsername(String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      return {'success': false, 'message': 'Username cannot be empty'};
    }

    final token = await getToken();

    // 1. If token is available, attempt remote backend update
    if (token != null) {
      try {
        developer.log('POST ${ApiConfig.changeUsername}', name: 'AuthService');
        final response = await http
            .post(
              Uri.parse(ApiConfig.changeUsername),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'name': trimmedName}),
            )
            .timeout(_requestTimeout);

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          await _storage.write(key: _userNameKey, value: trimmedName);
          developer.log('USERNAME UPDATED: $trimmedName', name: 'AuthService');
          return data;
        } else {
          return data;
        }
      } on TimeoutException {
        developer.log('Username update timed out, saving locally', name: 'AuthService');
        await _storage.write(key: _userNameKey, value: trimmedName);
        return {
          'success': true,
          'message': 'Username updated locally (Server timeout)',
        };
      } on http.ClientException catch (e) {
        developer.log('Username update network error: $e, saving locally', name: 'AuthService');
        await _storage.write(key: _userNameKey, value: trimmedName);
        return {
          'success': true,
          'message': 'Username updated locally (Offline mode)',
        };
      } catch (e) {
        developer.log('USERNAME UPDATE ERROR: $e', name: 'AuthService');
        return _genericError(e);
      }
    } else {
      // Guest or local mode
      await _storage.write(key: _userNameKey, value: trimmedName);
      return {'success': true, 'message': 'Username updated successfully'};
    }
  }

  /// Change the user's password securely after verifying their current password.
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) {
      return {'success': false, 'message': 'Current password is required'};
    }
    if (newPassword.isEmpty) {
      return {'success': false, 'message': 'New password is required'};
    }
    if (newPassword.length < 8) {
      return {'success': false, 'message': 'New password must be at least 8 characters'};
    }

    final token = await getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'User session not found. Please log in again.',
      };
    }

    try {
      developer.log('POST ${ApiConfig.changePassword}', name: 'AuthService');
      final response = await http
          .post(
            Uri.parse(ApiConfig.changePassword),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        developer.log('PASSWORD CHANGED: Successfully updated', name: 'AuthService');
      } else {
        developer.log('PASSWORD CHANGE ERROR: ${data['message']}', name: 'AuthService');
      }
      return data;
    } on TimeoutException {
      developer.log('Password change timed out', name: 'AuthService');
      return _timeoutError();
    } on http.ClientException catch (e) {
      developer.log('Password change network error: $e', name: 'AuthService');
      return _connectionError();
    } catch (e) {
      developer.log('PASSWORD CHANGE ERROR: $e', name: 'AuthService');
      return _genericError(e);
    }
  }

  /// Log out: notify backend (best-effort), then clear all local auth data.
  static Future<void> logout() async {
    final token = await getToken();

    // Best-effort call to backend — don't block on failure.
    if (token != null) {
      try {
        await http
            .post(
              Uri.parse(ApiConfig.logout),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(_requestTimeout);
      } catch (e) {
        developer.log('LOGOUT ERROR (backend notification): $e', name: 'AuthService');
      }
    }

    await clearAll();
  }

  // ──────────────────────────────────────────
  // Error Response Helpers
  // ──────────────────────────────────────────

  /// Returned when the HTTP request exceeds [_requestTimeout].
  static Map<String, dynamic> _timeoutError() {
    return {
      'success': false,
      'message':
          'The server took too long to respond. Please check that the backend is running and try again.',
    };
  }

  /// Returned when the device cannot reach the backend at all.
  static Map<String, dynamic> _connectionError() {
    return {
      'success': false,
      'message':
          'Cannot connect to the server. Make sure you are on the same Wi-Fi network and the backend is running.',
    };
  }

  /// Catch-all for unexpected errors (JSON parse failures, etc.).
  static Map<String, dynamic> _genericError(Object error) {
    return {
      'success': false,
      'message': 'Something went wrong. Please try again.',
    };
  }
}
