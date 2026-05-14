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

  bool _isGoogleLoading = false;
  bool get isGoogleLoading => _isGoogleLoading;

  void setGoogleLoading(bool value) {
    _isGoogleLoading = value;
    notifyListeners();
  }

  // Backfills default notification settings on login for any user
  // whose doc is missing them (older accounts, edge cases).
  // Idempotent: never overwrites fields the user has already customized.
  Future<void> _ensureUserDefaults(String uid) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      final snap = await docRef.get();
      final data = (snap.data() as Map<String, dynamic>?) ?? {};

      final Map<String, dynamic> updates = {};
      if (!data.containsKey('isRemindersEnabled')) updates['isRemindersEnabled'] = true;
      if (!data.containsKey('isScheduledDatesEnabled')) updates['isScheduledDatesEnabled'] = true;
      if (!data.containsKey('isDailyReminderEnabled')) updates['isDailyReminderEnabled'] = false;
      if (!data.containsKey('notificationTime')) updates['notificationTime'] = '09:00';

      if (updates.isNotEmpty) {
        await docRef.set(updates, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('ensureUserDefaults failed: $e');
    }
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

      debugPrint("Clean Timezone: $currentTimeZone");
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
          'isScheduledDatesEnabled': true,
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

        await _ensureUserDefaults(user.uid);

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
  Future<void> googleSignInFunction({required BuildContext context}) async {
    setGoogleLoading(true);
    try {
      final UserCredential? userCredential = await _authService.signInWithGoogle();

      if (userCredential == null) {
        setGoogleLoading(false);
        return;
      }

      final User? user = userCredential.user;
      if (user == null) {
        setGoogleLoading(false);
        return;
      }

      final String? idToken = await user.getIdToken();
      if (idToken != null && idToken.isNotEmpty) {
        await setDataToLocal(key: 'firebase_id_token', value: idToken);
      }
      await setDataToLocal(key: 'auth_provider', value: 'google');

      final String? fcmToken = await FirebaseMessaging.instance.getToken();

      final dynamic tz = await FlutterTimezone.getLocalTimezone();
      final String rawTz = tz.toString();
      final String currentTimeZone = rawTz.contains('(')
          ? rawTz.split('(')[1].split(',')[0]
          : rawTz;

      final offset = DateTime.now().timeZoneOffset;
      final String offsetString =
          "${offset.isNegative ? '-' : '+'}${offset.inHours.toString().padLeft(2, '0').replaceFirst('-', '')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}";

      final DocumentReference userDocRef = _firestore.collection('users').doc(user.uid);
      final DocumentSnapshot userDoc = await userDocRef.get();

      final String fullName = user.displayName ?? '';
      final List<String> parts = fullName.trim().split(' ');
      final String firstName = parts.isNotEmpty ? parts.first : '';
      final String lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      if (!userDoc.exists) {
        await userDocRef.set({
          'uid': user.uid,
          'email': user.email,
          'firstName': firstName,
          'lastName': lastName,
          'photoUrl': user.photoURL,
          'authProvider': 'google',
          'createdAt': FieldValue.serverTimestamp(),
          'children': [],
          'isDailyReminderEnabled': false,
          'isRemindersEnabled': true,
          'isScheduledDatesEnabled': true,
          'notificationTime': "09:00",
          'timezone': currentTimeZone,
          'utcOffset': offsetString,
          if (fcmToken != null) 'fcmToken': fcmToken,
          if (fcmToken != null) 'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userDocRef.set({
          'timezone': currentTimeZone,
          'utcOffset': offsetString,
          if (fcmToken != null) 'fcmToken': fcmToken,
          if (fcmToken != null) 'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await _ensureUserDefaults(user.uid);

      if (context.mounted) {
        Provider.of<SettingsProvider>(context, listen: false).init();
      }

      final QuerySnapshot caseSnapshot = await userDocRef
          .collection('cases')
          .limit(1)
          .get();

      setGoogleLoading(false);

      if (context.mounted) {
        if (caseSnapshot.docs.isEmpty) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            CaseSetupScreen.routeName,
            (route) => false,
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
            MainScreen.routeName,
            (route) => false,
            arguments: 0,
          );
        }
      }
    } catch (e) {
      setGoogleLoading(false);
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