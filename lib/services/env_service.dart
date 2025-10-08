import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvService {
  static String get whisperApiKey => dotenv.env['WHISPER_API_KEY'] ?? '';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseStorageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get neonConnectionString => dotenv.env['NEON_CONNECTION_STRING'] ?? '';
  
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
