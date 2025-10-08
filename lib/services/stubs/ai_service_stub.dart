import 'package:call_companion/models/ai_summary.dart';
import 'package:call_companion/models/transcript.dart';
import 'package:call_companion/models/chat_message.dart';

class AIService {
  Future<AISummary?> generateCallSummary(Transcript transcript, String apiKey) async => null;

  Future<String?> generateAIResponse(String userMessage, String customerId, String employeeId, String apiKey) async => null;

  Future<AISummary?> getAISummaryByCallId(String callId) async => null;

  Future<List<AISummary>> getAISummariesByCustomer(String customerId) async => [];

  Future<List<ChatMessage>> getChatMessagesByCustomer(String customerId, String employeeId) async => [];
}
