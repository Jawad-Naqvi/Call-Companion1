import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:call_companion/models/user.dart';
import 'auth_api_service.dart' as api; // Import for API fallback
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:call_companion/services/auth_api_service.dart' as auth_api; // Import UserAuthResult

class AuthService {
  final auth.FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final bool _useFirebase;

  AuthService._(this._useFirebase, this._auth, this._firestore);

  static Future<AuthService> create() async {
    await _initFirebaseIfNeeded();
    final useFirebase = _checkFirebaseAvailability();
    final fbAuth = useFirebase ? auth.FirebaseAuth.instance : null;
    final firestore = useFirebase ? FirebaseFirestore.instance : null;
    return AuthService._(useFirebase, fbAuth, firestore);
  }

  static Future<void> _initFirebaseIfNeeded() async {
    if (Firebase.apps.isNotEmpty) return;

    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyBWhnCDLZxjXEA1S5ogdtWFltuHoa-O9PI',
          authDomain: 'call-companion-ff585.firebaseapp.com',
          projectId: 'call-companion-ff585',
          storageBucket: 'call-companion-ff585.appspot.com',
          messagingSenderId: '605403679937',
          appId: '1:605403679937:web:2f6383a933b38730579840',
        ),
      );
    } else {
      // For mobile, try default initialization
      try {
        await Firebase.initializeApp();
      } catch (e) {
        // If fails, use provided options
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyBWhnCDLZxjXEA1S5ogdtWFltuHoa-O9PI',
            projectId: 'call-companion-ff585',
            storageBucket: 'call-companion-ff585.appspot.com',
            messagingSenderId: '605403679937',
            appId: '1:605403679937:web:2f6383a933b38730579840',
          ),
        );
      }
    }
  }

  static bool _checkFirebaseAvailability() {
    try {
      auth.FirebaseAuth.instance;
      FirebaseFirestore.instance;
      return true;
    } catch (e) {
      print('Firebase not available: $e');
      return false;
    }
  }

  Stream<auth.User?> get authStateChanges {
    if (_useFirebase && _auth != null) {
      return _auth!.authStateChanges();
    }
    return const Stream.empty();
  }

  auth.User? get currentUser {
    if (_useFirebase && _auth != null) {
      return _auth!.currentUser;
    }
    return null;
  }

  Future<User?> getCurrentAppUser() async {
    if (_useFirebase && _auth != null) {
      final authUser = currentUser;
      if (authUser == null) return null;
      
      try {
        final doc = await _firestore!.collection('users').doc(authUser.uid).get();
        if (doc.exists) {
          return User.fromJson({...doc.data()!, 'id': doc.id});
        }
      } catch (e) {
        print('Error getting current user: $e');
      }
      return null;
    } else {
      // Use API
      final apiService = api.AuthService();
      return await apiService.getCurrentAppUser();
    }
  }

  Future<auth_api.UserAuthResult> signInWithEmailPassword(String email, String password) async {
    // Always use existing API for email/password auth to avoid Firebase 400 on web
    final apiService = api.AuthService();
    return await apiService.signInWithEmailPassword(email, password);
  }

  Future<auth_api.UserAuthResult> signInWithGoogle() async {
    try {
      auth.UserCredential userCred;
      if (kIsWeb) {
        // Web: use Firebase popup flow (no google_sign_in clientId needed)
        final provider = auth.GoogleAuthProvider();
        userCred = await _auth!.signInWithPopup(provider);
      } else {
        // Mobile: use google_sign_in package
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          return auth_api.UserAuthResult.error('Sign in cancelled');
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCred = await _auth!.signInWithCredential(credential);
      }

      final fbUser = userCred.user;
      if (fbUser == null) {
        return auth_api.UserAuthResult.error('Google sign in failed');
      }

      // Sync with Neon DB via API (creates or updates user)
      final apiService = api.AuthService();
      final syncResult = await apiService.syncGoogleUser(
        email: fbUser.email ?? '',
        name: fbUser.displayName ?? 'User',
        firebaseUid: fbUser.uid,
        role: UserRole.employee, // Default to employee; backend enforces allowlist
        companyId: 'default-company',
      );

      if (syncResult.user != null) {
        return auth_api.UserAuthResult.success(syncResult.user!);
      } else {
        // If sync fails, still allow sign-in with fallback user
        final fallback = User(
          id: fbUser.uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ?? 'User',
          role: UserRole.employee,
          companyId: 'default-company',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        return auth_api.UserAuthResult.success(fallback);
      }
    } catch (e) {
      return auth_api.UserAuthResult.error('Google sign in error: $e');
    }
  }

  Future<auth_api.UserAuthResult> signUpWithEmailPassword(
    String email, 
    String password, 
    String name,
    UserRole role,
    String? companyId,
  ) async {
    // Always use existing API for email/password sign-up
    final apiService = api.AuthService();
    return await apiService.signUpWithEmailPassword(email, password, name, role, companyId);
  }

  Future<void> signOut() async {
    if (_useFirebase && _auth != null) {
      await _auth!.signOut();
    } else {
      // Use API
      final apiService = api.AuthService();
      await apiService.signOut();
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    if (_useFirebase && _auth != null) {
      try {
        await _auth!.sendPasswordResetEmail(email: email);
        return true;
      } catch (e) {
        print('Error sending password reset email: $e');
        return false;
      }
    } else {
      // API doesn't have this, return false
      return false;
    }
  }
  
  // Phone authentication with OTP as specified in PRD
  Future<auth_api.UserAuthResult> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    if (_useFirebase && _auth != null) {
      try {
        await _auth!.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (auth.PhoneAuthCredential credential) async {
            // Auto-verification completed (Android only)
            final userCredential = await _auth!.signInWithCredential(credential);
            if (userCredential.user != null) {
              final appUser = await _getUserData(userCredential.user!.uid);
              if (appUser != null) {
                // Handle success case - could set a variable or call a callback
                // Do NOT return a value here
              }

              // If user doesn't exist in Firestore, create a new employee user
              final newUser = User(
                id: userCredential.user!.uid,
                email: userCredential.user!.email ?? '',
                name: userCredential.user!.displayName ?? 'New User',
                role: UserRole.employee, // Default to employee role
                phoneNumber: phoneNumber,
                companyId: null, // Will need to be assigned later
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              await _firestore!.collection('users').doc(newUser.id).set(newUser.toJson());
              // Handle success case - could set a variable or call a callback
              // Do NOT return a value here
            }
            // Do NOT return a value here
          },
          verificationFailed: (auth.FirebaseAuthException e) {
            onError(_getAuthErrorMessage(e.code));
            // Do NOT return a value here
          },
          codeSent: (String verificationId, int? resendToken) {
            onCodeSent(verificationId);
            // Do NOT return a value here
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            // Auto-retrieval timeout
          },
          timeout: const Duration(seconds: 60),
        );
        return auth_api.UserAuthResult.pending();
      } catch (e) {
        onError('An unexpected error occurred: $e');
        return auth_api.UserAuthResult.error('An unexpected error occurred: $e');
      }
    } else {
      // API doesn't support phone auth
      onError('Phone authentication not available');
      return auth_api.UserAuthResult.error('Phone authentication not available');
    }
  }
  
  Future<auth_api.UserAuthResult> verifyOTP({
    required String verificationId,
    required String otp,
    required String phoneNumber,
    String? name,
  }) async {
    try {
      final credential = auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      
      final userCredential = await _auth!.signInWithCredential(credential);
      if (userCredential.user != null) {
        // Check if user exists in Firestore
        final appUser = await _getUserData(userCredential.user!.uid);
        if (appUser != null) {
          return auth_api.UserAuthResult.success(appUser);
        }
        
        // If user doesn't exist, create a new employee user
        final newUser = User(
          id: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          name: name ?? 'New User',
          role: UserRole.employee, // Default to employee role
          phoneNumber: phoneNumber,
          companyId: null, // Will need to be assigned later
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _firestore!.collection('users').doc(newUser.id).set(newUser.toJson());
        return auth_api.UserAuthResult.success(newUser);
      }
      
      return auth_api.UserAuthResult.error('Verification failed');
    } on auth.FirebaseAuthException catch (e) {
      return auth_api.UserAuthResult.error(_getAuthErrorMessage(e.code));
    } catch (e) {
      return auth_api.UserAuthResult.error('An unexpected error occurred: $e');
    }
  }

  Future<User?> _getUserData(String uid) async {
    if (_useFirebase && _firestore != null) {
      try {
        final doc = await _firestore!.collection('users').doc(uid).get();
        if (doc.exists) {
          return User.fromJson({...doc.data()!, 'id': doc.id});
        }
      } catch (e) {
        print('Error getting user data: $e');
      }
      return null;
    } else {
      // For API, we don't have a direct way to get user by UID, return null
      return null;
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  Future<List<User>> getEmployeesByCompany(String companyId) async {
    // On web or when Firestore unreliable, use API to avoid 400 Listen errors
    if (kIsWeb) {
      final apiService = api.AuthService();
      return await apiService.getEmployeesByCompany(companyId);
    }
    if (_useFirebase && _firestore != null) {
      try {
        final querySnapshot = await _firestore!
            .collection('users')
            .where('companyId', isEqualTo: companyId)
            .where('role', isEqualTo: UserRole.employee.name)
            .where('isActive', isEqualTo: true)
            .orderBy('name')
            .get();

        return querySnapshot.docs.map((doc) => 
          User.fromJson({...doc.data(), 'id': doc.id})
        ).toList();
      } catch (e) {
        print('Error getting employees via Firestore, falling back to API: $e');
        final apiService = api.AuthService();
        return await apiService.getEmployeesByCompany(companyId);
      }
    }
    // Use API
    final apiService = api.AuthService();
    return await apiService.getEmployeesByCompany(companyId);
  }

  Future<bool> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    // On web, avoid Firestore Timestamp serialization errors; use API
    if (kIsWeb) {
      final apiService = api.AuthService();
      return await apiService.updateUserProfile(userId, updates);
    }
    if (_useFirebase && _firestore != null) {
      try {
        updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
        await _firestore!.collection('users').doc(userId).update(updates);
        return true;
      } catch (e) {
        print('Error updating user profile via Firestore, falling back to API: $e');
        final apiService = api.AuthService();
        return await apiService.updateUserProfile(userId, updates);
      }
    }
    // Use API
    final apiService = api.AuthService();
    return await apiService.updateUserProfile(userId, updates);
  }
}