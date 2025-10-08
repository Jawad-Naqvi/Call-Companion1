import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/screens/chat/ai_chat_screen.dart';
import 'package:call_companion/services/ai_service.dart';
import 'package:call_companion/models/customer.dart';
import 'package:call_companion/models/chat_message.dart';

class MockAIService extends Mock implements AIService {}

void main() {
  late MockAIService mockAIService;
  late Customer testCustomer;

  setUp(() {
    mockAIService = MockAIService();
    testCustomer = Customer(
      id: 'cust1',
      name: 'John Doe',
      phoneNumber: '+1234567890',
      email: 'john@example.com',
      lastContactDate: DateTime.now(),
      tags: ['VIP'],
      notes: 'Test customer'
    );

    // Setup mock chat history
    final mockChatHistory = [
      ChatMessage(
        id: 'msg1',
        customerId: testCustomer.id,
        content: 'Hello, how can I help you?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isAI: true
      ),
      ChatMessage(
        id: 'msg2',
        customerId: testCustomer.id,
        content: 'What was discussed in our last call?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
        isAI: false
      ),
      ChatMessage(
        id: 'msg3',
        customerId: testCustomer.id,
        content: 'In your last call, we discussed...',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        isAI: true
      )
    ];

    when(mockAIService.getChatHistory(testCustomer.id))
        .thenAnswer((_) async => mockChatHistory);

    when(mockAIService.generateAIResponse(
      customerId: testCustomer.id,
      userMessage: any,
    )).thenAnswer((_) async => {
      'response': 'This is a test AI response',
      'context_used': true
    });
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: Provider<AIService>.value(
        value: mockAIService,
        child: AIChatScreen(customer: testCustomer),
      ),
    );
  }

  group('AIChatScreen Widget Tests', () {
    testWidgets('should display chat history and input field',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ListView), findsOneWidget); // Chat messages list
      expect(find.byType(TextField), findsOneWidget); // Message input field
      expect(find.byType(IconButton), findsOneWidget); // Send button
      expect(find.text('Hello, how can I help you?'), findsOneWidget);
      expect(find.text('What was discussed in our last call?'), findsOneWidget);
    });

    testWidgets('should send message and display AI response',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(
        find.byType(TextField),
        'Can you summarize our previous interactions?'
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Assert
      verify(mockAIService.generateAIResponse(
        customerId: testCustomer.id,
        userMessage: 'Can you summarize our previous interactions?',
      )).called(1);
      expect(find.text('This is a test AI response'), findsOneWidget);
    });

    testWidgets('should show loading indicator while generating response',
        (WidgetTester tester) async {
      // Arrange
      when(mockAIService.generateAIResponse(
        customerId: any,
        userMessage: any,
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1));
        return {
          'response': 'Delayed response',
          'context_used': true
        };
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error message on AI service failure',
        (WidgetTester tester) async {
      // Arrange
      when(mockAIService.generateAIResponse(
        customerId: any,
        userMessage: any,
      )).thenThrow(Exception('API Error'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error: Failed to generate AI response'), findsOneWidget);
    });

    testWidgets('should clear input field after sending message',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test message'), findsNothing);
    });
  });
}