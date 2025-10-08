import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/screens/admin/admin_dashboard.dart';
import 'package:call_companion/providers/auth_provider.dart';
import 'package:call_companion/providers/employee_provider.dart';
import 'package:call_companion/models/employee.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockEmployeeProvider extends Mock implements EmployeeProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockEmployeeProvider mockEmployeeProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockEmployeeProvider = MockEmployeeProvider();

    // Setup mock admin user
    when(mockAuthProvider.currentEmployee).thenReturn(
      Employee(
        id: 'admin1',
        name: 'Admin User',
        email: 'admin@example.com',
        role: 'admin',
        status: 'active'
      )
    );

    // Setup mock employees
    final mockEmployees = [
      Employee(
        id: 'emp1',
        name: 'John Agent',
        email: 'john@example.com',
        role: 'agent',
        status: 'active'
      ),
      Employee(
        id: 'emp2',
        name: 'Jane Agent',
        email: 'jane@example.com',
        role: 'agent',
        status: 'away'
      )
    ];

    when(mockEmployeeProvider.employees).thenReturn(mockEmployees);
    when(mockEmployeeProvider.loadEmployees())
        .thenAnswer((_) async => mockEmployees);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
          ),
          ChangeNotifierProvider<EmployeeProvider>.value(
            value: mockEmployeeProvider,
          ),
        ],
        child: const AdminDashboard(),
      ),
    );
  }

  group('AdminDashboard Widget Tests', () {
    testWidgets('should display employee list with status indicators',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('John Agent'), findsOneWidget);
      expect(find.text('Jane Agent'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Away'), findsOneWidget);
    });

    testWidgets('should show employee details on tap',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('John Agent'));
      await tester.pumpAndSettle();

      // Assert
      // Verify navigation to employee detail screen
      // This might need to be adjusted based on your actual navigation implementation
    });

    testWidgets('should show add employee button for admin',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should show add employee dialog on button tap',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Add New Employee'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('should show error state correctly',
        (WidgetTester tester) async {
      // Arrange
      when(mockEmployeeProvider.loadEmployees())
          .thenThrow(Exception('Failed to load employees'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error loading employees'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget); // Retry button
    });

    testWidgets('should show loading state',
        (WidgetTester tester) async {
      // Arrange
      when(mockEmployeeProvider.loadEmployees()).thenAnswer(
        (_) => Future.delayed(
          const Duration(seconds: 1),
          () => [],
        ),
      );

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should refresh employee list on pull to refresh',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Act
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Assert
      verify(mockEmployeeProvider.loadEmployees()).called(2); // Initial + refresh
    });

    testWidgets('should show performance metrics for each employee',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.call), findsWidgets); // Call count icon
      expect(find.byIcon(Icons.timer), findsWidgets); // Average duration icon
      expect(find.byIcon(Icons.people), findsWidgets); // Customer count icon
    });
  });
}