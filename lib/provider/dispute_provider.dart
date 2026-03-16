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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)));
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

      // 1. Upload Attachments to Firebase Storage
      for (var file in attachments) {
        // IMPROVEMENT: Preserve the original file extension (e.g., .pdf, .jpg)
        String extension = file.path
            .split('.')
            .last;
        String fileName = "${DateTime
            .now()
            .millisecondsSinceEpoch}_${attachments.indexOf(file)}.$extension";

        Reference ref = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/cases/$caseId/disputeRecords/$fileName');

        // Optional: Set metadata so the browser/app knows the file type
        UploadTask uploadTask = ref.putFile(file);

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        fileUrls.add(downloadUrl);
      }

      // 2. Add Dispute to Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(caseId)
          .collection('disputeRecords')
          .add({
        ...data,
        'caseId': caseId,
        'attachments': fileUrls, // Now contains URLs for images AND docs
        'createdAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();

      _showSnackBar(context, "Dispute added successfully!");
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      // GENTLE CORRECTION: Provide more specific feedback if it's a storage issue
      debugPrint("Upload Error: $e");
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

      // 1. Upload only NEW files
      for (var file in newAttachments) {
        String extension = file.path
            .split('.')
            .last;
        String fileName = "${DateTime
            .now()
            .millisecondsSinceEpoch}_${newAttachments.indexOf(
            file)}.$extension";

        Reference ref = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/cases/$caseId/disputeRecords/$fileName');

        TaskSnapshot snapshot = await ref.putFile(file);
        String downloadUrl = await snapshot.ref.getDownloadURL();
        finalUrls.add(downloadUrl);
      }

      // Prepare updated data
      Map<String, dynamic> updatedData = {
        ...data,
        'attachments': finalUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 2. Use WriteBatch for Atomic Operations
      WriteBatch batch = _firestore.batch();

      // Reference to the main document
      DocumentReference disputeRef = _firestore
          .collection('users').doc(user.uid)
          .collection('cases').doc(caseId)
          .collection('disputeRecords').doc(disputeId);

      batch.update(disputeRef, updatedData);

      // 3. Handle Flagged Events
      var flaggedQuery = await _firestore
          .collection('users').doc(user.uid)
          .collection('flaggedEvents')
          .where('originId', isEqualTo: disputeId)
          .get();

      if (data['flagEntry'] == true) {
        if (flaggedQuery.docs.isEmpty) {
          // Create new flagged entry
          DocumentReference newFlagRef = _firestore.collection('users').doc(
              user.uid).collection('flaggedEvents').doc();
          batch.set(newFlagRef, {
            ...updatedData,
            'originCollection': 'disputeRecords',
            'originId': disputeId
          });
        } else {
          // Update existing flagged entry
          batch.update(flaggedQuery.docs.first.reference, updatedData);
        }
      } else {
        // Remove flag if flagEntry is false
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
      debugPrint("Update Error: $e");
      _showSnackBar(context, "Error updating: ${e.toString()}");
    }
  }
}