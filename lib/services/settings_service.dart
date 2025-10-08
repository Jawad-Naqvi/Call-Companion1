import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_companion/services/env_service.dart';

class SettingsService {
  static const String _keyWhisperApiKey = 'whisper_api_key';
  static const String _keyGeminiApiKey = 'gemini_api_key';
  static const String _keyAutoTranscribe = 'auto_transcribe';
  static const String _keyAutoGenerateSummary = 'auto_generate_summary';
  static const String _keyTranscriptionProvider = 'transcription_provider';

  Future<void> saveWhisperApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWhisperApiKey, apiKey);
  }

  Future<String?> getWhisperApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_keyWhisperApiKey);
    // Return saved key or fallback to environment variable
    return savedKey?.isNotEmpty == true ? savedKey : EnvService.whisperApiKey;
  }

  Future<void> saveGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGeminiApiKey, apiKey);
  }

  Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_keyGeminiApiKey);
    // Return saved key or fallback to environment variable
    return savedKey?.isNotEmpty == true ? savedKey : EnvService.geminiApiKey;
  }

  Future<void> setAutoTranscribe(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoTranscribe, enabled);
  }

  Future<bool> getAutoTranscribe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoTranscribe) ?? false;
  }

  Future<void> setAutoGenerateSummary(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoGenerateSummary, enabled);
  }

  Future<bool> getAutoGenerateSummary() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoGenerateSummary) ?? false;
  }

  Future<void> setTranscriptionProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTranscriptionProvider, provider);
  }

  Future<String> getTranscriptionProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTranscriptionProvider) ?? 'whisper';
  }

  Future<void> clearAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> hasApiKeys() async {
    final whisperKey = await getWhisperApiKey();
    final geminiKey = await getGeminiApiKey();
    return whisperKey != null && geminiKey != null;
  }
}
