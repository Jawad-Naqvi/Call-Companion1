import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EnvService {
  static bool _isInitialized = false;

  static void _ensureInitialized() {
    // On web, do nothing; main.dart intentionally skips loading .env and we
    // must not trigger an asset fetch for assets/.env.
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }
    // For mobile/desktop, main.dart already loads .env on startup. We simply
    // mark initialized to avoid redundant work here.
    _isInitialized = true;
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

  static String get firebaseProjectId {
    _ensureInitialized();
    try {
      return dotenv.maybeGet('FIREBASE_PROJECT_ID') ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get firebaseStorageBucket {
    _ensureInitialized();
    try {
      return dotenv.maybeGet('FIREBASE_STORAGE_BUCKET') ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get neonConnectionString {
    _ensureInitialized();
    try {
      return dotenv.maybeGet('NEON_CONNECTION_STRING') ?? '';
    } catch (_) {
      return '';
    }
  }

  static bool get hasWhisperKey => whisperApiKey.isNotEmpty;
  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;
  static bool get hasAllApiKeys => hasWhisperKey && hasGeminiKey;

  static void printConfiguration() {
    print('=== Environment Configuration ===');
    print('Firebase Project ID: $firebaseProjectId');
    print('Firebase Storage Bucket: $firebaseStorageBucket');
    print('Whisper API Key: ${hasWhisperKey ? "✓ Configured" : "✗ Missing"}');
    print('Gemini API Key: ${hasGeminiKey ? "✓ Configured" : "✗ Missing"}');
    print('Neon DB: ${neonConnectionString.isNotEmpty ? "✓ Configured" : "✗ Missing"}');
    print('================================');
  }
}
