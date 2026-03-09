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

  bool isLoading = true;

  // Status flags
  bool get hasCustody => custodyRecords.isNotEmpty;
  bool get hasPayments => paymentRecords.isNotEmpty;
  bool get hasCustom => customRecords.isNotEmpty;

  // Record lists
  List<Map<String, dynamic>> custodyRecords = [];
  List<Map<String, dynamic>> paymentRecords = [];
  List<Map<String, dynamic>> customRecords = [];

  // Getters to easily access the FIRST (Scheduled) record ID for Edit/Delete buttons
  String? get custodyRecordId => hasCustody ? custodyRecords.first['id'] : null;
  String? get paymentRecordId => hasPayments ? paymentRecords.first['id'] : null;
  String? get customOrderId => hasCustom ? customRecords.first['id'] : null;

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
      // Fetch ALL entries for this case
      final results = await Future.wait([
        caseDocRef.collection('custodyRecords').get(),
        caseDocRef.collection('paymentRecords').get(),
        caseDocRef.collection('customRecords').get(),
      ]);

      // Map everything to a List including the document ID
      custodyRecords = results[0].docs.map((d) => {...d.data(), 'id': d.id}).toList();
      paymentRecords = results[1].docs.map((d) => {...d.data(), 'id': d.id}).toList();
      customRecords = results[2].docs.map((d) => {...d.data(), 'id': d.id}).toList();

    } catch (e) {
      debugPrint("Error checking sub-collections: $e");
    }
    notifyListeners();
  }

  // Your existing fetchUserCases and getCaseDisplayName remain exactly the same...
  Future<void> fetchUserCases() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).collection('cases').get();
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
      await _firestore
          .collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(caseId)
          .collection('${category}Records').doc(recordId)
          .delete();
      await checkSubCollections(); // Refresh the list
    } catch (e) {
      debugPrint("Delete Error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}