import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class Environment {
  static bool _isInitialized = false;

  static void _ensureInitialized() {
    if (!_isInitialized) {
      try {
        // On web, do nothing; main.dart intentionally skips loading .env and we
        // must not trigger an asset fetch for assets/.env.
        if (kIsWeb) {
          _isInitialized = true;
          return;
        }
        // For mobile/desktop, main.dart already loads .env on startup. We simply
        // mark initialized to avoid redundant work here.
        _isInitialized = true;
      } catch (_) {
        _isInitialized = true;
      }
    }
  }

  static String get whisperApiKey {
    _ensureInitialized();
    try {
      return dotenv.maybeGet('WHISPER_API_KEY') ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get geminiApiKey {
    _ensureInitialized();
    try {
      return dotenv.maybeGet('GEMINI_API_KEY') ?? '';
    } catch (_) {
      return '';
    }
  }

  static const bool autoTranscribeEnabled = true;
  static const bool autoGenerateAISummary = true;
  static const String defaultTranscriptionProvider = 'openai_whisper';

  static Future<void> load() async {
    try {
      // On web, do nothing; main.dart intentionally skips loading .env
      if (kIsWeb) {
        return;
      }
      await dotenv.load(fileName: '.env');
    } catch (e) {
      print('Error loading .env file: $e');
      // Do not set real API keys in source. Ensure a valid .env is present with
      // WHISPER_API_KEY and GEMINI_API_KEY. Optionally, set safe placeholders.
      dotenv.env['WHISPER_API_KEY'] = dotenv.env['WHISPER_API_KEY'] ?? '';
      dotenv.env['GEMINI_API_KEY'] = dotenv.env['GEMINI_API_KEY'] ?? '';
    }
  }
}