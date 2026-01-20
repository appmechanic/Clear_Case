import 'package:clearcase/core/utils/helping_functions.dart';
import 'package:clearcase/views/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../views/auth/email_verification_screen.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isEmailVerified = false;
  bool get isEmailVerified => _isEmailVerified;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> signUpFunction({
    required BuildContext context,
    required String email,
    required String password,
    required String fullName,
  }) async {
    setLoading(true);
    try {
      await _authService.signUp(email: email, password: password);

      await _authService.updateUserName(fullName);

      await _authService.sendVerificationEmail();

      setLoading(false);

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, EmailVerificationScreen.routeName);
      }
    } catch (e) {
      setLoading(false);
      if (context.mounted) {
        showSnackBar(context, e.toString());
      }
    }
  }

  // --- Login Function ---
  Future<void> loginFunction({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    setLoading(true);
    try {
      await _authService.login(email: email, password: password);
      User? user = _authService.currentUser;

      setLoading(false);

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          MainScreen.routeName,
          arguments: 0,
              (route) => false,
        );
      }
    } catch (e) {
      setLoading(false);
      if (context.mounted) {
        showSnackBar(context, e.toString());
      }
    }
  }

  // --- Forgot Password Function ---
  Future<void> forgetPasswordFunction({
    required BuildContext context,
    required String email,
  }) async {
    if (email.isEmpty) {
      showSnackBar(context, "Please enter your email");
      return;
    }

    setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(email);
      setLoading(false);
      if (context.mounted) {
        showSnackBar(context, "Reset link sent! Check your email.");
        Navigator.pop(context);
      }
    } catch (e) {
      setLoading(false);
      if (context.mounted) {
        showSnackBar(context, e.toString());
      }
    }
  }

  // --- Resend Verification Email ---
  Future<void> resendVerificationEmail(BuildContext context) async {
    try {
      await _authService.sendVerificationEmail();
      if (context.mounted) {
        showSnackBar(context, "Verification email sent.");
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, e.toString());
      }
    }
  }
}