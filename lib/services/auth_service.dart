import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInResult {
  final UserCredential userCredential;
  final String? givenName;
  final String? familyName;
  final String? appleUserIdentifier;
  final String? authorizationCode;

  AppleSignInResult({
    required this.userCredential,
    this.givenName,
    this.familyName,
    this.appleUserIdentifier,
    this.authorizationCode,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Google sign-in failed. Please try again.';
    }
  }

  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<AppleSignInResult?> signInWithApple() async {
    try {
      final String rawNonce = _generateNonce();
      final String hashedNonce = _sha256OfString(rawNonce);

      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      if (appleCredential.identityToken == null) {
        throw 'Apple sign-in failed. Please try again.';
      }

      final OAuthCredential oauthCredential =
          OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(oauthCredential);

      return AppleSignInResult(
        userCredential: userCredential,
        givenName: appleCredential.givenName,
        familyName: appleCredential.familyName,
        appleUserIdentifier: appleCredential.userIdentifier,
        authorizationCode: appleCredential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw 'Apple sign-in failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw 'An account with this email already exists. Please sign in with your original method.';
      }
      throw _handleAuthException(e);
    } catch (_) {
      throw 'Apple sign-in failed. Please try again.';
    }
  }

  Future<AppleSignInResult?> reauthenticateWithApple() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw 'Not signed in.';
    }
    try {
      final String rawNonce = _generateNonce();
      final String hashedNonce = _sha256OfString(rawNonce);

      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      if (appleCredential.identityToken == null ||
          appleCredential.authorizationCode.isEmpty) {
        throw 'Apple re-authentication failed. Please try again.';
      }

      final OAuthCredential oauthCredential =
          OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential =
          await user.reauthenticateWithCredential(oauthCredential);

      return AppleSignInResult(
        userCredential: userCredential,
        appleUserIdentifier: appleCredential.userIdentifier,
        authorizationCode: appleCredential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw 'Apple re-authentication failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (_) {
      throw 'Apple re-authentication failed. Please try again.';
    }
  }

  Future<void> revokeAppleTokenWith(String authorizationCode) async {
    try {
      await _auth.revokeTokenWithAuthorizationCode(authorizationCode);
    } catch (e) {
      // Revocation is required by Apple but should never block account
      // deletion entirely if Apple's endpoint hiccups; we surface a log
      // and let the caller proceed with Firebase + Firestore cleanup.
      // ignore: avoid_print
      print('Apple token revoke failed: $e');
    }
  }

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
      case 'invalid-credential': 
        return 'Incorrect email or password.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}