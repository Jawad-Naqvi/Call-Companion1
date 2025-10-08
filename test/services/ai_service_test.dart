import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:call_companion/services/ai_service.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockHttpClient extends Mock {}

void main() {
  late AIService aiService;
  late MockFirestore mockFirestore;
  late MockHttpClient mockHttpClient;

  setUp(() {
    mockFirestore = MockFirestore();
    mockHttpClient = MockHttpClient();
    aiService = AIService(useMockData: true);
  });

  group('AIService Tests', () {
    test('generateCallSummary should create summary successfully', () async {
      // Arrange
      const callId = 'test_call_id';
      const transcript = 'This is a test transcript for summarization';
      final mockResponse = {
        'summary': 'Test call summary',
        'action_items': ['Follow up with client', 'Send documentation'],
        'sentiment': 'positive'
      };

      // Mock Gemini API response
      when(mockHttpClient.post(any, body: any)).thenAnswer((_) async => mockResponse);

      // Act
      final result = await aiService.generateCallSummary(
        callId: callId,
        transcript: transcript
      );

      // Assert
      expect(result, isNotNull);
      expect(result['summary'], isNotEmpty);
      expect(result['action_items'], isNotEmpty);
      verify(mockFirestore.collection('calls').doc(callId).update(any)).called(1);
    });

    test('generateAIResponse should handle chat successfully', () async {
      // Arrange
      const customerId = 'test_customer_id';
      const userMessage = 'What were the main points from our last call?';
      final mockResponse = {
        'response': 'Here are the main points from your last call...',
        'context_used': true
      };

      // Mock Gemini API response
      when(mockHttpClient.post(any, body: any)).thenAnswer((_) async => mockResponse);

      // Act
      final result = await aiService.generateAIResponse(
        customerId: customerId,
        userMessage: userMessage
      );

      // Assert
      expect(result, isNotNull);
      expect(result['response'], isNotEmpty);
      verify(mockFirestore.collection('customers').doc(customerId)
        .collection('chat').add(any)).called(2);
    });

    test('generateAIResponse should handle errors gracefully', () async {
      // Arrange
      const customerId = 'test_customer_id';
      const userMessage = 'Test message';

      // Mock API error
      when(mockHttpClient.post(any, body: any)).thenThrow(Exception('API Error'));

      // Act & Assert
      expect(
        () => aiService.generateAIResponse(
          customerId: customerId,
          userMessage: userMessage
        ),
        throwsException
      );
    });
  });
}