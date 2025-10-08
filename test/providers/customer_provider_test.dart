import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:call_companion/providers/customer_provider.dart';
import 'package:call_companion/models/customer.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockQuerySnapshot extends Mock implements QuerySnapshot {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot {}

void main() {
  late CustomerProvider customerProvider;
  late MockFirestore mockFirestore;

  setUp(() {
    mockFirestore = MockFirestore();
    customerProvider = CustomerProvider();
  });

  group('CustomerProvider Tests', () {
    test('loadCustomers should fetch and parse customers correctly', () async {
      // Arrange
      final mockCustomers = [
        {
          'id': 'customer1',
          'name': 'John Doe',
          'phoneNumber': '+1234567890',
          'email': 'john@example.com',
          'lastContactDate': DateTime.now().millisecondsSinceEpoch,
          'tags': ['VIP', 'New'],
          'notes': 'Test customer'
        }
      ];

      final mockSnapshot = MockQuerySnapshot();
      final mockDocs = mockCustomers.map((customer) {
        final doc = MockQueryDocumentSnapshot();
        when(doc.data()).thenReturn(customer);
        when(doc.id).thenReturn(customer['id'] as String);
        return doc;
      }).toList();

      when(mockSnapshot.docs).thenReturn(mockDocs);
      when(mockFirestore.collection('customers').get())
          .thenAnswer((_) async => mockSnapshot);

      // Act
      await customerProvider.loadCustomers();

      // Assert
      expect(customerProvider.customers, isNotEmpty);
      expect(customerProvider.customers.first.id, equals('customer1'));
      expect(customerProvider.customers.first.name, equals('John Doe'));
      expect(customerProvider.customers.first.phoneNumber, equals('+1234567890'));
    });

    test('searchCustomers should filter customers correctly', () {
      // Arrange
      final mockCustomers = [
        Customer(
          id: 'customer1',
          name: 'John Doe',
          phoneNumber: '+1234567890',
          email: 'john@example.com',
          lastContactDate: DateTime.now(),
          tags: ['VIP'],
          notes: 'Test customer'
        ),
        Customer(
          id: 'customer2',
          name: 'Jane Smith',
          phoneNumber: '+0987654321',
          email: 'jane@example.com',
          lastContactDate: DateTime.now(),
          tags: ['New'],
          notes: 'Another customer'
        )
      ];

      customerProvider.customers = mockCustomers;

      // Act & Assert
      expect(
        customerProvider.searchCustomers('John').length,
        equals(1)
      );
      expect(
        customerProvider.searchCustomers('1234').length,
        equals(1)
      );
      expect(
        customerProvider.searchCustomers('VIP').length,
        equals(1)
      );
      expect(
        customerProvider.searchCustomers('').length,
        equals(2)
      );
    });

    test('getCustomerById should return correct customer', () {
      // Arrange
      final mockCustomers = [
        Customer(
          id: 'customer1',
          name: 'John Doe',
          phoneNumber: '+1234567890',
          email: 'john@example.com',
          lastContactDate: DateTime.now(),
          tags: ['VIP'],
          notes: 'Test customer'
        )
      ];

      customerProvider.customers = mockCustomers;

      // Act
      final customer = customerProvider.getCustomerById('customer1');

      // Assert
      expect(customer, isNotNull);
      expect(customer?.id, equals('customer1'));
      expect(customer?.name, equals('John Doe'));
    });

    test('addCustomer should add customer to list', () async {
      // Arrange
      final newCustomer = Customer(
        id: 'customer3',
        name: 'Bob Wilson',
        phoneNumber: '+1122334455',
        email: 'bob@example.com',
        lastContactDate: DateTime.now(),
        tags: ['New'],
        notes: 'New customer'
      );

      // Mock Firestore add operation
      when(mockFirestore.collection('customers').add(any))
          .thenAnswer((_) async => MockDocumentReference());

      // Act
      await customerProvider.addCustomer(newCustomer);

      // Assert
      verify(mockFirestore.collection('customers').add(any)).called(1);
      expect(customerProvider.customers, contains(newCustomer));
    });
  });
}

class MockDocumentReference extends Mock implements DocumentReference {}