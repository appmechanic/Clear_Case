import 'package:clearcase/core/utils/helping_functions.dart';
import 'package:clearcase/provider/setting_provider.dart';
import 'package:clearcase/views/home/case_setup_screen.dart';
import 'package:clearcase/views/main_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../views/auth/email_verification_screen.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'clearcase'
  );

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void>  signUpFunction({
    required BuildContext context,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    setLoading(true);
    try {
      UserCredential userCredential = await _authService.signUp(email: email, password: password);
      User? user = userCredential.user;
      await _authService.updateUserName("$firstName $lastName");

      final dynamic tz = await FlutterTimezone.getLocalTimezone();

       String rawTz = tz.toString();
      String currentTimeZone = rawTz.contains('(')
          ? rawTz.split('(')[1].split(',')[0]
          : rawTz;

      print("Clean Timezone: $currentTimeZone");
      final offset = DateTime.now().timeZoneOffset;
      final String offsetString = "${offset.isNegative ? '-' : '+'}${offset.inHours.toString().padLeft(2, '0').replaceFirst('-', '')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}";
        await _firestore.collection('users').doc(user?.uid).set({
          'uid': user?.uid,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'createdAt': FieldValue.serverTimestamp(),
          'children': [],
          'isDailyReminderEnabled': false,
          'isRemindersEnabled': true,
          'notificationTime': "09:00",
          'timezone': currentTimeZone,
          'utcOffset': offsetString,
          });
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

  Future<void> loginFunction({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    setLoading(true);
    try {
      await _authService.login(email: email, password: password);
      User? user = _authService.currentUser;

      if (user != null && context.mounted) {

         String? token = await FirebaseMessaging.instance.getToken();

         final dynamic tz = await FlutterTimezone.getLocalTimezone();
        String rawTz = tz.toString();
        String currentTimeZone = rawTz.contains('(')
            ? rawTz.split('(')[1].split(',')[0]
            : rawTz;

        final offset = DateTime.now().timeZoneOffset;
        final String offsetString = "${offset.isNegative ? '-' : '+'}${offset.inHours.toString().padLeft(2, '0').replaceFirst('-', '')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}";

        Provider.of<SettingsProvider>(context, listen: false).init();

         if (token != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'fcmToken': token,
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
            'timezone': currentTimeZone,
            'utcOffset': offsetString,
          }, SetOptions(merge: true));
        }


        QuerySnapshot caseSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cases')
            .limit(1)
            .get();

        setLoading(false);

        if (context.mounted) {
          if (caseSnapshot.docs.isEmpty) {
            Navigator.pushReplacementNamed(context, CaseSetupScreen.routeName);
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              MainScreen.routeName,
              arguments: 0,
                  (route) => false,
            );
          }
        }
      } else {
        setLoading(false);
      }
    } catch (e) {
      setLoading(false);
      if (context.mounted) {
        showSnackBar(context, e.toString());
      }
    }
  }
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

  Future<void> resendVerificationEmail(BuildContext context) async {
    try {
      await _authService.sendVerificationEmail();
      if (context.mounted) {
        showSnackBar(context, "Verification email sent.");
      }
    } on FirebaseAuthException catch (e) { // Catch the specific Firebase error
      String message = "An error occurred. Please try again.";

      // Map specific codes to short messages
      if (e.code == 'too-many-requests') {
        message = "Too many attempts. Please try again later.";
      } else if (e.code == 'network-request-failed') {
        message = "Check your internet connection.";
      }

      if (context.mounted) {
        showSnackBar(context, message);
      }
      debugPrint("Firebase Error: ${e.code} - ${e.message}");
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, "Something went wrong.");
      }
    }
  }
}