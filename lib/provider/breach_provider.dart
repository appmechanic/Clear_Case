import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class BreachProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> addBreach(BuildContext context, String caseId, Map<String, dynamic> data, List<File> files) async {
    final user = _auth.currentUser;
    if (user == null) return;
    _isLoading = true; notifyListeners();

    try {
      List<String> urls = [];
      for (var file in files) {
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
        Reference ref = FirebaseStorage.instance.ref().child('users/${user.uid}/cases/$caseId/breachRecords/$fileName');
        await ref.putFile(file);
        urls.add(await ref.getDownloadURL());
      }

      WriteBatch batch = _firestore.batch();
      DocumentReference ref = _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId).collection('breachRecords').doc();

      Map<String, dynamic> finalData = {...data, 'attachments': urls, 'createdAt': FieldValue.serverTimestamp()};
      batch.set(ref, finalData);

      if (data['flagEntry'] == true) {
        batch.set(_firestore.collection('users').doc(user.uid).collection('flaggedEvents').doc(),
            {...finalData, 'originCollection': 'breachRecords', 'originId': ref.id});
      }

      await batch.commit();
      _isLoading = false; notifyListeners();
      _showSnackBar(context, "Breach recorded!");
      Navigator.pop(context);
    } catch (e) {
      _isLoading = false; notifyListeners();
      _showSnackBar(context, "Error: $e");
    }
  }

  Future<void> updateBreach(BuildContext context, String caseId, String breachId, Map<String, dynamic> data, List<File> newFiles, List<String> existingUrls) async {
    final user = _auth.currentUser;
    if (user == null) return;
    _isLoading = true; notifyListeners();

    try {
      List<String> finalUrls = List.from(existingUrls);
      for (var file in newFiles) {
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
        Reference ref = FirebaseStorage.instance.ref().child('users/${user.uid}/cases/$caseId/breachRecords/$fileName');
        await ref.putFile(file);
        finalUrls.add(await ref.getDownloadURL());
      }

      Map<String, dynamic> updatedData = {...data, 'attachments': finalUrls, 'updatedAt': FieldValue.serverTimestamp()};
      WriteBatch batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(user.uid).collection('cases').doc(caseId).collection('breachRecords').doc(breachId), updatedData);

      var flaggedQuery = await _firestore.collection('users').doc(user.uid).collection('flaggedEvents').where('originId', isEqualTo: breachId).get();
      if (data['flagEntry'] == true) {
        if (flaggedQuery.docs.isEmpty) {
          batch.set(_firestore.collection('users').doc(user.uid).collection('flaggedEvents').doc(), {...updatedData, 'originCollection': 'breachRecords', 'originId': breachId});
        } else {
          batch.update(flaggedQuery.docs.first.reference, updatedData);
        }
      } else {
        for (var doc in flaggedQuery.docs) batch.delete(doc.reference);
      }

      await batch.commit();
      _isLoading = false; notifyListeners();
      _showSnackBar(context, "Breach updated!");
      Navigator.pop(context);
    } catch (e) {
      _isLoading = false; notifyListeners();
      _showSnackBar(context, "Error: $e");
    }
  }
}