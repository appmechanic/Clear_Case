
import 'package:clearcase/models/remainder_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';


class ReminderProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Helper for consistent UI feedback
  void showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // --- Add Reminder ---
  Future<void> addReminder(BuildContext context, String caseId, ReminderModel reminder) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(caseId)
          .collection('reminders')
          .add(reminder.toMap());

      _isLoading = false;
      notifyListeners();
      showSnackBar(context, "Reminder added successfully!");
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      showSnackBar(context, "Error: ${e.toString()}");
    }
  }

  // --- Update Reminder ---
  Future<void> updateReminder(BuildContext context, ReminderModel reminder) async {
    final user = _auth.currentUser;
    if (user == null || reminder.id == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(reminder.caseId)
          .collection('reminders')
          .doc(reminder.id)
          .update(reminder.toMap());

      _isLoading = false;
      notifyListeners();
      showSnackBar(context, "Reminder updated successfully!");
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      showSnackBar(context, "Error: ${e.toString()}");
    }
  }

  // --- Fetch Record ---
  Future<ReminderModel?> getReminderById(String caseId, String reminderId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(caseId)
          .collection('reminders')
          .doc(reminderId)
          .get();

      return doc.exists ? ReminderModel.fromMap(doc.data()!, doc.id) : null;
    } catch (e) {
      debugPrint("Error fetching reminder: $e");
      return null;
    }
  }
}