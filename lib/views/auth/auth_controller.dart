
import 'package:clearcase/views/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/utils/helping_functions.dart';
import '../main_screen.dart';
import 'email_verification_screen.dart';

class AuthController {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController emptyController = TextEditingController();

  FocusNode emailFocusNode = FocusNode();
  FocusNode passwordFocusNode = FocusNode();
  FocusNode emptyFocusNode = FocusNode();

  bool isLoginValidate({required BuildContext context}) {
    if (!(emailController.text.contains('@') &&
        emailController.text.contains('.'))) {
      showSnackBar(context, "Enter valid email");
      return false;
    } else if (passwordController.text.isEmpty) {
      showSnackBar(context, "Password can't be empty");
      return false;
    }
    return true;
  }

  // Register Controller
  TextEditingController fullNameController = TextEditingController();
  TextEditingController otpController = TextEditingController();

  bool isRegisterValidate({required BuildContext context}) {
    if (!(emailController.text.contains('@') &&
        emailController.text.contains('.'))) {
      showSnackBar(context, "Enter valid email");
      return false;
    }else if (passwordController.text.isEmpty) {
      showSnackBar(context, "Password can't be empty");
      return false;
    } else if (fullNameController.text.isEmpty) {
      showSnackBar(context, "Name can't be empty");
      return false;
    } else if (passwordController.text.length < 6) {
      showSnackBar(context, "Passwords should be at least 6 characters");
      return false;
    }
    return true;
  }

  bool isEmailValidate({required BuildContext context}) {
    if (!(emailController.text.contains('@') &&
        emailController.text.contains('.'))) {
      showSnackBar(context, "Enter valid email");
      return false;
    }else if (fullNameController.text.isEmpty) {
      showSnackBar(context, "Name can't be empty");
      return false;
    }
    return true;
  }

  // FocusNode
  FocusNode fullNameFocusNode = FocusNode();
  FocusNode otpFocusNode = FocusNode();

  navigateFunction(BuildContext context) async {
    await Future.delayed(const Duration(seconds: 1));

    User? user = FirebaseAuth.instance.currentUser;

    if (context.mounted) {
      if (user != null) {
        if (user.emailVerified) {
          Navigator.pushReplacementNamed(context, MainScreen.routeName, arguments: 0);
        } else {
          Navigator.pushReplacementNamed(context, EmailVerificationScreen.routeName);
        }
      } else {
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    }
  }
}