import 'package:call_companion/models/customer.dart';

class CustomerService {
  Future<List<Customer>> getCustomersByEmployee(String employeeId) async => [];

  Future<Customer?> getCustomerByPhoneAndEmployee(String phoneNumber, String employeeId) async => null;

  Future<Customer> createOrUpdateCustomer({
    required String phoneNumber,
    required String employeeId,
    String? alias,
    String? name,
    String? company,
    String? email,
  }) async {
    throw UnsupportedError('Customer operations are unavailable in web preview without backend.');
  }

  Future<bool> updateCustomerAlias(String customerId, String alias) async => false;

  Future<bool> updateCustomerInfo(String customerId, {
    String? alias,
    String? name,
    String? company,
    String? email,
  }) async => false;

  Future<Customer?> getCustomerById(String customerId) async => null;

  Future<List<Customer>> searchCustomers(String employeeId, String query) async => [];

  Future<bool> deleteCustomer(String customerId) async => false;

  Stream<List<Customer>> watchCustomersByEmployee(String employeeId) => const Stream.empty();
}
