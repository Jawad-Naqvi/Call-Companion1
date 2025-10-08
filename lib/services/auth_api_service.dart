import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_companion/models/user.dart';

class UserAuthResult {
  final bool isSuccess;
  final User? user;
  final String? error;

  UserAuthResult._({required this.isSuccess, this.user, this.error});

  factory UserAuthResult.success(User user) {
    return UserAuthResult._(isSuccess: true, user: user);
  }

  factory UserAuthResult.error(String error) {
    return UserAuthResult._(isSuccess: false, error: error);
  }
}

class AuthApiService {
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  static const String tokenKey = 'auth_token';
  
  // Mock auth state changes stream for compatibility
  Stream<dynamic> get authStateChanges => const Stream.empty();
  
  // Store authentication token
  Future<void> _storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }
  
  // Get stored authentication token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }
  
  // Remove authentication token
  Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }
  
  // Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Sign up with email and password
  Future<UserAuthResult> signUpWithEmailPassword(
    String email,
    String password,
    String name,
    UserRole role,
    String? companyId,
  ) async {
    try {
      print('Attempting signup to: $baseUrl/auth/signup');
      print('Payload: ${jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'role': role.name.toLowerCase(),
        'company_id': companyId ?? 'default-company',
      })}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          'role': role.name.toLowerCase(),
          'company_id': companyId ?? 'default-company',
        }),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store token
        await _storeToken(data['access_token']);
        
        // Create user object
        final userData = data['user'];
        DateTime _safeParseDate(dynamic v) {
          if (v == null) return DateTime.now();
          if (v is String && v.isNotEmpty) {
            return DateTime.tryParse(v) ?? DateTime.now();
          }
          return DateTime.now();
        }
        final roleStr = (userData['role'] as String? ?? 'employee').toLowerCase();
        final user = User(
          id: userData['id'],
          email: userData['email'],
          name: userData['name'],
          role: roleStr == 'admin' ? UserRole.admin : UserRole.employee,
          companyId: userData['companyId'],
          createdAt: _safeParseDate(userData['createdAt']),
          updatedAt: _safeParseDate(userData['updatedAt']),
        );
        
        return UserAuthResult.success(user);
      } else if (response.statusCode == 409) {
        return UserAuthResult.error('User with this email already exists');
      } else {
        final error = jsonDecode(response.body);
        return UserAuthResult.error(error['detail'] ?? 'Signup failed');
      }
    } catch (e) {
      return UserAuthResult.error('Network error: $e');
    }
  }
  
  // Sign in with email and password
  Future<UserAuthResult> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store token
        await _storeToken(data['access_token']);
        
        // Create user object
        final userData = data['user'];
        final user = User(
          id: userData['id'],
          email: userData['email'],
          name: userData['name'],
          role: userData['role'] == 'admin' ? UserRole.admin : UserRole.employee,
          companyId: userData['companyId'],
          createdAt: DateTime.parse(userData['createdAt']),
          updatedAt: DateTime.parse(userData['updatedAt']),
        );
        
        return UserAuthResult.success(user);
      } else if (response.statusCode == 401) {
        return UserAuthResult.error('Invalid email or password');
      } else {
        final error = jsonDecode(response.body);
        return UserAuthResult.error(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      return UserAuthResult.error('Network error: $e');
    }
  }
  
  // Get current user
  Future<User?> getCurrentAppUser() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        DateTime _safeParseDate(dynamic v) {
          if (v == null) return DateTime.now();
          if (v is String && v.isNotEmpty) {
            return DateTime.tryParse(v) ?? DateTime.now();
          }
          return DateTime.now();
        }
        final roleStr = (userData['role'] as String? ?? 'employee').toLowerCase();
        return User(
          id: userData['id'],
          email: userData['email'],
          name: userData['name'],
          role: roleStr == 'admin' ? UserRole.admin : UserRole.employee,
          companyId: userData['companyId'],
          createdAt: _safeParseDate(userData['createdAt']),
          updatedAt: _safeParseDate(userData['updatedAt']),
        );
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        await _removeToken();
        return null;
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
    return null;
  }
  
  // Sign out
  Future<void> signOut() async {
    await _removeToken();
  }
  
  // Get employees by company (admin only)
  Future<List<User>> getEmployeesByCompany(String companyId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/employees?company_id=$companyId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> employeesData = jsonDecode(response.body);
        DateTime _safeParseDate(dynamic v) {
          if (v == null) return DateTime.now();
          if (v is String && v.isNotEmpty) {
            return DateTime.tryParse(v) ?? DateTime.now();
          }
          return DateTime.now();
        }
        return employeesData.map((userData) {
          final roleStr = (userData['role'] as String? ?? 'employee').toLowerCase();
          return User(
            id: userData['id'],
            email: userData['email'],
            name: userData['name'],
            role: roleStr == 'admin' ? UserRole.admin : UserRole.employee,
            companyId: userData['companyId'],
            createdAt: _safeParseDate(userData['createdAt']),
            updatedAt: _safeParseDate(userData['updatedAt']),
          );
        }).toList();
      } else {
        throw Exception('Failed to load employees');
      }
    } catch (e) {
      print('Error getting employees: $e');
      return [];
    }
  }
  
  // Send password reset email (placeholder)
  Future<bool> sendPasswordResetEmail(String email) async {
    // TODO: Implement password reset functionality
    return false;
  }
  
  // Update user profile (placeholder)
  Future<bool> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    // TODO: Implement user profile update
    return false;
  }
  
  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _getToken();
    if (token == null) return false;
    
    // Verify token by trying to get current user
    final user = await getCurrentAppUser();
    return user != null;
  }
}
