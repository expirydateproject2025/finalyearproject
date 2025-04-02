import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthResult {
  final bool success;
  final String message;
  final bool needsVerification;
  final User? user;

  AuthResult({
    required this.success,
    required this.message,
    this.needsVerification = false,
    this.user,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign In
  Future<AuthResult> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        return AuthResult(
          success: false,
          message: "Please verify your email before logging in.",
          needsVerification: true,
          user: userCredential.user,
        );
      }

      return AuthResult(
        success: true,
        message: "Login successful",
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _handleAuthError(e),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: "An unexpected error occurred. Please try again.",
      );
    }
  }

  // Send Email Verification
  Future<void> sendEmailVerification(String email) async {
    User? user = _auth.currentUser;

    // If no current user, try to sign in
    if (user == null) {
      try {
        // This is a temporary sign-in just to get the user object
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.isEmpty) {
          throw "No account found with this email.";
        }

        // We don't want to actually complete the sign-in,
        // just get the user object to send verification
        user = _auth.currentUser;
        if (user == null) {
          throw "Unable to send verification email. Please contact support.";
        }
      } catch (e) {
        throw e.toString();
      }
    }

    // Send verification email
    try {
      await user.sendEmailVerification();
    } catch (e) {
      throw "Error sending verification email: ${e.toString()}";
    }
  }

  // Sign Up
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Store user info in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': userCredential.user!.uid,
      });

      return AuthResult(
        success: true,
        message: "Account created! Please verify your email before logging in.",
        needsVerification: true,
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _handleAuthError(e),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: "An unexpected error occurred. Please try again.",
      );
    }
  }

  // Reset Password
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(
        success: true,
        message: "Password reset email sent. Please check your inbox.",
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _handleAuthError(e),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: "An unexpected error occurred. Please try again.",
      );
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get Current User
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Update Profile
  Future<AuthResult> updateProfile({String? name, String? email}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: "No user logged in",
        );
      }

      if (email != null && email != user.email) {
        await user.updateEmail(email);
        // Send verification if email changes
        await user.sendEmailVerification();
      }

      if (name != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': name,
        });
      }

      return AuthResult(
        success: true,
        message: email != user.email
            ? "Profile updated! Please verify your new email."
            : "Profile updated successfully!",
        needsVerification: email != user.email,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _handleAuthError(e),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: "An unexpected error occurred. Please try again.",
      );
    }
  }

  // Update Password
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: "No user logged in",
        );
      }

      await user.updatePassword(newPassword);
      return AuthResult(
        success: true,
        message: "Password updated successfully!",
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _handleAuthError(e),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: "An unexpected error occurred. Please try again.",
      );
    }
  }

  // Get User Data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
        await _firestore.collection('users').doc(user.uid).get();
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print("Error getting user data: $e");
      return null;
    }
  }

  // Handle Authentication Errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-disabled':
        return 'This user account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'requires-recent-login':
        return 'This operation requires re-authentication. Please logout and login again.';
      default:
        return e.message ?? 'An error occurred during authentication';
    }
  }
}