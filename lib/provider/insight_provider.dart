import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_model.dart';


class InsightProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CaseModel> _allCases = [];
  CaseModel? _selectedCase;
  bool _isLoading = false;


  int fulfilledDays = 0;
  int justifiedDays = 0;
  int missedDays = 0;
  double complianceRate = 0.0;

  // Payment Variables
  double totalPaid = 0.0;
  double totalReceived = 0.0;
  double totalCompulsory = 0.0;
  double totalAdditional = 0.0;

  // Placeholder Variables for future modules
  int totalFlagged = 0;
  double custodyCompliance = 0.0;

  int totalDisputes = 0;
  int communicationCount = 0;
  int transferIssuesCount = 0;
  int paymentDisputesCount = 0;

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
      calculateCustodyCompliance(),
      calculatePaymentInsights(),
      calculateBreachInsights(),
      calculateDisputeInsights(),
      calculateFlaggedInsights(),
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
        calculateCustodyCompliance(),
        calculatePaymentInsights(),
        calculateBreachInsights(),
        calculateDisputeInsights(),
        calculateFlaggedInsights(),
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


  Future<void> calculateCustodyCompliance() async {
    if (_selectedCase == null) return;
    final userId = _auth.currentUser!.uid;
    final caseId = _selectedCase!.id;

    // Normalize "today" to midnight to ensure inclusive date comparisons
    final now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    try {
      // Step A: Fetch Scheduled Rules to define the "Expected" dates
      final rulesSnapshot = await _firestore
          .collection('users').doc(userId)
          .collection('cases').doc(caseId)
          .collection('scheduledRules').get();

      if (rulesSnapshot.docs.isEmpty) {
        _resetCustodyStats();
        return;
      }

      Set<String> scheduledDates = {};

      for (var doc in rulesSnapshot.docs) {
        final data = doc.data();
        DateTime startDate = DateTime.parse(data['startDate']);
        startDate = DateTime(startDate.year, startDate.month, startDate.day);

        DateTime? endDate = data['endDate'] != null ? DateTime.parse(data['endDate']) : null;

        DateTime calculationEnd = today;
        if (endDate != null && endDate.isBefore(today)) {
          calculationEnd = DateTime(endDate.year, endDate.month, endDate.day);
        }

        // Every single day from start to end/today is an expected custody day
        for (DateTime date = startDate;
        !date.isAfter(calculationEnd);
        date = date.add(const Duration(days: 1))) {
          scheduledDates.add(DateFormat('yyyy-MM-dd').format(date));
        }
      }

      int totalScheduledUntilToday = scheduledDates.length;

      // Step B: Fetch Actual Custody Records
      final recordsSnapshot = await _firestore
          .collection('users').doc(userId)
          .collection('cases').doc(caseId)
          .collection('custodyRecords').get();

      int tempFulfilled = 0;
      int tempJustified = 0;

      for (var doc in recordsSnapshot.docs) {
        final data = doc.data();

        // NEW: Ignore entries where isScheduled is false
        final bool isScheduledEntry = data['isScheduled'] ?? false;
        if (!isScheduledEntry) continue;

        bool isFulfilled = data['isFulfilled'] ?? false;
        DateTime recordDate = (data['startDate'] as Timestamp).toDate();
        String dateKey = DateFormat('yyyy-MM-dd').format(recordDate);

        // Only count if this record falls on one of our scheduled dates
        if (scheduledDates.contains(dateKey)) {
          if (isFulfilled) {
            tempFulfilled++;
          } else {
            // It was scheduled, entry exists, but not fulfilled = Justified
            tempJustified++;
          }
        }
      }

      // Step C: Update State
      fulfilledDays = tempFulfilled;
      justifiedDays = tempJustified;

      // Missed = Scheduled dates that have NO entry at all in the DB
      missedDays = totalScheduledUntilToday - (tempFulfilled + tempJustified);
      if (missedDays < 0) missedDays = 0;

      // Step D: Formula - (Fulfilled + Justified) / Total Scheduled
      int actualDays = fulfilledDays + justifiedDays;
      if (totalScheduledUntilToday > 0) {
        complianceRate = (actualDays / totalScheduledUntilToday) * 100;
      } else {
        complianceRate = 0.0;
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Custody Insight Error: $e");
    }
  }

// Helper to clear stats if no rules exist
  void _resetCustodyStats() {
    fulfilledDays = 0;
    justifiedDays = 0;
    missedDays = 0;
    complianceRate = 0.0;
    notifyListeners();
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

  /// 4. Dispute Specific Logic
  Future<void> calculateDisputeInsights() async {
    if (_selectedCase == null) return;

    final userId = _auth.currentUser!.uid;
    final caseId = _selectedCase!.id;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cases')
          .doc(caseId)
          .collection('disputeRecords')
          .get();

      int tempComm = 0;
      int tempTransfer = 0;
      int tempPayment = 0;

      for (var doc in snapshot.docs) {
        final category = doc.data()['category'] ?? "";

        if (category == "Communication") {
          tempComm++;
        } else if (category == "Transfer Issues") {
          tempTransfer++;
        } else if (category == "Payment Disputes") {
          tempPayment++;
        }
      }

      communicationCount = tempComm;
      transferIssuesCount = tempTransfer;
      paymentDisputesCount = tempPayment;
      totalDisputes = snapshot.docs.length;

      notifyListeners();
    } catch (e) {
      debugPrint("Dispute Insight Error: $e");
    }
  }

  // Add these variables to your InsightProvider class
  int flaggedCustodyCount = 0;
  int flaggedPaymentsCount = 0;
  int flaggedDisputesCount = 0;
  int flaggedBreachCount = 0;

// Update the total getter
  int get totalFlaggedCount => flaggedCustodyCount + flaggedPaymentsCount + flaggedDisputesCount + flaggedBreachCount;

  Future<void> calculateFlaggedInsights() async {
    if (_selectedCase == null) return;
    final userId = _auth.currentUser!.uid;
    final caseId = _selectedCase!.id;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cases')
          .doc(caseId)
          .collection('flaggedEvents')
          .get();

      int tempCustody = 0;
      int tempPayments = 0;
      int tempDisputes = 0;
      int tempBreach = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String origin = data['originCollection'] ?? "";

        // Logic to categorize based on originCollection
        if (origin == "paymentRecords") {
          tempPayments++;
        } else if (origin == "disputeRecords") {
          tempDisputes++;
        } else if (origin == "breachRecords") {
          tempBreach++;
        } else if (origin == "custodyRecords" || origin == "eventRecords") {
          tempCustody++;
        }
      }

      flaggedCustodyCount = tempCustody;
      flaggedPaymentsCount = tempPayments;
      flaggedDisputesCount = tempDisputes;
      flaggedBreachCount = tempBreach;

      notifyListeners();
    } catch (e) {
      debugPrint("Flagged Insight Error: $e");
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
    totalDisputes = 0;
    communicationCount = 0;
    transferIssuesCount = 0;
    paymentDisputesCount = 0;
    flaggedCustodyCount = 0;
    flaggedPaymentsCount = 0;
    flaggedDisputesCount = 0;
    flaggedBreachCount = 0;
  }

}