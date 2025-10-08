import 'package:call_companion/models/call.dart';
import 'package:call_companion/models/transcript.dart';
import 'package:call_companion/models/ai_summary.dart';
import 'package:call_companion/services/transcription_service.dart';
import 'package:call_companion/services/ai_service.dart';
import 'package:call_companion/services/call_service.dart';
import 'package:call_companion/services/settings_service.dart';

/// Service to automatically process calls after recording
/// Handles transcription and AI summary generation
class CallProcessingService {
  final TranscriptionService _transcriptionService = TranscriptionService();
  final AIService _aiService = AIService(useMockData: true);
  final CallService _callService = CallService();
  final SettingsService _settingsService = SettingsService();

  /// Process a completed call: transcribe and generate AI summary
  Future<CallProcessingResult> processCall(Call call) async {
    final result = CallProcessingResult(
      callId: call.id,
      success: false,
    );

    try {
      // Check if auto-processing is enabled
      final autoTranscribe = await _settingsService.getAutoTranscribe();
      final autoSummary = await _settingsService.getAutoGenerateSummary();

      if (!autoTranscribe && !autoSummary) {
        result.message = 'Auto-processing disabled';
        return result;
      }

      // Get API keys
      final whisperKey = await _settingsService.getWhisperApiKey();
      final geminiKey = await _settingsService.getGeminiApiKey();

      // Step 1: Transcribe the call
      Transcript? transcript;
      if (autoTranscribe && whisperKey != null && whisperKey.isNotEmpty) {
        print('Starting transcription for call ${call.id}...');
        
        await _callService.updateCallStatus(call.id, CallStatus.transcribing);
        
        final provider = await _settingsService.getTranscriptionProvider();
        transcript = await _transcriptionService.transcribeCall(
          call,
          whisperKey,
          provider: provider,
        );

        if (transcript != null) {
          result.transcript = transcript;
          result.transcriptionSuccess = true;
          await _callService.markCallAsTranscribed(call.id);
          print('Transcription completed for call ${call.id}');
        } else {
          result.transcriptionError = 'Failed to generate transcript';
          print('Transcription failed for call ${call.id}');
        }
      } else {
        result.transcriptionError = 'Auto-transcribe disabled or API key missing';
      }

      // Step 2: Generate AI summary
      if (autoSummary && 
          transcript != null && 
          geminiKey != null && 
          geminiKey.isNotEmpty) {
        print('Starting AI summary generation for call ${call.id}...');
        
        final summary = await _aiService.generateCallSummary(
          transcript,
          apiKey: geminiKey,
        );

        if (summary != null) {
          result.aiSummary = summary;
          result.summarySuccess = true;
          await _callService.markCallAsAnalyzed(call.id);
          print('AI summary completed for call ${call.id}');
        } else {
          result.summaryError = 'Failed to generate AI summary';
          print('AI summary failed for call ${call.id}');
        }
      } else {
        result.summaryError = 'Auto-summary disabled, no transcript, or API key missing';
      }

      // Overall success if at least one step succeeded
      result.success = result.transcriptionSuccess || result.summarySuccess;
      result.message = _buildResultMessage(result);

      return result;
    } catch (e) {
      print('Error processing call ${call.id}: $e');
      result.success = false;
      result.message = 'Error: $e';
      return result;
    }
  }

  String _buildResultMessage(CallProcessingResult result) {
    final messages = <String>[];

    if (result.transcriptionSuccess) {
      messages.add('Transcription completed');
    } else if (result.transcriptionError != null) {
      messages.add('Transcription: ${result.transcriptionError}');
    }

    if (result.summarySuccess) {
      messages.add('AI summary generated');
    } else if (result.summaryError != null) {
      messages.add('Summary: ${result.summaryError}');
    }

    return messages.isEmpty ? 'No processing performed' : messages.join('. ');
  }

  /// Process multiple calls in batch
  Future<List<CallProcessingResult>> processCalls(List<Call> calls) async {
    final results = <CallProcessingResult>[];
    
    for (final call in calls) {
      final result = await processCall(call);
      results.add(result);
    }
    
    return results;
  }

  /// Check if a call needs processing
  Future<bool> needsProcessing(Call call) async {
    if (call.status != CallStatus.completed) {
      return false;
    }

    final autoTranscribe = await _settingsService.getAutoTranscribe();
    final autoSummary = await _settingsService.getAutoGenerateSummary();

    if (autoTranscribe && !call.hasTranscript) {
      return true;
    }

    if (autoSummary && !call.hasAISummary) {
      return true;
    }

    return false;
  }
}

class CallProcessingResult {
  final String callId;
  bool success;
  String? message;
  
  Transcript? transcript;
  bool transcriptionSuccess = false;
  String? transcriptionError;
  
  AISummary? aiSummary;
  bool summarySuccess = false;
  String? summaryError;

  CallProcessingResult({
    required this.callId,
    required this.success,
    this.message,
  });

  @override
  String toString() {
    return 'CallProcessingResult(callId: $callId, success: $success, message: $message)';
  }
}
