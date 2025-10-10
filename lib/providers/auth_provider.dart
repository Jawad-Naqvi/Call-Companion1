import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:call_companion/config/app_config.dart';
import 'package:call_companion/services/auth_service.dart' as fb_auth;
import 'package:call_companion/services/auth_api_service.dart' as api_auth;
import 'package:call_companion/models/user.dart';

class AuthProvider extends ChangeNotifier {
  late dynamic _authService; // fb_auth.AuthService or api_auth.AuthService

  User? _user;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  User? get currentUser => _user; // Alias for clarity
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isEmployee => _user?.role == UserRole.employee;
  bool get isAdmin => _user?.role == UserRole.admin;

  AuthProvider() {
    _init();
  }

  void _init() async {
    // Choose auth implementation at runtime
    if (AppConfig.useApiAuth) {
      _authService = api_auth.AuthService();
    } else {
      _authService = fb_auth.AuthService();
    }
    
    // Check if user is already authenticated
    _user = await _authService.getCurrentAppUser();
    
    if (!AppConfig.useApiAuth && !kIsWeb) {
      _authService.authStateChanges.listen((_) async {
        _isLoading = true;
        notifyListeners();
        _user = await _authService.getCurrentAppUser();
        _isLoading = false;
        notifyListeners();
      });
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.signInWithEmailPassword(email, password);
      if (result.isSuccess && result.user != null) {
        _user = result.user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'An unexpected error occurred: $e';
      notifyListeners();
      return false;
    }
  }
  

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? companyId,
  }) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {

      final result = await _authService.signUpWithEmailPassword(
        email,
        password,
        name,
        role,
        companyId,
      );
      if (result.isSuccess && result.user != null) {
        _user = result.user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'An unexpected error occurred during registration';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
    } catch (e) {
      _error = 'Error signing out';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_user == null) return false;

    _error = null;
    notifyListeners();

    try {
      final success = await _authService.updateUserProfile(_user!.id, updates);
      if (success) {
        _user = await _authService.getCurrentAppUser();
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to update profile';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error updating profile';
      notifyListeners();
      return false;
    }
  }

  Future<List<User>> getCompanyEmployees() async {
    if (_user?.companyId == null) return [];

    try {
      return await _authService.getEmployeesByCompany(_user!.companyId!);
    } catch (e) {
      _error = 'Error fetching employees';
      notifyListeners();
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
