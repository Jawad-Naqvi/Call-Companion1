import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:call_companion/config/app_config.dart';
import 'package:call_companion/services/auth_service.dart' as fb_auth;
import 'package:call_companion/services/auth_api_service.dart' as api_auth;
import 'package:call_companion/models/user.dart';

class AuthProvider extends ChangeNotifier {
  late Future<dynamic> _authServiceFuture; // Future for async AuthService

  User? _user;
  bool _isLoading = true;
  String? _error;
  bool _needsRoleSelection = false;

  User? get user => _user;
  User? get currentUser => _user; // Alias for clarity
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isEmployee => _user?.role == UserRole.employee;
  bool get isAdmin => _user?.role == UserRole.admin;
  bool get needsRoleSelection => _needsRoleSelection;

  AuthProvider() {
    _init();
  }

  void _init() async {
    // Choose auth implementation at runtime
    if (AppConfig.useApiAuth) {
      _authServiceFuture = Future.value(api_auth.AuthService());
    } else {
      _authServiceFuture = fb_auth.AuthService.create();
    }
    
    final authService = await _authServiceFuture;
    
    // Optionally force login screen on startup (do not auto-restore prior session)
    if (AppConfig.forceLoginOnStartup) {
      try {
        await authService.signOut(); // clears any stored token/session
      } catch (_) {}
      _user = null;
    } else {
      // Prefer API-backed session restoration first (JWT). This ensures reload keeps the user logged in.
      try {
        final apiUser = await api_auth.AuthService().getCurrentAppUser();
        _user = apiUser;
      } catch (_) {}
      // If API session not found, try authService-specific lookup (e.g., Firestore on mobile)
      if (_user == null) {
        _user = await authService.getCurrentAppUser();
      }
      // Final fallback to locally cached user
      if (_user == null) {
        _user = await _loadCachedUser();
      }
    }
    
    if (!AppConfig.useApiAuth && !kIsWeb) {
      authService.authStateChanges.listen((_) async {
        _isLoading = true;
        notifyListeners();
        _user = await authService.getCurrentAppUser();
        _isLoading = false;
        notifyListeners();
      });
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _cacheUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = user.toJson();
      map['id'] = user.id;
      await prefs.setString('app_user', jsonEncode(map));
    } catch (_) {}
  }

  Future<User?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('app_user');
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return User.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final authService = await _authServiceFuture;
      final result = await authService.signInWithEmailPassword(email, password);
      if (result.isSuccess && result.user != null) {
        _user = result.user;
        await _cacheUser(_user!);
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

  Future<bool> completeRoleSelection(UserRole role) async {
    if (_user == null) return false;
    // Enforce admin allowlist – only specific emails can be admins
    const allowedAdmins = {'naqvimohammedjawad@gmail.com'};
    final email = (_user!.email).trim().toLowerCase();
    if (role == UserRole.admin && !allowedAdmins.contains(email)) {
      role = UserRole.employee;
    }
    // Optimistically update local state so UI can proceed immediately
    final String company = _user!.companyId ?? 'default-company';
    _user = _user!.copyWith(role: role, companyId: company);
    _needsRoleSelection = false;
    notifyListeners();

    // Persist in background (best-effort). Do not await to avoid blocking on Firestore 400s.
    try {
      final authService = await _authServiceFuture;
      // Fire-and-forget; ignore result/errors
      // Using separate microtask to fully detach from UI flow
      Future.microtask(() async {
        try {
          if (role == UserRole.admin && !allowedAdmins.contains(email)) {
            await authService.updateUserProfile(_user!.id, {
              'role': UserRole.employee.name,
              'companyId': company,
            });
          } else {
            await authService.updateUserProfile(_user!.id, {
              'role': role.name,
              'companyId': company,
            });
          }
        } catch (_) {}
      });
    } catch (_) {}

    // Persist cache so reload restores session + role/company
    try {
      await _cacheUser(_user!);
    } catch (_) {}

    return true;
  }
  
  Future<bool> signInWithGoogle() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      // Always use Firebase-based Google sign-in (works on web and mobile)
      final authService = await _authServiceFuture;
      final result = await authService.signInWithGoogle();
      if (result.isSuccess && result.user != null) {
        _user = result.user;
        // Role comes from Neon DB sync; do not prompt again.
        _needsRoleSelection = false;
        await _cacheUser(_user!);
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
      _error = 'Google sign-in failed: $e';
      _isLoading = false;
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
      final authService = await _authServiceFuture;
      final result = await authService.signUpWithEmailPassword(
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
      final authService = await _authServiceFuture;
      // Clear API token/session
      try { await api_auth.AuthService().signOut(); } catch (_) {}
      // Sign out from Firebase session if applicable
      try { await authService.signOut(); } catch (_) {}
      _user = null;
      _needsRoleSelection = false;
      await _clearCachedUser();
    } catch (e) {
      _error = 'Error signing out';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _clearCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_user');
    } catch (_) {}
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_user == null) return false;

    _error = null;
    notifyListeners();

    try {
      final authService = await _authServiceFuture;
      final success = await authService.updateUserProfile(_user!.id, updates);
      if (success) {
        _user = await authService.getCurrentAppUser() ?? _user;
        if (_user != null) {
          await _cacheUser(_user!);
        }
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
      final authService = await _authServiceFuture;
      return await authService.getEmployeesByCompany(_user!.companyId!);
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
