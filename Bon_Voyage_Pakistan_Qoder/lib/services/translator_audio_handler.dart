import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Dedicated audio controller for STT recording and neural TTS playback.
class TranslatorAudioHandler {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Stream to listen when audio playback finishes.
  Stream<void> get onPlayerComplete => _audioPlayer.onPlayerComplete;

  /// Starts recording microphone audio into a temporary `.m4a` file.
  Future<void> startRecording() async {
    if (_isRecording) return;

    // 1. Request OS level permission via permission_handler
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        throw Exception(
          'Microphone permission is permanently denied. Please enable it in app settings.',
        );
      }
      throw Exception('Microphone permission denied.');
    }

    // 2. Double check recorder permission
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Audio recording permission is not available on device.');
    }

    // 3. Create unique temporary file path
    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/voice_record_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // 4. Start AAC encoder recording
    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    _isRecording = true;
  }

  /// Stops current recording and returns the path to the temporary `.m4a` file.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      _isRecording = false;
      debugPrint('Error stopping audio recorder: $e');
      rethrow;
    }
  }

  /// Plays decoded Base64 MP3 audio (supports raw Base64 and data URI prefix).
  Future<void> playBase64Audio(String base64Audio) async {
    final trimmed = base64Audio.trim();
    if (trimmed.isEmpty) return;

    // Handle data:audio/mpeg;base64,... prefix defensively
    final cleanBase64 =
        trimmed.contains(',') ? trimmed.split(',').last.trim() : trimmed;

    try {
      final bytes = base64Decode(cleanBase64);
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('Audio playback error: $e');
      throw Exception('Failed to play audio: $e');
    }
  }

  /// Stops currently playing audio.
  Future<void> stopPlayback() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping audio playback: $e');
    }
  }

  /// Safely cleans up temporary audio file from device storage.
  static Future<void> cleanupTempFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Could not delete temporary audio file $filePath: $e');
    }
  }

  /// Disposes recorder and player resources.
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}
