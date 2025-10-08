import 'package:call_companion/models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Stream<dynamic> get authStateChanges => const Stream.empty();
  dynamic get currentUser => null;

  User? _currentUser;
  
  // Static storage for web demo
  static final Map<String, List<User>> _companyEmployees = {};
  static final Map<String, User> _allUsers = {};

  Future<User?> getCurrentAppUser() async => _currentUser;

  Future<UserAuthResult> signInWithEmailPassword(String email, String password) async {
    // For web testing, create a demo user
    final user = User(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: email.split('@')[0],
      role: email.toLowerCase().contains('admin') ? UserRole.admin : UserRole.employee,
      companyId: 'demo-company',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // If it's an employee, add to the company list
    if (user.role == UserRole.employee) {
      _addEmployeeToCompany(user);
    }

    // Set as current user
    _currentUser = user;
    
    return UserAuthResult.success(user);
  }

  Future<UserAuthResult> signUpWithEmailPassword(
    String email,
    String password,
    String name,
    UserRole role,
    String? companyId,
  ) async {
    // Create a demo user for web testing
    final user = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email,
      name: name,
      role: role,
      companyId: companyId ?? 'demo-company',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    // Store the user if they're an employee
    if (role == UserRole.employee) {
      _addEmployeeToCompany(user);
    }
    
    // Set as current user
    _currentUser = user;
    
    return UserAuthResult.success(user);
  }

  Future<void> signOut() async {}

  Future<bool> sendPasswordResetEmail(String email) async => false;


  Future<List<User>> getEmployeesByCompany(String companyId) async {
    return _companyEmployees[companyId] ?? [];
  }

  void _addEmployeeToCompany(User user) {
    if (user.companyId != null) {
      _companyEmployees[user.companyId!] = [
        ...?_companyEmployees[user.companyId!],
        user,
      ];
    }
  }

  Future<bool> updateUserProfile(String userId, Map<String, dynamic> updates) async => false;

  Future<UserAuthResult> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    return UserAuthResult.error('Phone authentication is unavailable in web preview.');
  }

  Future<UserAuthResult> verifyOTP({
    required String verificationId,
    required String otp,
    required String phoneNumber,
    String? name,
  }) async {
    return UserAuthResult.error('OTP verification is unavailable in web preview.');
  }
}

class UserAuthResult {
  final bool isSuccess;
  final User? user;
  final String? error;

  UserAuthResult.success(this.user) : isSuccess = true, error = null;
  UserAuthResult.error(this.error) : isSuccess = false, user = null;
}
