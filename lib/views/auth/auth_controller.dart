import 'package:clearcase/views/auth/login_screen.dart';
import 'package:clearcase/views/home/case_setup_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../core/utils/helping_functions.dart';
import '../main_screen.dart';
import 'email_verification_screen.dart';

class AuthController {
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  FocusNode firstNameFocusNode = FocusNode();
  FocusNode lastNameFocusNode = FocusNode();
  FocusNode emailFocusNode = FocusNode();
  FocusNode passwordFocusNode = FocusNode();

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'clearcase',
  );

  bool isLoginValidate({required BuildContext context}) {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty && password.isEmpty) {
      showSnackBar(context, "Please enter your email and password.");
      return false;
    }
    else if (email.isEmpty) {
      showSnackBar(context, "Please enter your email address.");
      return false;
    }
    else if (!email.contains('@') || !email.contains('.')) {
      showSnackBar(context, "Please enter a valid email address.");
      return false;
    }
    else if (password.isEmpty) {
      showSnackBar(context, "Please enter your password.");
      return false;
    }
    return true;
  }

  bool isRegisterValidate({required BuildContext context}) {
    if (firstNameController.text.isEmpty) {
      showSnackBar(context, "First name can't be empty");
      return false;
    } else if (lastNameController.text.isEmpty) {
      showSnackBar(context, "Last name can't be empty");
      return false;
    } else if (!(emailController.text.contains('@') &&
        emailController.text.contains('.'))) {
      showSnackBar(context, "Please enter a valid email address.");
      return false;
    } else if (passwordController.text.isEmpty) {
      showSnackBar(context, "Please enter your password.");
      return false;
    } else if (passwordController.text.length < 6) {
      showSnackBar(context, "Passwords should be at least 6 characters");
      return false;
    }
    return true;
  }
  
  navigateFunction(BuildContext context) async {
    await Future.delayed(const Duration(seconds: 1));

    User? user = FirebaseAuth.instance.currentUser;

    if (context.mounted) {
      if (user != null) {
        if (user.emailVerified) {
          try {
            QuerySnapshot caseSnapshot = await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('cases')
                .limit(1)
                .get();

            if (context.mounted) {
              if (caseSnapshot.docs.isEmpty) {
                Navigator.pushNamedAndRemoveUntil(
                    context, CaseSetupScreen.routeName, (route) => false);
              } else {
                Navigator.pushNamedAndRemoveUntil(
                    context, MainScreen.routeName, (route) => false,
                    arguments: 0);
              }
            }
          } catch (e) {
            Navigator.pushNamedAndRemoveUntil(
                context, LoginScreen.routeName, (route) => false);
          }
        } else {
          Navigator.pushNamedAndRemoveUntil(
              context, EmailVerificationScreen.routeName, (route) => false);
        }
      } else {
        Navigator.pushNamedAndRemoveUntil(
            context, LoginScreen.routeName, (route) => false);
      }
    }
  }
}