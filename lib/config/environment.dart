import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get whisperApiKey => dotenv.get('WHISPER_API_KEY');
  static String get geminiApiKey => dotenv.get('GEMINI_API_KEY');
  
  static const bool autoTranscribeEnabled = true;
  static const bool autoGenerateAISummary = true;
  static const String defaultTranscriptionProvider = 'openai_whisper';

  static Future<void> load() async {
    try {
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