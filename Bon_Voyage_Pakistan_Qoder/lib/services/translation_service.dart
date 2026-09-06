library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/translation_model.dart';

/// Real-time live AI translation engine for tourists in Pakistan.
class TranslationService {
  /// Auto Detect option.
  static const LanguageOption autoDetect = LanguageOption(
    code: 'auto',
    name: 'Auto Detect',
    nativeName: 'Auto Detect',
    flag: '🌐',
  );

  /// Target output languages (Urdu as default, English).
  static const List<LanguageOption> targetLanguages = [
    LanguageOption(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      flag: '🇵🇰',
      isPakistaniRegional: true,
    ),
    LanguageOption(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
    ),
  ];

  /// All supported source languages with Auto Detect first.
  static const List<LanguageOption> sourceLanguages = [
    autoDetect,
    LanguageOption(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
    ),
    LanguageOption(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      flag: '🇵🇰',
      isPakistaniRegional: true,
    ),
    LanguageOption(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
    ),
    LanguageOption(
      code: 'zh',
      name: 'Chinese (Mandarin)',
      nativeName: '中文',
      flag: '🇨🇳',
    ),
    LanguageOption(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      flag: '🇷🇺',
    ),
    LanguageOption(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
    LanguageOption(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
    ),
    LanguageOption(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
    ),
  ];

  /// Alias for backward compatibility.
  static const List<LanguageOption> supportedLanguages = sourceLanguages;

  /// Find language option by code.
  static LanguageOption getLanguage(String code) {
    if (code.toLowerCase() == 'auto') return autoDetect;
    return sourceLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => autoDetect,
    );
  }

  /// Helper to get potential endpoint candidate URLs (Flask 5000 & FastAPI 8000 across candidate hosts)
  static List<String> _getTextEndpoints() {
    final urls = <String>[];
    for (final host in ApiConfig.candidateHosts) {
      urls.add('http://$host:5000/api/v1/translate/text');
      urls.add('http://$host:8000/api/v1/translate/text');
    }
    return urls;
  }

  static List<String> _getVoiceEndpoints() {
    final urls = <String>[];
    for (final host in ApiConfig.candidateHosts) {
      urls.add('http://$host:5000/api/v1/translate/voice');
      urls.add('http://$host:8000/api/v1/translate/voice');
    }
    return urls;
  }

  static List<String> _getSynthesizeEndpoints() {
    final urls = <String>[];
    for (final host in ApiConfig.candidateHosts) {
      urls.add('http://$host:5000/api/v1/translate/synthesize');
      urls.add('http://$host:8000/api/v1/translate/synthesize');
    }
    return urls;
  }

  /// Live text translation via FastAPI / Flask backend.
  static Future<Map<String, String>> translateText({
    required String text,
    required String sourceCode,
    required String targetCode,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return {'translated': '', 'romanized': '', 'audio_base64': ''};
    }

    final normalizedTarget = (targetCode == 'ur' || targetCode == 'en') ? targetCode : 'ur';
    final endpoints = _getTextEndpoints();
    String lastError = '';

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'text': trimmed,
                'source_language': sourceCode,
                'target_language': normalizedTarget,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['success'] == true) {
            return {
              'translated': data['translated_text']?.toString() ?? '',
              'romanized': data['romanized_pronunciation']?.toString() ?? '',
              'source_romanized': data['source_romanized_pronunciation']?.toString() ?? '',
              'audio_base64': data['audio_base64']?.toString() ?? '',
              'detected_language': (data['detected_source_language'] ?? data['detected_language'] ?? '').toString(),
            };
          }
        }

        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          lastError = errorData['error'] ?? 'Server error ${response.statusCode}';
        } catch (_) {
          lastError = 'HTTP ${response.statusCode} from $endpoint';
        }
      } catch (e) {
        lastError = e.toString();
        // Continue loop to try fallback endpoint
      }
    }

    return {
      'translated': 'Network error: Cannot reach translation server. Please check that backend/app.py is running. ($lastError)',
      'romanized': '',
      'source_romanized': '',
      'audio_base64': '',
    };
  }

  /// Live voice translation: uploads recorded audio file to backend for Groq Whisper + Gemini + Edge TTS.
  static Future<Map<String, String>> translateVoiceFile({
    required String filePath,
    required String sourceCode,
    required String targetCode,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return {
        'translated': 'Error: Recorded audio file not found on device.',
        'romanized': '',
        'source_romanized': '',
        'transcript': '',
        'audio_base64': '',
      };
    }

    final normalizedTarget = (targetCode == 'ur' || targetCode == 'en') ? targetCode : 'ur';
    final endpoints = _getVoiceEndpoints();
    String lastError = '';

    for (final endpoint in endpoints) {
      try {
        final request = http.MultipartRequest('POST', Uri.parse(endpoint));
        request.fields['source_language'] = sourceCode;
        request.fields['target_language'] = normalizedTarget;
        request.files.add(await http.MultipartFile.fromPath('audio_file', filePath));

        final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['success'] == true) {
            return {
              'translated': data['translated_text']?.toString() ?? '',
              'romanized': data['romanized_pronunciation']?.toString() ?? '',
              'source_romanized': data['source_romanized_pronunciation']?.toString() ?? '',
              'transcript': data['transcript']?.toString() ?? '',
              'audio_base64': data['audio_base64']?.toString() ?? '',
              'detected_language': (data['detected_source_language'] ?? data['detected_language'] ?? '').toString(),
            };
          }
        }

        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          lastError = errorData['error'] ?? 'Voice translation failed';
        } catch (_) {
          lastError = 'HTTP ${response.statusCode} from $endpoint';
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    return {
      'translated': 'Voice translation error: $lastError',
      'romanized': '',
      'transcript': '',
      'audio_base64': '',
    };
  }

  /// Synthesizes neural TTS for a given text and language (Urdu 'ur' or English 'en').
  static Future<String> synthesizeSpeech({
    required String text,
    required String languageCode,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return '';

    final normalizedLang = (languageCode == 'ur' || languageCode == 'en') ? languageCode : 'ur';
    final endpoints = _getSynthesizeEndpoints();

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'text': cleanText,
                'language': normalizedLang,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['success'] == true) {
            return data['audio_base64']?.toString() ?? '';
          }
        }
      } catch (_) {
        // Fallback to next endpoint
      }
    }
    return '';
  }
}


