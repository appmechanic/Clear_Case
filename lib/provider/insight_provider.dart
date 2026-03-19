import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/case_model.dart';


class InsightProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CaseModel> _allCases = [];
  CaseModel? _selectedCase;
  bool _isLoading = false;

  // Payment Variables
  double totalPaid = 0.0;
  double totalReceived = 0.0;
  double totalCompulsory = 0.0;
  double totalAdditional = 0.0;

  // Placeholder Variables for future modules
  int totalFlagged = 0;
  double custodyCompliance = 0.0;

  bool get isLoading => _isLoading;
  List<CaseModel> get allCases => _allCases;
  CaseModel? get selectedCase => _selectedCase;

  InsightProvider() {
    init();
  }

  Future<void> init() async {
    await fetchUserCases();
  }

  /// 1. Fetch all cases (Updating names, numbers, and children)
  Future<void> fetchUserCases({bool quietLoad = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!quietLoad) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).collection('cases').get();

      _allCases = snapshot.docs.map((doc) {
        var model = CaseModel.fromMap(doc.data());
        model.id = doc.id;
        return model;
      }).toList();

      // If we already had a selected case, update its data from the fresh list
      if (_selectedCase != null) {
        _selectedCase = _allCases.firstWhere(
              (c) => c.id == _selectedCase!.id,
          orElse: () => _allCases.isNotEmpty ? _allCases.first : _selectedCase!,
        );
      } else if (_allCases.isNotEmpty) {
        setSelectedCase(_allCases.first);
      }
    } catch (e) {
      debugPrint("Fetch Cases Error: $e");
    } finally {
      if (!quietLoad) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 2. MAIN REFRESH METHOD
  /// Called by the RefreshIndicator to update Case List AND Insights
  Future<void> refreshAllData() async {
    // First, refresh the cases (Case numbers, names, etc.)
    // We use quietLoad: true to prevent a big loading spinner in the middle of a pull-to-refresh
    await fetchUserCases(quietLoad: true);

    if (_selectedCase == null) {
      notifyListeners();
      return;
    }

    // Then, refresh the specific insights for the current case
    await Future.wait([
      calculatePaymentInsights(),
      calculateBreachInsights(),
      // calculateFlaggedEvents(),
    ]);

    notifyListeners();
  }

  double get totalPayments => totalPaid + totalReceived + totalCompulsory + totalAdditional;

  void setSelectedCase(dynamic caseModel) {
    _selectedCase = caseModel as CaseModel?;
    _resetStats();
    if (_selectedCase != null) {
      // Logic for calculating insights based on the new selection
      Future.wait([
        calculatePaymentInsights(),
        calculateBreachInsights(),
      ]).then((_) => notifyListeners());
    }
    notifyListeners();
  }

  String getCaseDisplayName(dynamic caseItem) {
    if (caseItem is! CaseModel) return "Select Case";
    final caseNum = caseItem.caseNumber.isEmpty ? "No Case #" : caseItem.caseNumber;
    if (caseItem.children.isEmpty) return caseNum;
    final names = caseItem.children.map((child) => child.name.trim()).join(' & ');
    return "$caseNum ($names)";
  }

  /// 3. Payment Specific Logic
  Future<void> calculatePaymentInsights() async {
    if (_selectedCase == null) return;

    final userId = _auth.currentUser!.uid;
    final caseId = _selectedCase!.id;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cases')
          .doc(caseId)
          .collection('paymentRecords')
          .get();

      double tempPaid = 0.0;
      double tempReceived = 0.0;
      double tempCompulsory = 0.0;
      double tempAdditional = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final double amount = (data['amount'] ?? 0).toDouble();
        final bool isReceived = data['isReceived'] ?? false;
        final String category = data['paymentCategory'] ?? "";

        if (isReceived) {
          tempReceived += amount;
        } else {
          tempPaid += amount;
        }

        if (category == "Compulsory") {
          tempCompulsory += amount;
        } else if (category == "Additional") {
          tempAdditional += amount;
        }
      }

      totalPaid = tempPaid;
      totalReceived = tempReceived;
      totalCompulsory = tempCompulsory;
      totalAdditional = tempAdditional;
    } catch (e) {
      debugPrint("Payment Error: $e");
    }
  }


  int totalBreachCount = 0; // Renamed from monthlyBreachCount for clarity

  Future<void> calculateBreachInsights() async {
    if (_selectedCase == null) return;
    final userId = _auth.currentUser!.uid;
    final caseId = _selectedCase!.id;

    try {
      // Removed the 'where' date filter to get the absolute total
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cases')
          .doc(caseId)
          .collection('breachRecords')
          .get();

      totalBreachCount = snapshot.docs.length;
      notifyListeners();
    } catch (e) {
      debugPrint("Breach Insight Error: $e");
    }
  }

  void _resetStats() {
    totalPaid = 0.0;
    totalReceived = 0.0;
    totalCompulsory = 0.0;
    totalAdditional = 0.0;
    totalFlagged = 0;
    custodyCompliance = 0.0;
    totalBreachCount = 0;
  }

}