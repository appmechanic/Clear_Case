import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class DisputeInsightsProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'clearcase',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<dynamic> _allDisputes = [];
  List<dynamic> _filteredDisputes = [];
  bool _isLoading = false;

  // Stats for Header
  int commCount = 0;
  int transferCount = 0;
  int paymentCount = 0;
  int openCount = 0;
  int resolvedCount = 0;

  List<dynamic> get disputes => _filteredDisputes;

  bool get isLoading => _isLoading;

  Future<void> fetchDisputes(String caseId) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _isLoading = true;
    _resetStats();
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('cases')
          .doc(caseId)
          .collection('disputeRecords')
          .orderBy('date', descending: true)
          .get();

      // 1. Map the documents to their data maps first
      final List<Map<String, dynamic>> tempDisputes = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['caseId'] = caseId; // Helpful for deep linking later
        _calculateStats(data);
        return data;
      }).toList();

      // 2. Fetch all log counts in parallel for better performance
      await Future.wait(tempDisputes.map((dispute) async {
        final logSnap = await _db.collection('users').doc(userId).collection('cases')
            .doc(caseId)
            .collection('disputeRecords')
            .doc(dispute['id'])
            .collection('logs')
            .count() // Uses the efficient aggregation query
            .get();

        dispute['logCount'] = logSnap.count ?? 0;
      }));

      _allDisputes = tempDisputes;
      _filteredDisputes = List.from(_allDisputes);

    } catch (e) {
      debugPrint("Error fetching disputes: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  void _calculateStats(Map<String, dynamic> data) {
    final category = data['category'] ?? "";
    final status = data['disputeStatus'] ?? "Open";

    if (category == "Communication")
      commCount++;
    else if (category == "Transfer Issues")
      transferCount++;
    else if (category == "Payment Disputes") paymentCount++;

    if (status == "Open")
      openCount++;
    else if (status == "Resolved") resolvedCount++;
  }

  void _resetStats() {
    commCount = 0;
    transferCount = 0;
    paymentCount = 0;
    openCount = 0;
    resolvedCount = 0;
  }

  void filterDisputes(String query) {
    if (query.isEmpty) {
      _filteredDisputes = List.from(_allDisputes);
    } else {
      _filteredDisputes = _allDisputes.where((d) {
        final status = (d['disputeStatus'] ?? "").toString().toLowerCase();
        final cat = (d['category'] ?? "").toString().toLowerCase();
        final name = (d['name'] ?? "").toString().toLowerCase();
        return status.contains(query.toLowerCase()) ||
            cat.contains(query.toLowerCase()) ||
            name.contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  // Inside DisputeInsightsProvider class
// 1. Stream for the parent dispute
  Stream<DocumentSnapshot> getDisputeStream(String caseId, String disputeId) {
    return _db.collection('users').doc(_auth.currentUser?.uid)
        .collection('cases').doc(caseId)
        .collection('disputeRecords').doc(disputeId).snapshots();
  }

// 2. Stream for the sub-collection logs
  Stream<List<Map<String, dynamic>>> getDisputeLogs(String caseId,
      String disputeId) {
    return _db.collection('users').doc(_auth.currentUser?.uid)
        .collection('cases').doc(caseId)
        .collection('disputeRecords').doc(disputeId)
        .collection('logs').orderBy('createdAt', descending: true).snapshots()
        .map((snap) =>
        snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

// 3. Unified Save Log (Add or Edit)
  Future<void> saveLog({
    required String caseId,
    required String disputeId,
    String? logId,
    required String title,
    required String desc,
    List<File>? files,
    List<String>? remainingUrls, // <--- Add this to keep track of what wasn't deleted
  }) async {
    final userId = _auth.currentUser?.uid;
    List<String> finalUrls = remainingUrls ?? [];

    // Upload new files
    if (files != null && files.isNotEmpty) {
      for (var file in files) {
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${files.indexOf(file)}";
        Reference ref = FirebaseStorage.instance.ref().child('users/$userId/cases/$caseId/disputeLogs/$fileName');
        await ref.putFile(file);
        finalUrls.add(await ref.getDownloadURL());
      }
    }

    final docRef = _db.collection('users').doc(userId)
        .collection('cases').doc(caseId)
        .collection('disputeRecords').doc(disputeId).collection('logs');

    if (logId == null) {
      await docRef.add({
        'title': title, 'description': desc, 'attachments': finalUrls, 'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.doc(logId).update({
        'title': title, 'description': desc, 'attachments': finalUrls, 'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

// 4. Update Dispute Status (Open/Resolved)
  Future<void> updateDisputeStatus(String caseId, String disputeId,
      String newStatus) async {
    await _db.collection('users').doc(_auth.currentUser?.uid)
        .collection('cases').doc(caseId)
        .collection('disputeRecords').doc(disputeId)
        .update({
      'disputeStatus': newStatus,
      'updatedAt': FieldValue.serverTimestamp()
    });
  }

// 5. Delete Log + Storage Cleanup
  Future<void> deleteLogWithStorage(String caseId, String disputeId,
      Map<String, dynamic> log) async {
    final List attachments = log['attachments'] ?? [];
    for (String url in attachments) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {}
    }
    await _db.collection('users').doc(_auth.currentUser?.uid)
        .collection('cases').doc(caseId)
        .collection('disputeRecords').doc(disputeId)
        .collection('logs').doc(log['id']).delete();
  }
}