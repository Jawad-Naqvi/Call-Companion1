import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:call_companion/models/user.dart';

class AuthService {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<auth.User?> get authStateChanges => _auth.authStateChanges();
  auth.User? get currentUser => _auth.currentUser;

  Future<User?> getCurrentAppUser() async {
    final authUser = currentUser;
    if (authUser == null) return null;
    
    try {
      final doc = await _firestore.collection('users').doc(authUser.uid).get();
      if (doc.exists) {
        return User.fromJson({...doc.data()!, 'id': doc.id});
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
    return null;
  }

  Future<UserAuthResult> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        final appUser = await _getUserData(credential.user!.uid);
        return UserAuthResult.success(appUser);
      }
      
      return UserAuthResult.error('Sign in failed');
    } on auth.FirebaseAuthException catch (e) {
      return UserAuthResult.error(_getAuthErrorMessage(e.code));
    } catch (e) {
      return UserAuthResult.error('An unexpected error occurred: $e');
    }
  }

  Future<UserAuthResult> signUpWithEmailPassword(
    String email, 
    String password, 
    String name,
    UserRole role,
    String? companyId,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        final user = User(
          id: credential.user!.uid,
          email: email,
          name: name,
          role: role,
          companyId: companyId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(user.id).set(user.toJson());
        
        return UserAuthResult.success(user);
      }
      
      return UserAuthResult.error('Sign up failed');
    } on auth.FirebaseAuthException catch (e) {
      return UserAuthResult.error(_getAuthErrorMessage(e.code));
    } catch (e) {
      return UserAuthResult.error('An unexpected error occurred: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Error sending password reset email: $e');
      return false;
    }
  }
  
  // Phone authentication with OTP as specified in PRD
  Future<UserAuthResult> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (auth.PhoneAuthCredential credential) async {
          // Auto-verification completed (Android only)
          final userCredential = await _auth.signInWithCredential(credential);
          if (userCredential.user != null) {
            final appUser = await _getUserData(userCredential.user!.uid);
            if (appUser != null) {
              return UserAuthResult.success(appUser);
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
            
            await _firestore.collection('users').doc(newUser.id).set(newUser.toJson());
            return UserAuthResult.success(newUser);
          }
          return UserAuthResult.error('Verification failed');
        },
        verificationFailed: (auth.FirebaseAuthException e) {
          onError(_getAuthErrorMessage(e.code));
          return UserAuthResult.error(_getAuthErrorMessage(e.code));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
          return UserAuthResult.codeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timeout
        },
        timeout: const Duration(seconds: 60),
      );
      return UserAuthResult.pending();
    } catch (e) {
      onError('An unexpected error occurred: $e');
      return UserAuthResult.error('An unexpected error occurred: $e');
    }
  }
  
  Future<UserAuthResult> verifyOTP({
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
      
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        // Check if user exists in Firestore
        final appUser = await _getUserData(userCredential.user!.uid);
        if (appUser != null) {
          return UserAuthResult.success(appUser);
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
        
        await _firestore.collection('users').doc(newUser.id).set(newUser.toJson());
        return UserAuthResult.success(newUser);
      }
      
      return UserAuthResult.error('Verification failed');
    } on auth.FirebaseAuthException catch (e) {
      return UserAuthResult.error(_getAuthErrorMessage(e.code));
    } catch (e) {
      return UserAuthResult.error('An unexpected error occurred: $e');
    }
  }

  Future<User?> _getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return User.fromJson({...doc.data()!, 'id': doc.id});
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
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
    try {
      final querySnapshot = await _firestore
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
      print('Error getting employees: $e');
      return [];
    }
  }

  Future<bool> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection('users').doc(userId).update(updates);
      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }
}

class UserAuthResult {
  final bool isSuccess;
  final User? user;
  final String? error;

  UserAuthResult.success(this.user) : isSuccess = true, error = null;
  UserAuthResult.error(this.error) : isSuccess = false, user = null;
}