
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/user_model.dart';
import 'package:clearcase/views/auth/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../core/utils/helping_functions.dart';
import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Use your named database instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(), 
    databaseId: 'clearcase'
  );

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Data Holders
  UserModel? _userProfile;
  UserModel? get userProfile => _userProfile;

  List<CaseModel> _cases = [];
  List<CaseModel> get cases => _cases;

  // Notification Settings

  bool _isScheduledDatesEnabled = true;
  bool _isRemindersEnabled = true;
  bool _isDailyReminderEnabled = false;

  bool get isScheduledDatesEnabled => _isScheduledDatesEnabled;
  bool get isRemindersEnabled => _isRemindersEnabled;
  bool get isDailyReminderEnabled => _isDailyReminderEnabled;

  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay get notificationTime => _notificationTime;

  // --- INIT ---
  void init() {
    _fetchUserData();
    _fetchUserCases();
  }


  Future<void> refreshData() async {
      await Future.wait([
      _fetchUserData(),
      _fetchUserCases(),
    ]);
    notifyListeners();
  }

  // 1. Fetch User Profile & Settings
  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Parse Profile
          _userProfile = UserModel.fromMap(data);

          // Parse the 3 new toggles
          _isScheduledDatesEnabled = data['isScheduledDatesEnabled'] ?? true;
          _isRemindersEnabled = data['isRemindersEnabled'] ?? true;
          _isDailyReminderEnabled = data['isDailyReminderEnabled'] ?? false;

          if (data.containsKey('notificationTime')) {
            // Stored as "HH:mm" string
            final timeParts = (data['notificationTime'] as String).split(':');
            _notificationTime = TimeOfDay(
              hour: int.parse(timeParts[0]), 
              minute: int.parse(timeParts[1])
            );
          }
        }
      } catch (e) {
        debugPrint("Error fetching profile: $e");
      }
    }
    notifyListeners();
  }


  void toggleScheduledDates(bool val) {
    _isScheduledDatesEnabled = val;
    notifyListeners();
    _saveSettingsToFirebase();
  }

  void toggleReminders(bool val) {
    _isRemindersEnabled = val;
    notifyListeners();
    _saveSettingsToFirebase();
  }

  void toggleDailyReminder(bool val) {
    _isDailyReminderEnabled = val;
    notifyListeners();
    _saveSettingsToFirebase();
  }

  // 2. Fetch Cases List
  Future<void> _fetchUserCases() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cases')
            .orderBy('createdAt', descending: true)
            .get();

        _cases = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Assign doc ID strictly
          CaseModel c = CaseModel.fromMap(data); 
          c.id = doc.id; 
          return c;
        }).toList();

      } catch (e) {
        debugPrint("Error fetching cases: $e");
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  // --- ACTIONS ---

  // Update Push Notification Toggle
  Future<void> toggleNotifications(bool value) async {
    notifyListeners();
    _saveSettingsToFirebase();
  }

  // Update Time
  Future<void> updateNotificationTime(TimeOfDay newTime) async {
    _notificationTime = newTime;
    notifyListeners();
    _saveSettingsToFirebase();
  }


  Future<void> _saveSettingsToFirebase() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // 1. டைம்ஜோன் பெயரைப் பெறுதல்
        final dynamic tz = await FlutterTimezone.getLocalTimezone();
        String rawTz = tz.toString();

        // அசிங்கமான வரியிலிருந்து "Asia/Kolkata" வை மட்டும் பிரித்தல்
        String currentTimeZone = rawTz.contains('(')
            ? rawTz.split('(')[1].split(',')[0]
            : rawTz;

        // 2. UTC Offset-ஐக் கணக்கிடுதல்
        final offset = DateTime.now().timeZoneOffset;
        final String offsetString = "${offset.isNegative ? '-' : '+'}${offset.inHours.toString().padLeft(2, '0').replaceFirst('-', '')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}";

        // 3. நேரத்தை 24-மணிநேர பார்மட்டிற்கு மாற்றுதல்
        final String hour = _notificationTime.hour.toString().padLeft(2, '0');
        final String minute = _notificationTime.minute.toString().padLeft(2, '0');
        final timeString = "$hour:$minute";

        // 4. Firestore-இல் அப்டேட் செய்தல்
        // இங்கே உங்கள் '_firestore' வேரியபிளைப் பயன்படுத்துகிறோம்
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'isScheduledDatesEnabled': _isScheduledDatesEnabled,
          'isRemindersEnabled': _isRemindersEnabled,
          'isDailyReminderEnabled': _isDailyReminderEnabled,
          'notificationTime': timeString,
          'timezone': currentTimeZone,
          'utcOffset': offsetString,
        });

        debugPrint("✅ Settings & Timezone updated successfully in 'clearcase' DB!");
      } catch (e) {
        debugPrint("❌ Error saving settings: $e");
      }
    }
  }
  // Delete Case

  Future<void> deleteCase(BuildContext context, String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // 1. DELETE ALL FILES IN STORAGE FOR THIS CASE
      // Path: /users/{uid}/cases/{caseId}/
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('cases')
          .child(caseId);

      await _deleteStorageFolder(storageRef);

      // 2. DELETE ALL FIRESTORE DATA (Records & Sub-collections)
      final WriteBatch batch = _firestore.batch();
      final DocumentReference caseRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(caseId);

      List<String> subCollections = [
        'custodyRecords', 'paymentRecords', 'breachRecords',
        'scheduledRules', 'flaggedEvents', 'disputeRecords', 'reminders',
      ];

      for (String subName in subCollections) {
        final querySnapshot = await caseRef.collection(subName).get();
        for (var doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      // Delete the main case document
      batch.delete(caseRef);

      // Commit all Firestore deletions at once
      await batch.commit();

      // 3. UPDATE LOCAL UI
      _cases.removeWhere((c) => c.id == caseId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Case, all records, and storage files deleted."))
        );
      }
    } catch (e) {
      debugPrint("Full Delete Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recursive helper to delete all files and sub-folders in a Storage path
  Future<void> _deleteStorageFolder(Reference ref) async {
    try {
      final listResult = await ref.listAll();

      // Delete all files in the current directory
      for (var item in listResult.items) {
        await item.delete();
      }

      // Recursively delete sub-folders (like /payment_attachments/)
      for (var prefix in listResult.prefixes) {
        await _deleteStorageFolder(prefix);
      }
    } catch (e) {
      debugPrint("Storage folder cleanup error: $e");
    }
  }

  Future<void> logout(BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    try {
      // FIRST: Cleanup notification tokens while user is still authenticated
      await PushNotificationService.deleteTokenOnLogout();

      // SECOND: Sign out from Firebase Auth
      await _auth.signOut();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context,
            LoginScreen.routeName,
                (route) => false
        );
      }
    } catch (e) {
      // Fallback sign out if something fails
      await _auth.signOut();
      if (context.mounted) showSnackBar(context, "Logged out with errors");
    } finally {
      _isLoading = true;
      notifyListeners();
    }
  }

  Future<void> deleteUserAccount(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // --- STEP 1: PRE-EMPTIVE AUTH CHECK ---
      // We attempt a "dry run" or check if deletion is possible.
      // If the session is old, this throws 'requires-recent-login' immediately,
      // before any Firestore or Storage data is deleted.
      // We can use reauthenticate or simply attempt a tiny operation,
      // but the most reliable way is to try the delete early or check the time.

      // Check: Has the user logged in within the last 5 minutes?
      final lastSignIn = user.metadata.lastSignInTime;
      final now = DateTime.now();
      if (lastSignIn != null && now.difference(lastSignIn).inMinutes > 5) {
        throw FirebaseAuthException(code: 'requires-recent-login');
      }

      // --- STEP 2: NOTIFICATION CLEANUP ---
      await PushNotificationService.deleteTokenOnLogout();

      // --- STEP 3: STORAGE CLEANUP ---
      final storageUserRef = FirebaseStorage.instance.ref().child('users').child(user.uid);
      await _deleteStorageFolder(storageUserRef);

      // --- STEP 4: FIRESTORE CLEANUP ---
      final casesSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .get();

      for (var caseDoc in casesSnapshot.docs) {
        final caseRef = caseDoc.reference;
        List<String> subCollections = [
          'custodyRecords', 'paymentRecords', 'breachRecords',
          'scheduledRules', 'flaggedEvents', 'disputeRecords', 'reminders',
        ];

        for (String subName in subCollections) {
          final subSnapshot = await caseRef.collection(subName).get();
          final subBatch = _firestore.batch();
          for (var doc in subSnapshot.docs) {
            subBatch.delete(doc.reference);
          }
          await subBatch.commit();
        }
        await caseRef.delete();
      }

      // --- STEP 5: DOCUMENT & ACCOUNT DELETION ---
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, LoginScreen.routeName, (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account and all data deleted successfully."))
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Deletion Error: ${e.code}");
      if (context.mounted) {
        String message = "Deletion failed.";
        if (e.code == 'requires-recent-login') {
          message = "For security, please log out and back in, then try deleting your account again.";
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      debugPrint("General Deletion Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("An error occurred. Please try again."))
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}