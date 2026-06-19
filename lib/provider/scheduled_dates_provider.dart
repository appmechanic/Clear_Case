import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/case_model.dart';
import '../services/case_selection_service.dart';

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

  StreamSubscription<User?>? _authSubscription;
  String? _currentUid;

  ScheduledDatesProvider() {
    _currentUid = _auth.currentUser?.uid;
    // Clear cached cases and rule records when the signed-in user changes,
    // so a fresh login never sees the previous account's data.
    _authSubscription = _auth.authStateChanges().listen(_handleAuthChanged);
    // Keep the case selection in sync with the rest of the app.
    CaseSelectionService.instance.addListener(_onSharedSelectionChanged);
  }

  // Reflects a case selection made on another screen. Guarded so it only acts
  // on a genuinely different, known case (avoids feedback loops). When the
  // cases haven't been loaded yet, init() reconciles with the shared selection.
  void _onSharedSelectionChanged() {
    final id = CaseSelectionService.instance.selectedCaseId;
    if (id == null || _selectedCase?.id == id) return;
    final matches = _allCases.where((c) => c.id == id);
    if (matches.isNotEmpty) setSelectedCase(matches.first);
  }

  void _handleAuthChanged(User? user) {
    if (_currentUid == user?.uid) return;
    _currentUid = user?.uid;
    _allCases = [];
    _selectedCase = null;
    custodyRecords = [];
    paymentRecords = [];
    customRecords = [];
    isLoading = true;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    CaseSelectionService.instance.removeListener(_onSharedSelectionChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  // Guard against notifying after disposal (in-flight async fetches).
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  Future<void> init({String? initialCaseId}) async {
    isLoading = true;
    notifyListeners();

    // 1. Fetch all cases first
    await fetchUserCases(shouldCheckSub: false); // Modified to not run sub-check yet

    // 2. Decide which case to select
    if (initialCaseId != null && _allCases.isNotEmpty) {
      // Look for the case passed from Settings
      final foundCase = _allCases.firstWhere(
            (c) => c.id == initialCaseId,
        orElse: () => _allCases.first,
      );
      _selectedCase = foundCase;
    } else if (_allCases.isNotEmpty) {
      // Honour a case already chosen elsewhere in the app, else first.
      final sharedId = CaseSelectionService.instance.selectedCaseId;
      _selectedCase = (sharedId != null)
          ? _allCases.firstWhere((c) => c.id == sharedId, orElse: () => _allCases.first)
          : _allCases.first;
    }

    // 3. Now check the rules for the selected case
    if (_selectedCase != null) {
      // Broadcast so other screens follow this selection.
      CaseSelectionService.instance.select(_selectedCase!.id);
      await checkSubCollections();
    }

    isLoading = false;
    notifyListeners();
  }

  // Modified fetchUserCases to be more flexible
  Future<void> fetchUserCases({bool shouldCheckSub = true}) async {
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

      if (shouldCheckSub && _allCases.isNotEmpty && _selectedCase == null) {
        _selectedCase = _allCases.first;
        await checkSubCollections();
      }
    } catch (e) {
      debugPrint("Error fetching cases: $e");
    }
  }
  void setSelectedCase(dynamic caseModel) async {
    // 1. Set to loading state
    isLoading = true;
    _selectedCase = caseModel as CaseModel?;
    // Broadcast to the rest of the app (no-op when unchanged, so it can't loop).
    CaseSelectionService.instance.select(_selectedCase?.id);
    notifyListeners(); // This notifies the UI to show the loader

    // 2. Perform the async work
    await checkSubCollections();

    // 3. Stop loading
    isLoading = false;
    notifyListeners();
  }

  Future<void> checkSubCollections() async {
    if (_selectedCase == null || _auth.currentUser == null) return;

    final caseDocRef = _firestore
        .collection('users').doc(_auth.currentUser!.uid)
        .collection('cases').doc(_selectedCase!.id)
        .collection('scheduledRules'); // THE NEW CLEAN FOLDER

    try {
      // Check if the specific rule documents exist
      final [custodyDoc, paymentDoc, customDoc] = await Future.wait([
        caseDocRef.doc('custody').get(),
        caseDocRef.doc('payment').get(),
        caseDocRef.doc('custom').get(),
      ]);

      // Update your state based on whether the document exists
      // We store the data, and we store the doc ID (which is the category name)
      custodyRecords = custodyDoc.exists ? [{...custodyDoc.data()!, 'id': custodyDoc.id}] : [];
      paymentRecords = paymentDoc.exists ? [{...paymentDoc.data()!, 'id': paymentDoc.id}] : [];
      customRecords = customDoc.exists ? [{...customDoc.data()!, 'id': customDoc.id}] : [];

    } catch (e) {
      debugPrint("Error checking sub-collections: $e");
    }
    notifyListeners();
  }


  String getCaseDisplayName(dynamic caseItem) {
    if (caseItem is! CaseModel) return "Select Case";
    // Show the child name(s); fall back to the case number only when a case
    // has no children attached.
    if (caseItem.children.isEmpty) {
      return caseItem.caseNumber.isEmpty ? "No Case #" : caseItem.caseNumber;
    }
    return caseItem.children.map((child) => child.name.trim()).join(' & ');
  }

  Future<void> deleteRule(String caseId, String recordId, String category) async {
    isLoading = true;
    notifyListeners();
    try {
      await _firestore
          .collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(caseId)
          .collection('scheduledRules') // Point to the new folder
          .doc(category.toLowerCase())  // Delete the specific rule document
          .delete();

      await checkSubCollections(); // This will now refresh and see that the doc is gone
    } catch (e) {
      debugPrint("Delete Error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }}
