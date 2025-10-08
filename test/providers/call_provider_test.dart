import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:call_companion/providers/call_provider.dart';
import 'package:call_companion/models/call.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockQuerySnapshot extends Mock implements QuerySnapshot {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot {}

void main() {
  late CallProvider callProvider;
  late MockFirestore mockFirestore;

  setUp(() {
    mockFirestore = MockFirestore();
    callProvider = CallProvider();
  });

  group('CallProvider Tests', () {
    test('loadCalls should fetch and parse calls correctly', () async {
      // Arrange
      final mockCalls = [
        {
          'id': 'call1',
          'customerId': 'customer1',
          'employeeId': 'employee1',
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 300,
          'status': 'completed',
          'type': 'outbound',
          'audioUrl': 'test_url',
          'transcript': 'Test transcript',
          'summary': {'text': 'Test summary'}
        }
      ];

      final mockSnapshot = MockQuerySnapshot();
      final mockDocs = mockCalls.map((call) {
        final doc = MockQueryDocumentSnapshot();
        when(doc.data()).thenReturn(call);
        when(doc.id).thenReturn(call['id'] as String);
        return doc;
      }).toList();

      when(mockSnapshot.docs).thenReturn(mockDocs);
      when(mockFirestore.collection('calls').get())
          .thenAnswer((_) async => mockSnapshot);

      // Act
      await callProvider.loadCalls();

      // Assert
      expect(callProvider.calls, isNotEmpty);
      expect(callProvider.calls.first.id, equals('call1'));
      expect(callProvider.calls.first.customerId, equals('customer1'));
      expect(callProvider.calls.first.status, equals('completed'));
    });

    test('getCallsByCustomer should filter calls correctly', () async {
      // Arrange
      const customerId = 'customer1';
      final mockCalls = [
        Call(
          id: 'call1',
          customerId: customerId,
          employeeId: 'employee1',
          startTime: DateTime.now(),
          duration: 300,
          status: 'completed',
          type: 'outbound',
          audioUrl: 'test_url'
        ),
        Call(
          id: 'call2',
          customerId: 'customer2',
          employeeId: 'employee1',
          startTime: DateTime.now(),
          duration: 200,
          status: 'completed',
          type: 'inbound',
          audioUrl: 'test_url'
        )
      ];

      callProvider.calls = mockCalls;

      // Act
      final customerCalls = callProvider.getCallsByCustomer(customerId);

      // Assert
      expect(customerCalls.length, equals(1));
      expect(customerCalls.first.id, equals('call1'));
      expect(customerCalls.first.customerId, equals(customerId));
    });

    test('getCallsByEmployee should filter calls correctly', () async {
      // Arrange
      const employeeId = 'employee1';
      final mockCalls = [
        Call(
          id: 'call1',
          customerId: 'customer1',
          employeeId: employeeId,
          startTime: DateTime.now(),
          duration: 300,
          status: 'completed',
          type: 'outbound',
          audioUrl: 'test_url'
        ),
        Call(
          id: 'call2',
          customerId: 'customer2',
          employeeId: 'employee2',
          startTime: DateTime.now(),
          duration: 200,
          status: 'completed',
          type: 'inbound',
          audioUrl: 'test_url'
        )
      ];

      callProvider.calls = mockCalls;

      // Act
      final employeeCalls = callProvider.getCallsByEmployee(employeeId);

      // Assert
      expect(employeeCalls.length, equals(1));
      expect(employeeCalls.first.id, equals('call1'));
      expect(employeeCalls.first.employeeId, equals(employeeId));
    });
  });
}