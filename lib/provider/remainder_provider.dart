import 'package:clearcase/models/remainder_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/utils/helping_functions.dart';

class ReminderProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  CollectionReference<Map<String, dynamic>> _reminders(String uid, String caseId) =>
      _firestore.collection('users').doc(uid).collection('cases').doc(caseId).collection('reminders');

  // Runs [write], then reports and closes the form. Shared by add and update.
  Future<void> _save(BuildContext context, String message, Future<void> Function(String uid) write) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      await write(user.uid);
      _isLoading = false;
      notifyListeners();
      if (context.mounted) {
        showSnackBar(context, message);
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (context.mounted) showSnackBar(context, "Error: ${e.toString()}");
    }
  }

  Future<void> addReminder(BuildContext context, ReminderModel reminder) {
    return _save(context, "Reminder added", (uid) async {
      await _reminders(uid, reminder.caseId).add(reminder.toMap());
    });
  }

  Future<void> updateReminder(BuildContext context, ReminderModel reminder) {
    if (reminder.id == null) return Future.value();
    return _save(context, "Reminder updated", (uid) async {
      await _reminders(uid, reminder.caseId).doc(reminder.id).update(reminder.toMap());
    });
  }

  /// Deletes a reminder — for a repeated one, the whole series.
  Future<void> deleteReminder(BuildContext context, String caseId, String reminderId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _reminders(user.uid, caseId).doc(reminderId).delete();
      if (context.mounted) showSnackBar(context, "Reminder deleted");
    } catch (e) {
      if (context.mounted) showSnackBar(context, "Error: ${e.toString()}");
    }
  }

  Future<ReminderModel?> getReminderById(String caseId, String reminderId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _reminders(user.uid, caseId).doc(reminderId).get();
      return doc.exists ? ReminderModel.fromMap(doc.data()!, doc.id) : null;
    } catch (e) {
      debugPrint("Error fetching reminder: $e");
      return null;
    }
  }
}
