import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/case_model.dart';

// Ensure CaseModel import is here

class ScheduledDatesProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CaseModel> _allCases = [];
  CaseModel? _selectedCase;

  // Screen Loader State
  bool isLoading = true;

  // Status flags
  bool hasCustody = false;
  bool hasPayments = false;
  bool hasCustom = false;

  // Specific Record IDs for Editing/Deleting
  String? custodyRecordId;
  String? paymentRecordId;
  String? customOrderId;

  List<CaseModel> get allCases => _allCases;
  CaseModel? get selectedCase => _selectedCase;

  ScheduledDatesProvider() {
    init();
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    await fetchUserCases();

    isLoading = false;
    notifyListeners();
  }

  void setSelectedCase(dynamic caseModel) async {
    _selectedCase = caseModel as CaseModel?;
    // Clear old IDs before checking new ones
    custodyRecordId = null;
    paymentRecordId = null;
    customOrderId = null;

    await checkSubCollections();
    notifyListeners();
  }

  Future<void> checkSubCollections() async {
    if (_selectedCase == null || _auth.currentUser == null) return;

    final caseDocRef = _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('cases')
        .doc(_selectedCase!.id);

    try {
      final results = await Future.wait([
        caseDocRef.collection('custodyRecords').limit(1).get(),
        caseDocRef.collection('paymentRecords').limit(1).get(),
        caseDocRef.collection('customRecords').limit(1).get(),
      ]);

      // Process Custody
      hasCustody = results[0].docs.isNotEmpty;
      custodyRecordId = hasCustody ? results[0].docs.first.id : null;

      // Process Payments
      hasPayments = results[1].docs.isNotEmpty;
      paymentRecordId = hasPayments ? results[1].docs.first.id : null;

      // Process Custom
      hasCustom = results[2].docs.isNotEmpty;
      customOrderId = hasCustom ? results[2].docs.first.id : null;

    } catch (e) {
      debugPrint("Error checking sub-collections: $e");
    }
    notifyListeners(); // THIS UPDATES THE UI
  }

  Future<void> fetchUserCases() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .get();

      _allCases = snapshot.docs.map((doc) {
        var model = CaseModel.fromMap(doc.data());
        model.id = doc.id;
        return model;
      }).toList();

      if (_allCases.isNotEmpty && _selectedCase == null) {
        _selectedCase = _allCases.first;
        await checkSubCollections();
      }
    } catch (e) {
      debugPrint("Error fetching cases: $e");
    }
  }

  String getCaseDisplayName(dynamic caseItem) {
    if (caseItem is! CaseModel) return "Select Case";
    final caseNum = caseItem.caseNumber.isEmpty ? "No Case #" : caseItem.caseNumber;
    if (caseItem.children.isEmpty) return caseNum;
    final names = caseItem.children.map((child) => child.name.trim()).join(' & ');
    return "$caseNum ($names)";
  }

  Future<void> deleteRule(String caseId, String recordId, String category) async {
    isLoading = true;
    notifyListeners();

    try {
      final uid = _auth.currentUser!.uid;
      // This will work for 'custodyRecords', 'paymentRecords', and 'customRecords'
      await _firestore
          .collection('users').doc(uid)
          .collection('cases').doc(caseId)
          .collection('${category}Records').doc(recordId)
          .delete();

      // Just refresh the flags for the current case instead of fetching all cases again
      await checkSubCollections();
    } catch (e) {
      debugPrint("Delete Error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}