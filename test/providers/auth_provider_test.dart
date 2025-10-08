import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:call_companion/providers/auth_provider.dart';
import 'package:call_companion/models/employee.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirestore extends Mock implements FirebaseFirestore {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}

void main() {
  late AuthProvider authProvider;
  late MockFirebaseAuth mockAuth;
  late MockFirestore mockFirestore;
  late MockUser mockUser;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirestore();
    mockUser = MockUser();
    authProvider = AuthProvider();

    // Setup default mock user
    when(mockUser.uid).thenReturn('test_uid');
    when(mockUser.email).thenReturn('test@example.com');
  });

  group('AuthProvider Tests', () {
    test('signIn should authenticate user and load employee data', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';
      final mockCredential = MockUserCredential();
      
      when(mockCredential.user).thenReturn(mockUser);
      when(mockAuth.signInWithEmailAndPassword(
        email: email,
        password: password
      )).thenAnswer((_) async => mockCredential);

      final mockEmployeeData = {
        'id': 'emp1',
        'name': 'Test Employee',
        'email': email,
        'role': 'agent',
        'status': 'active'
      };

      // Mock Firestore employee data fetch
      when(mockFirestore.collection('employees')
        .doc(any)
        .get()
      ).thenAnswer((_) async => MockDocumentSnapshot(mockEmployeeData));

      // Act
      final result = await authProvider.signIn(email, password);

      // Assert
      expect(result, isTrue);
      expect(authProvider.currentEmployee, isNotNull);
      expect(authProvider.currentEmployee?.email, equals(email));
      expect(authProvider.isAuthenticated, isTrue);
    });

    test('signOut should clear current user and employee data', () async {
      // Arrange
      when(mockAuth.signOut()).thenAnswer((_) async {});
      authProvider.currentEmployee = Employee(
        id: 'emp1',
        name: 'Test Employee',
        email: 'test@example.com',
        role: 'agent',
        status: 'active'
      );

      // Act
      await authProvider.signOut();

      // Assert
      verify(mockAuth.signOut()).called(1);
      expect(authProvider.currentEmployee, isNull);
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('updateEmployeeStatus should update status correctly', () async {
      // Arrange
      const newStatus = 'away';
      authProvider.currentEmployee = Employee(
        id: 'emp1',
        name: 'Test Employee',
        email: 'test@example.com',
        role: 'agent',
        status: 'active'
      );

      // Mock Firestore update
      when(mockFirestore.collection('employees')
        .doc(any)
        .update(any)
      ).thenAnswer((_) async {});

      // Act
      await authProvider.updateEmployeeStatus(newStatus);

      // Assert
      verify(mockFirestore.collection('employees')
        .doc(authProvider.currentEmployee?.id)
        .update({'status': newStatus})
      ).called(1);
      expect(authProvider.currentEmployee?.status, equals(newStatus));
    });

    test('checkAuthState should handle authenticated state correctly', () async {
      // Arrange
      when(mockAuth.authStateChanges())
          .thenAnswer((_) => Stream.value(mockUser));

      final mockEmployeeData = {
        'id': 'emp1',
        'name': 'Test Employee',
        'email': 'test@example.com',
        'role': 'agent',
        'status': 'active'
      };

      when(mockFirestore.collection('employees')
        .doc(any)
        .get()
      ).thenAnswer((_) async => MockDocumentSnapshot(mockEmployeeData));

      // Act
      await authProvider.checkAuthState();

      // Assert
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentEmployee, isNotNull);
      expect(authProvider.currentEmployee?.email, equals('test@example.com'));
    });
  });
}

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {
  final Map<String, dynamic> _data;

  MockDocumentSnapshot(this._data);

  @override
  Map<String, dynamic> data() => _data;
}