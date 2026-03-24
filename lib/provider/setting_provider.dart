
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/user_model.dart';
import 'package:clearcase/views/auth/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

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
  bool _pushNotificationsEnabled = true;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  
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

          // Parse Settings (stored in user doc)
          if (data.containsKey('pushNotificationsEnabled')) {
            _pushNotificationsEnabled = data['pushNotificationsEnabled'];
          }
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
    _pushNotificationsEnabled = value;
    notifyListeners();
    _saveSettingsToFirebase();
  }

  // Update Time
  Future<void> updateNotificationTime(TimeOfDay newTime) async {
    _notificationTime = newTime;
    notifyListeners();
    _saveSettingsToFirebase();
  }

  // Save to Firebase (Helper)
  Future<void> _saveSettingsToFirebase() async {
    final user = _auth.currentUser;
    if (user != null) {
      final timeString = "${_notificationTime.hour}:${_notificationTime.minute}";
      await _firestore.collection('users').doc(user.uid).update({
        'pushNotificationsEnabled': _pushNotificationsEnabled,
        'notificationTime': timeString,
      });
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

   // Logout
  Future<void> logout(BuildContext context) async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, LoginScreen.routeName, (route) => false);
    }
  }

  Future<void> deleteUserAccount(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // 1. Storage Cleanup: Delete the entire /users/{uid} folder
      final storageUserRef = FirebaseStorage.instance.ref().child('users').child(user.uid);
      await _deleteStorageFolder(storageUserRef);

      // 2. Firestore Cleanup: Loop through all cases
      final casesSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .get();

      for (var caseDoc in casesSnapshot.docs) {
         final caseRef = caseDoc.reference;

        // Clean up sub-collections for each case
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
          await subBatch.commit(); // Batch per sub-collection to avoid limits
        }

        // Delete the case document itself
        await caseRef.delete();
      }

      // 3. Delete the main User document
      await _firestore.collection('users').doc(user.uid).delete();

      // 4. Delete Firebase Auth User
      // Note: If user hasn't logged in recently, this might throw a 'requires-recent-login' error
      await user.delete();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, LoginScreen.routeName, (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account and all data deleted successfully."))
        );
      }
    } catch (e) {
      debugPrint("Account Deletion Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Deletion failed. You may need to re-login to perform this action."))
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}