
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/user_model.dart';
import 'package:clearcase/views/auth/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
    if (user != null) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cases')
            .doc(caseId)
            .delete();
        
        // Remove locally to update UI instantly
        _cases.removeWhere((c) => c.id == caseId);
        notifyListeners();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case deleted successfully")));
        }
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  // Logout
  Future<void> logout(BuildContext context) async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, LoginScreen.routeName, (route) => false);
    }
  }
}