import 'package:call_companion/models/transcript.dart';
import 'package:call_companion/models/call.dart';

class TranscriptionService {
  Future<Transcript?> transcribeCall(Call call, String apiKey, {String provider = 'whisper'}) async => null;

  Future<Transcript?> getTranscriptByCallId(String callId) async => null;

  Future<List<Transcript>> getTranscriptsByCustomer(String customerId) async => [];

  Future<bool> deleteTranscript(String transcriptId) async => false;
}
