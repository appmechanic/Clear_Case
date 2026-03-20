import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class DisputeProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> addDispute({
    required BuildContext context,
    required String caseId,
    required Map<String, dynamic> data,
    required List<File> attachments,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      List<String> fileUrls = [];

      for (var file in attachments) {
        String extension = file.path.split('.').last;
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${attachments.indexOf(file)}.$extension";

        Reference ref = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/cases/$caseId/disputeRecords/$fileName');

        TaskSnapshot snapshot = await ref.putFile(file);
        String downloadUrl = await snapshot.ref.getDownloadURL();
        fileUrls.add(downloadUrl);
      }

      final Map<String, dynamic> recordData = {
        ...data,
        'caseId': caseId,
        'disputeStatus': data['disputeStatus'] ?? 'Open', // Ensure default here
        'attachments': fileUrls,
        'createdAt': FieldValue.serverTimestamp(),
      };

      WriteBatch batch = _firestore.batch();

      // 1. Reference for Dispute Record
      DocumentReference disputeRef = _firestore
          .collection('users').doc(user.uid)
          .collection('cases').doc(caseId)
          .collection('disputeRecords').doc();

      batch.set(disputeRef, recordData);

      // 2. Handle Flagged Events (NEW PATH)
      if (data['flagEntry'] == true) {
        DocumentReference flaggedRef = _firestore
            .collection('users').doc(user.uid)
            .collection('cases').doc(caseId) // Path changed
            .collection('flaggedEvents').doc();

        batch.set(flaggedRef, {
          ...recordData,
          'originCollection': 'disputeRecords',
          'originId': disputeRef.id,
        });
      }

      await batch.commit();

      _isLoading = false;
      notifyListeners();

      _showSnackBar(context, "Dispute added successfully!");
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      _showSnackBar(context, "Failed to save: ${e.toString()}");
    }
  }

  Future<void> updateDispute({
    required BuildContext context,
    required String caseId,
    required String disputeId,
    required Map<String, dynamic> data,
    required List<File> newAttachments,
    required List<String> existingUrls,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      List<String> finalUrls = List.from(existingUrls);

      for (var file in newAttachments) {
        String extension = file.path.split('.').last;
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${newAttachments.indexOf(file)}.$extension";

        Reference ref = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/cases/$caseId/disputeRecords/$fileName');

        TaskSnapshot snapshot = await ref.putFile(file);
        String downloadUrl = await snapshot.ref.getDownloadURL();
        finalUrls.add(downloadUrl);
      }

      Map<String, dynamic> updatedData = {
        ...data,
        'attachments': finalUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      WriteBatch batch = _firestore.batch();

      DocumentReference disputeRef = _firestore
          .collection('users').doc(user.uid)
          .collection('cases').doc(caseId)
          .collection('disputeRecords').doc(disputeId);

      batch.update(disputeRef, updatedData);

      // 3. Handle Flagged Events (NEW PATH)
      var flaggedQuery = await _firestore
          .collection('users').doc(user.uid)
          .collection('cases').doc(caseId) // Path changed for query
          .collection('flaggedEvents')
          .where('originId', isEqualTo: disputeId)
          .get();

      if (data['flagEntry'] == true) {
        if (flaggedQuery.docs.isEmpty) {
          DocumentReference newFlagRef = _firestore
              .collection('users').doc(user.uid)
              .collection('cases').doc(caseId) // Path changed for new doc
              .collection('flaggedEvents').doc();

          batch.set(newFlagRef, {
            ...updatedData,
            'originCollection': 'disputeRecords',
            'originId': disputeId,
            'caseId': caseId
          });
        } else {
          batch.update(flaggedQuery.docs.first.reference, updatedData);
        }
      } else {
        for (var doc in flaggedQuery.docs) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      _showSnackBar(context, "Dispute updated successfully!");
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      _showSnackBar(context, "Error updating: ${e.toString()}");
    }
  }
}