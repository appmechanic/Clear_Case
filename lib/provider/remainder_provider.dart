
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/remainder_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class ReminderProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase');

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<CaseModel> _userCases = [];
  List<CaseModel> get userCases => _userCases;

  CaseModel? _selectedCase;
  CaseModel? get selectedCase => _selectedCase;

  // --- Init ---
  void init() {
    _fetchUserCases();
  }

  // 1. Fetch Cases for Dropdown
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

        _userCases = snapshot.docs.map((doc) {
          CaseModel c = CaseModel.fromMap(doc.data() as Map<String, dynamic>);
          c.id = doc.id;
          return c;
        }).toList();

        // Default to the first case if available
        if (_userCases.isNotEmpty) {
          _selectedCase = _userCases.first;
        }
        notifyListeners();
      } catch (e) {
        debugPrint("Error fetching cases: $e");
      }
    }
  }

  // 2. Select Case
  void selectCase(CaseModel? newCase) {
    _selectedCase = newCase;
    notifyListeners();
  }

  // 3. Add Reminder
  Future<void> addReminder(BuildContext context, ReminderModel reminder) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a case first")));
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // PATH: users/{uid}/cases/{caseId}/reminders/
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(_selectedCase!.id)
          .collection('reminders') // Correct spelling usually 'reminders'
          .add(reminder.toMap());

      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder added successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- Fetch single record by ID ---
  Future<ReminderModel?> getReminderById(String caseId, String reminderId) async {
    try {
      final doc = await _firestore
          .collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(caseId)
          .collection('reminders').doc(reminderId).get();

      if (doc.exists) {
        return ReminderModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint("Error fetching reminder: $e");
    }
    return null;
  }

// --- Update record ---
  Future<void> updateReminder(BuildContext context, ReminderModel reminder) async {
    _isLoading = true; notifyListeners();
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(reminder.caseId)
          .collection('reminders').doc(reminder.id).update(reminder.toMap());

      _isLoading = false; notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder updated!")));
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false; notifyListeners();
      debugPrint("Error updating reminder: $e");
    }
  }
}