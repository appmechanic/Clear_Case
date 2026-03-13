import 'dart:io';
import 'package:clearcase/models/custody_model.dart';
import 'package:clearcase/models/payment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';


class NewEntryProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Helper method to upload file and get URL
  Future<String?> uploadAttachment(File file, String category, String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
      Reference ref = _storage.ref().child('users/${user.uid}/cases/$caseId/$category/$fileName');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Storage Error: $e");
      return null;
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // --- CUSTODY METHODS ---

  Future<void> addCustodyRecord(
      BuildContext context, String caseId, CustodyRecordModel record, List<File> imageFiles) async {
    final user = _auth.currentUser;
    if (user == null) return;
    _isLoading = true; notifyListeners();

    try {
      List<String> downloadUrls = [];
      for (File file in imageFiles) {
        String? url = await uploadAttachment(file, 'custody_attachments', caseId);
        if (url != null) downloadUrls.add(url);
      }
      Map<String, dynamic> recordData = record.toMap();
      recordData['attachmentUrls'] = downloadUrls;

      WriteBatch batch = _firestore.batch();
      DocumentReference ref = _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId).collection('custodyRecords').doc();
      batch.set(ref, recordData);

      if (record.flagEntry == true) {
        DocumentReference flaggedRef = _firestore.collection('users').doc(user.uid).collection('flaggedEvents').doc();
        batch.set(flaggedRef, {...recordData, 'originCollection': 'custodyRecords', 'originId': ref.id});
      }

      await batch.commit();
      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        _showSnackBar(context, "Custody record added successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      _showSnackBar(context, "Error adding record: ${e.toString()}");
    }
  }

  Future<void> updateCustodyRecord(
      BuildContext context, String caseId, CustodyRecordModel record, List<File> newImageFiles) async {
    final user = _auth.currentUser;
    if (user == null || record.id == null) return;
    _isLoading = true; notifyListeners();

    try {
      List<String> updatedUrls = List.from(record.attachmentUrls ?? []);
      for (File file in newImageFiles) {
        String? url = await uploadAttachment(file, 'custody_attachments', caseId);
        if (url != null) updatedUrls.add(url);
      }
      Map<String, dynamic> recordData = record.toMap();
      recordData['attachmentUrls'] = updatedUrls;

      WriteBatch batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(user.uid).collection('cases').doc(caseId).collection('custodyRecords').doc(record.id), recordData);

      var flaggedQuery = await _firestore.collection('users').doc(user.uid).collection('flaggedEvents').where('originId', isEqualTo: record.id).get();
      if (record.flagEntry == true) {
        if (flaggedQuery.docs.isEmpty) {
          batch.set(_firestore.collection('users').doc(user.uid).collection('flaggedEvents').doc(), {...recordData, 'originCollection': 'custodyRecords', 'originId': record.id});
        } else {
          batch.update(flaggedQuery.docs.first.reference, recordData);
        }
      } else {
        for (var doc in flaggedQuery.docs) batch.delete(doc.reference);
      }
      await batch.commit();
      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        _showSnackBar(context, "Record updated successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      _showSnackBar(context, "Error update record: ${e.toString()}");
    }
  }

  Future<CustodyRecordModel?> getCustodyRecordById(String caseId, String recordId) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId).collection('custodyRecords').doc(recordId).get();
    return doc.exists ? CustodyRecordModel.fromMap(doc.data()!, doc.id) : null;
  }

  // --- PAYMENT METHODS ---

// --- CORRECTED PAYMENT METHODS ---

  Future<PaymentRecordModel?> getPaymentRecordById(String caseId, String recordId) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .doc(caseId)
        .collection('paymentRecords')
        .doc(recordId)
        .get();

    // Fixed: Ensure the return type is PaymentRecordModel
    return doc.exists ? PaymentRecordModel.fromMap(doc.data()!, doc.id) : null;
  }

  Future<void> addPaymentRecord(
      BuildContext context, String caseId, PaymentRecordModel record, List<File> imageFiles) async {
    final user = _auth.currentUser;
    if (user == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      List<String> downloadUrls = [];
      for (File file in imageFiles) {
        String? url = await uploadAttachment(file, 'payment_attachments', caseId);
        if (url != null) downloadUrls.add(url);
      }
      Map<String, dynamic> data = record.toMap();
      data['attachmentUrls'] = downloadUrls;

      WriteBatch batch = _firestore.batch();
      DocumentReference ref = _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId).collection('paymentRecords').doc();
      batch.set(ref, data);

      if (record.flagEntry == true) {
        DocumentReference flaggedRef = _firestore.collection('users').doc(user.uid).collection('flaggedEvents').doc();
        batch.set(flaggedRef, {...data, 'originCollection': 'paymentRecords', 'originId': ref.id});
      }

      await batch.commit();
      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        _showSnackBar(context, "Payment record added successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      _showSnackBar(context, "Error adding record: ${e.toString()}");
    }
  }

  Future<void> updatePaymentRecord(
      BuildContext context, String caseId, PaymentRecordModel record, List<File> newFiles) async {
    final user = _auth.currentUser;
    if (user == null || record.id == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      List<String> updatedUrls = List.from(record.attachmentUrls ?? []);
      for (File file in newFiles) {
        String? url = await uploadAttachment(file, 'payment_attachments', caseId);
        if (url != null) updatedUrls.add(url);
      }
      Map<String, dynamic> data = record.toMap();
      data['attachmentUrls'] = updatedUrls;

      WriteBatch batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(user.uid).collection('cases').doc(caseId).collection('paymentRecords').doc(record.id), data);

      var flaggedQuery = await _firestore.collection('users').doc(user.uid).collection('flaggedEvents').where('originId', isEqualTo: record.id).get();

      if (record.flagEntry == true) {
        if (flaggedQuery.docs.isEmpty) {
          batch.set(_firestore.collection('users').doc(user.uid).collection('flaggedEvents').doc(), {
            ...data,
            'originCollection': 'paymentRecords',
            'originId': record.id
          });
        } else {
          batch.update(flaggedQuery.docs.first.reference, data);
        }
      } else {
        for (var doc in flaggedQuery.docs) batch.delete(doc.reference);
      }

      await batch.commit();
      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        _showSnackBar(context, "Payment record updated successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      _showSnackBar(context, "Error updating record: ${e.toString()}");
    }
  }
}