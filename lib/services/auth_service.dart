import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp({required String email, required String password}) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unknown error occurred.';
    }
  }

  Future<UserCredential> login({required String email, required String password}) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unknown error occurred.';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> sendVerificationEmail() async {
    User? user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> updateUserName(String fullName) async {
    await _auth.currentUser?.updateDisplayName(fullName);
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}