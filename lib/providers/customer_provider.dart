import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:call_companion/services/backend_services.dart';
import 'package:call_companion/models/customer.dart';

class CustomerProvider extends ChangeNotifier {
  CustomerService? _customerService; // initialize only on non-web
  
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Mock data for testing
  void _addMockCustomers(String employeeId) {
    final mockCustomers = [
      Customer(
        id: '1',
        phoneNumber: '+1 (555) 123-4567',
        name: 'John Smith',
        company: 'Tech Solutions Inc.',
        email: 'john.smith@techsolutions.com',
        employeeId: employeeId,
        alias: 'Enterprise Client',
        lastCallAt: DateTime.now().subtract(const Duration(hours: 2)),
        totalCalls: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ),
      Customer(
        id: '2',
        phoneNumber: '+1 (555) 987-6543',
        name: 'Sarah Johnson',
        company: 'Marketing Pros LLC',
        email: 'sarah.j@marketingpros.com',
        employeeId: employeeId,
        alias: 'Marketing Lead',
        lastCallAt: DateTime.now().subtract(const Duration(days: 1)),
        totalCalls: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    
    _customers = mockCustomers;
    notifyListeners();
  }

  Future<void> loadCustomers(String employeeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // For testing: Always load mock data
      _addMockCustomers(employeeId);
      
      // Normal production code (commented out for testing)
      // if (kIsWeb) {
      //   _customers = [];
      // } else {
      //   _customerService ??= CustomerService();
      //   _customers = await _customerService!.getCustomersByEmployee(employeeId);
      // }
    } catch (e) {
      _error = 'Failed to load customers: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Customer?> createOrUpdateCustomer({
    required String phoneNumber,
    required String employeeId,
    String? alias,
    String? name,
    String? company,
    String? email,
  }) async {
    try {
      if (kIsWeb) {
        // Create a local-only customer object
        final customer = Customer(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
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
        final existingIndex = _customers.indexWhere((c) => c.phoneNumber == phoneNumber && c.employeeId == employeeId);
        if (existingIndex != -1) {
          _customers[existingIndex] = customer;
        } else {
          _customers.insert(0, customer);
        }
        _customers.sort((a, b) => b.lastCallAt.compareTo(a.lastCallAt));
        notifyListeners();
        return customer;
      }

      _customerService ??= CustomerService();
      final customer = await _customerService!.createOrUpdateCustomer(
        phoneNumber: phoneNumber,
        employeeId: employeeId,
        alias: alias,
        name: name,
        company: company,
        email: email,
      );

      final existingIndex = _customers.indexWhere((c) => c.id == customer.id);
      if (existingIndex != -1) {
        _customers[existingIndex] = customer;
      } else {
        _customers.insert(0, customer);
      }
      _customers.sort((a, b) => b.lastCallAt.compareTo(a.lastCallAt));

      notifyListeners();
      return customer;
    } catch (e) {
      _error = 'Error creating/updating customer: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCustomerAlias(String customerId, String alias) async {
    try {
      if (kIsWeb) {
        final index = _customers.indexWhere((c) => c.id == customerId);
        if (index != -1) {
          _customers[index] = _customers[index].copyWith(alias: alias, updatedAt: DateTime.now());
          notifyListeners();
          return true;
        }
        return false;
      }

      _customerService ??= CustomerService();
      final success = await _customerService!.updateCustomerAlias(customerId, alias);
      if (success) {
        final index = _customers.indexWhere((c) => c.id == customerId);
        if (index != -1) {
          _customers[index] = _customers[index].copyWith(alias: alias, updatedAt: DateTime.now());
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _error = 'Error updating customer alias: $e';
      notifyListeners();
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
      if (kIsWeb) {
        final index = _customers.indexWhere((c) => c.id == customerId);
        if (index != -1) {
          _customers[index] = _customers[index].copyWith(
            alias: alias ?? _customers[index].alias,
            name: name ?? _customers[index].name,
            company: company ?? _customers[index].company,
            email: email ?? _customers[index].email,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
          return true;
        }
        return false;
      }

      _customerService ??= CustomerService();
      final success = await _customerService!.updateCustomerInfo(
        customerId,
        alias: alias,
        name: name,
        company: company,
        email: email,
      );
      if (success) {
        final index = _customers.indexWhere((c) => c.id == customerId);
        if (index != -1) {
          _customers[index] = _customers[index].copyWith(
            alias: alias ?? _customers[index].alias,
            name: name ?? _customers[index].name,
            company: company ?? _customers[index].company,
            email: email ?? _customers[index].email,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _error = 'Error updating customer info: $e';
      notifyListeners();
      return false;
    }
  }

  Future<Customer?> getCustomerByPhoneAndEmployee(String phoneNumber, String employeeId) async {
    try {
      if (kIsWeb) {
        try {
          return _customers.firstWhere((c) => c.phoneNumber == phoneNumber && c.employeeId == employeeId);
        } catch (_) {
          return null;
        }
      }
      _customerService ??= CustomerService();
      return await _customerService!.getCustomerByPhoneAndEmployee(phoneNumber, employeeId);
    } catch (e) {
      _error = 'Error getting customer: $e';
      notifyListeners();
      return null;
    }
  }

  Future<Customer?> getCustomerById(String customerId) async {
    try {
      if (kIsWeb) {
        try {
          return _customers.firstWhere((c) => c.id == customerId);
        } catch (_) {
          return null;
        }
      }
      _customerService ??= CustomerService();
      return await _customerService!.getCustomerById(customerId);
    } catch (e) {
      _error = 'Error getting customer: $e';
      notifyListeners();
      return null;
    }
  }

  List<Customer> searchCustomers(String query) {
    if (query.isEmpty) return _customers;
    
    final searchTerms = query.toLowerCase();
    return _customers.where((customer) {
      return customer.phoneNumber.contains(searchTerms) ||
             customer.displayName.toLowerCase().contains(searchTerms) ||
             (customer.company?.toLowerCase().contains(searchTerms) ?? false) ||
             (customer.email?.toLowerCase().contains(searchTerms) ?? false);
    }).toList();
  }

  Future<bool> deleteCustomer(String customerId) async {
    try {
      if (kIsWeb) {
        _customers.removeWhere((c) => c.id == customerId);
        notifyListeners();
        return true;
      }
      _customerService ??= CustomerService();
      final success = await _customerService!.deleteCustomer(customerId);
      if (success) {
        _customers.removeWhere((c) => c.id == customerId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Error deleting customer: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}