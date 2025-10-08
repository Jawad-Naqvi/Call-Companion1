import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/screens/employee/employee_dashboard.dart';
import 'package:call_companion/providers/auth_provider.dart';
import 'package:call_companion/providers/call_provider.dart';
import 'package:call_companion/providers/customer_provider.dart';
import 'package:call_companion/models/employee.dart';
import 'package:call_companion/models/customer.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockCallProvider extends Mock implements CallProvider {}
class MockCustomerProvider extends Mock implements CustomerProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockCallProvider mockCallProvider;
  late MockCustomerProvider mockCustomerProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockCallProvider = MockCallProvider();
    mockCustomerProvider = MockCustomerProvider();

    // Setup default mock data
    when(mockAuthProvider.currentEmployee).thenReturn(
      Employee(
        id: 'emp1',
        name: 'Test Employee',
        email: 'test@example.com',
        role: 'agent',
        status: 'active'
      )
    );

    when(mockCustomerProvider.customers).thenReturn([
      Customer(
        id: 'cust1',
        name: 'John Doe',
        phoneNumber: '+1234567890',
        email: 'john@example.com',
        lastContactDate: DateTime.now(),
        tags: ['VIP'],
        notes: 'Test customer'
      )
    ]);

    when(mockCustomerProvider.searchCustomers(any)).thenReturn([
      Customer(
        id: 'cust1',
        name: 'John Doe',
        phoneNumber: '+1234567890',
        email: 'john@example.com',
        lastContactDate: DateTime.now(),
        tags: ['VIP'],
        notes: 'Test customer'
      )
    ]);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
          ),
          ChangeNotifierProvider<CallProvider>.value(
            value: mockCallProvider,
          ),
          ChangeNotifierProvider<CustomerProvider>.value(
            value: mockCustomerProvider,
          ),
        ],
        child: const EmployeeDashboard(),
      ),
    );
  }

  group('EmployeeDashboard Widget Tests', () {
    testWidgets('should display search bar and customer list',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(TextField), findsOneWidget); // Search bar
      expect(find.byType(ListView), findsOneWidget); // Customer list
      expect(find.text('John Doe'), findsOneWidget); // Customer name
      expect(find.text('+1234567890'), findsOneWidget); // Customer phone
    });

    testWidgets('should filter customers when searching',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byType(TextField), 'John');
      await tester.pumpAndSettle();

      // Assert
      verify(mockCustomerProvider.searchCustomers('John')).called(1);
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('should show app bar with profile menu',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should navigate to customer thread on tap',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('John Doe'));
      await tester.pumpAndSettle();

      // Assert
      // Verify navigation occurred (implementation depends on your navigation setup)
      // This might need to be adjusted based on your actual navigation implementation
    });
  });
}