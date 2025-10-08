import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:call_companion/models/customer.dart';

class CustomerService {
  FirebaseFirestore? _firestore; // Initialize only on non-web
  final Uuid _uuid = const Uuid();

  Future<List<Customer>> getCustomersByEmployee(String employeeId) async {
    try {
      if (kIsWeb) return []; // Skip Firestore on web
      _firestore ??= FirebaseFirestore.instance;
      final querySnapshot = await _firestore!
          .collection('customers')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('lastCallAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => 
        Customer.fromJson({...doc.data(), 'id': doc.id})
      ).toList();
    } catch (e) {
      print('Error getting customers: $e');
      return [];
    }
  }

  Future<Customer?> getCustomerByPhoneAndEmployee(String phoneNumber, String employeeId) async {
    try {
      if (kIsWeb) return null;
      _firestore ??= FirebaseFirestore.instance;
      final querySnapshot = await _firestore!
          .collection('customers')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .where('employeeId', isEqualTo: employeeId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return Customer.fromJson({...doc.data(), 'id': doc.id});
      }
    } catch (e) {
      print('Error getting customer by phone: $e');
    }
    return null;
  }

  Future<Customer> createOrUpdateCustomer({
    required String phoneNumber,
    required String employeeId,
    String? alias,
    String? name,
    String? company,
    String? email,
  }) async {
    try {
      // Check if customer already exists
      final existing = await getCustomerByPhoneAndEmployee(phoneNumber, employeeId);
      
      if (existing != null) {
        // Update existing customer
        final updatedCustomer = existing.copyWith(
          alias: alias ?? existing.alias,
          name: name ?? existing.name,
          company: company ?? existing.company,
          email: email ?? existing.email,
          lastCallAt: DateTime.now(),
          totalCalls: existing.totalCalls + 1,
          updatedAt: DateTime.now(),
        );
        
        if (!kIsWeb) {
          _firestore ??= FirebaseFirestore.instance;
          await _firestore!
            .collection('customers')
            .doc(existing.id)
            .update(updatedCustomer.toJson());
        }
            
        return updatedCustomer;
      } else {
        // Create new customer
        final customer = Customer(
          id: _uuid.v4(),
          phoneNumber: phoneNumber,
          alias: alias,
          name: name,
          company: company,
          email: email,
          employeeId: employeeId,
          lastCallAt: DateTime.now(),
          totalCalls: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        if (!kIsWeb) {
          _firestore ??= FirebaseFirestore.instance;
          await _firestore!
              .collection('customers')
              .doc(customer.id)
              .set(customer.toJson());
        }
            
        return customer;
      }
    } catch (e) {
      print('Error creating/updating customer: $e');
      rethrow;
    }
  }

  Future<bool> updateCustomerAlias(String customerId, String alias) async {
    try {
      if (kIsWeb) return false;
      _firestore ??= FirebaseFirestore.instance;
      await _firestore!.collection('customers').doc(customerId).update({
        'alias': alias,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error updating customer alias: $e');
      return false;
    }
  }

  Future<bool> updateCustomerInfo(String customerId, {
    String? alias,
    String? name,
    String? company,
    String? email,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      
      if (alias != null) updates['alias'] = alias;
      if (name != null) updates['name'] = name;
      if (company != null) updates['company'] = company;
      if (email != null) updates['email'] = email;
      
      if (kIsWeb) return false;
      _firestore ??= FirebaseFirestore.instance;
      await _firestore!.collection('customers').doc(customerId).update(updates);
      return true;
    } catch (e) {
      print('Error updating customer info: $e');
      return false;
    }
  }

  Future<Customer?> getCustomerById(String customerId) async {
    try {
      if (kIsWeb) return null;
      _firestore ??= FirebaseFirestore.instance;
      final doc = await _firestore!.collection('customers').doc(customerId).get();
      if (doc.exists) {
        return Customer.fromJson({...doc.data()!, 'id': doc.id});
      }
    } catch (e) {
      print('Error getting customer by ID: $e');
    }
    return null;
  }

  Future<List<Customer>> searchCustomers(String employeeId, String query) async {
    try {
      final customers = await getCustomersByEmployee(employeeId);
      
      return customers.where((customer) {
        final searchTerms = query.toLowerCase();
        return customer.phoneNumber.contains(searchTerms) ||
               (customer.alias?.toLowerCase().contains(searchTerms) ?? false) ||
               (customer.name?.toLowerCase().contains(searchTerms) ?? false) ||
               (customer.company?.toLowerCase().contains(searchTerms) ?? false);
      }).toList();
    } catch (e) {
      print('Error searching customers: $e');
      return [];
    }
  }

  Future<bool> deleteCustomer(String customerId) async {
    try {
      if (kIsWeb) return false;
      _firestore ??= FirebaseFirestore.instance;
      await _firestore!.collection('customers').doc(customerId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Stream<List<Customer>> watchCustomersByEmployee(String employeeId) {
    if (kIsWeb) {
      return Stream<List<Customer>>.value([]);
    }
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!
        .collection('customers')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('lastCallAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }
}