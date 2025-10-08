import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/screens/customer/customer_thread_screen.dart';
import 'package:call_companion/providers/call_provider.dart';
import 'package:call_companion/providers/customer_provider.dart';
import 'package:call_companion/models/customer.dart';
import 'package:call_companion/models/call.dart';

class MockCallProvider extends Mock implements CallProvider {}
class MockCustomerProvider extends Mock implements CustomerProvider {}

void main() {
  late MockCallProvider mockCallProvider;
  late MockCustomerProvider mockCustomerProvider;
  late Customer testCustomer;

  setUp(() {
    mockCallProvider = MockCallProvider();
    mockCustomerProvider = MockCustomerProvider();

    testCustomer = Customer(
      id: 'cust1',
      name: 'John Doe',
      phoneNumber: '+1234567890',
      email: 'john@example.com',
      lastContactDate: DateTime.now(),
      tags: ['VIP'],
      notes: 'Test customer'
    );

    // Setup mock calls
    final mockCalls = [
      Call(
        id: 'call1',
        customerId: testCustomer.id,
        employeeId: 'emp1',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        duration: 300,
        status: 'completed',
        type: 'outbound',
        audioUrl: 'test_url',
        transcript: 'Test transcript',
        summary: {'text': 'Test summary'}
      ),
      Call(
        id: 'call2',
        customerId: testCustomer.id,
        employeeId: 'emp1',
        startTime: DateTime.now(),
        duration: 200,
        status: 'completed',
        type: 'inbound',
        audioUrl: 'test_url'
      )
    ];

    when(mockCallProvider.getCallsByCustomer(testCustomer.id))
        .thenReturn(mockCalls);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<CallProvider>.value(
            value: mockCallProvider,
          ),
          ChangeNotifierProvider<CustomerProvider>.value(
            value: mockCustomerProvider,
          ),
        ],
        child: CustomerThreadScreen(customer: testCustomer),
      ),
    );
  }

  group('CustomerThreadScreen Widget Tests', () {
    testWidgets('should display customer information and calls',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('+1234567890'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget); // Call list
      expect(find.byType(Card), findsNWidgets(2)); // Two call cards
    });

    testWidgets('should show AI chat button',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.chat), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('should show edit customer dialog on edit button tap',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Edit Customer'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('should display call details correctly',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Outbound Call'), findsOneWidget);
      expect(find.text('Inbound Call'), findsOneWidget);
      expect(find.text('Completed'), findsNWidgets(2));
    });

    testWidgets('should show transcript and summary when available',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Outbound Call'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test transcript'), findsOneWidget);
      expect(find.text('Test summary'), findsOneWidget);
    });
  });
}