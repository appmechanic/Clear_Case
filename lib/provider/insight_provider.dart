import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calender_event_model.dart';
import '../models/case_model.dart';
import '../services/case_selection_service.dart';


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class InsightProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Real-time Listeners
  StreamSubscription? _casesSubscription;
  final List<StreamSubscription> _caseDetailSubscriptions = [];
  StreamSubscription<User?>? _authSubscription;
  String? _currentUid;

  List<CaseModel> _allCases = [];
  CaseModel? _selectedCase;
  bool _isLoading = false;

  // Custody Variables
  int fulfilledDays = 0;
  int justifiedDays = 0;
  int missedDays = 0;
  double complianceRate = 0.0;

  // Payment Variables
  double totalPaid = 0.0;
  double totalReceived = 0.0;
  double totalCompulsory = 0.0;
  double totalAdditional = 0.0;

  // Non-compliance & Dispute Variables
  int totalNonComplianceCount = 0;
  int totalDisputes = 0;
  int communicationCount = 0;
  int transferIssuesCount = 0;
  int paymentDisputesCount = 0;

  // Flagged Variables
  int flaggedCustodyCount = 0;
  int flaggedPaymentsCount = 0;
  int flaggedDisputesCount = 0;
  int flaggedNonComplianceCount = 0;

  // Report Variables
  List<CalendarEvent> _allEvents = [];
  List<CalendarEvent> get allEvents => _allEvents;

  bool get isLoading => _isLoading;
  List<CaseModel> get allCases => _allCases;
  CaseModel? get selectedCase => _selectedCase;
  int get totalFlaggedCount => flaggedCustodyCount + flaggedPaymentsCount + flaggedDisputesCount + flaggedNonComplianceCount;
  List<ChildModel> get children => _selectedCase?.children ?? [];

  // FIX: Only sum Paid and Received to prevent double-counting sub-categories
  double get totalPayments => totalPaid + totalReceived;

  InsightProvider() {
    // Drive all listeners off auth state so logging out / switching accounts
    // tears down the previous user's data and rebinds to the new uid.
    _authSubscription = _auth.authStateChanges().listen(_handleAuthChanged);
    // Keep the case selection in sync with the rest of the app.
    CaseSelectionService.instance.addListener(_onSharedSelectionChanged);
  }

  // Reflects a case selection made on another screen. Guarded so it only acts
  // on a genuinely different, known case (avoids feedback loops).
  void _onSharedSelectionChanged() {
    final id = CaseSelectionService.instance.selectedCaseId;
    if (id == null || _selectedCase?.id == id) return;
    final matches = _allCases.where((c) => c.id == id);
    if (matches.isNotEmpty) setSelectedCase(matches.first);
  }

  void _handleAuthChanged(User? user) {
    if (_currentUid == user?.uid) return;
    _currentUid = user?.uid;
    _resetForUserChange();
    if (user != null) {
      listenToUserCases();
    } else {
      notifyListeners();
    }
  }

  void _resetForUserChange() {
    _casesSubscription?.cancel();
    _casesSubscription = null;
    for (var sub in _caseDetailSubscriptions) {
      sub.cancel();
    }
    _caseDetailSubscriptions.clear();
    _allCases = [];
    _selectedCase = null;
    _allEvents = [];
    _isLoading = false;
    _resetStats();
  }

  /// 1. REAL-TIME: Listen to the list of cases
// Change from: void listenToUserCases()
// To:
  Future<void> listenToUserCases() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _casesSubscription?.cancel();

    _casesSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .snapshots()
        .listen((snapshot) {
      _allCases = snapshot.docs.map((doc) {
        var model = CaseModel.fromMap(doc.data());
        model.id = doc.id;
        return model;
      }).toList();

      if (_selectedCase != null) {
        _selectedCase = _allCases.firstWhere(
              (c) => c.id == _selectedCase!.id,
          orElse: () => _allCases.isNotEmpty ? _allCases.first : _selectedCase!,
        );
      } else if (_allCases.isNotEmpty) {
        // Honour a case already chosen elsewhere in the app, else first.
        final sharedId = CaseSelectionService.instance.selectedCaseId;
        final initial = (sharedId != null)
            ? _allCases.firstWhere((c) => c.id == sharedId, orElse: () => _allCases.first)
            : _allCases.first;
        setSelectedCase(initial);
      }

      _isLoading = false;
      notifyListeners();
    }, onError: (e) => debugPrint("Cases Stream Error: $e"));

    // Return a completed future so the RefreshIndicator knows the "setup" is done
    return;
  }

  /// 2. SET CASE: Updates listeners for the specific case sub-collections
  void setSelectedCase(dynamic caseModel) {
    _selectedCase = caseModel as CaseModel?;
    // Broadcast to the rest of the app (no-op when unchanged, so it can't loop).
    CaseSelectionService.instance.select(_selectedCase?.id);
    _resetStats();
    _startListeningToCaseDetails();
    notifyListeners();
  }

  /// 3. REAL-TIME: Detailed listeners for the selected case
  void _startListeningToCaseDetails() {
    for (var sub in _caseDetailSubscriptions) { sub.cancel(); }
    _caseDetailSubscriptions.clear();

    if (_selectedCase == null) return;

    final userId = _auth.currentUser!.uid;
    final caseId = _selectedCase!.id;
    final caseDoc = _firestore.collection('users').doc(userId).collection('cases').doc(caseId);

    // Payments Listener
    _caseDetailSubscriptions.add(
        caseDoc.collection('paymentRecords').snapshots().listen((snap) {
          _calculatePaymentInsightsSync(snap.docs);
        })
    );

    // Custody Listeners (Rules + Records)
    _caseDetailSubscriptions.add(
        caseDoc.collection('scheduledRules').snapshots().listen((_) => calculateCustodyCompliance())
    );
    _caseDetailSubscriptions.add(
        caseDoc.collection('custodyRecords').snapshots().listen((_) => calculateCustodyCompliance())
    );

    // Non-compliances Listener
    _caseDetailSubscriptions.add(
        caseDoc.collection('nonComplianceRecords').snapshots().listen((snap) {
          totalNonComplianceCount = snap.docs.length;
          notifyListeners();
        })
    );

    // Disputes Listener
    _caseDetailSubscriptions.add(
        caseDoc.collection('disputeRecords').snapshots().listen((snap) {
          _calculateDisputeInsightsSync(snap.docs);
        })
    );

    // Flagged Listener
    _caseDetailSubscriptions.add(
        caseDoc.collection('flaggedEvents').snapshots().listen((snap) {
          _calculateFlaggedInsightsSync(snap.docs);
        })
    );
  }

  // --- SYNC CALCULATORS FOR STREAM DATA ---

  void _calculatePaymentInsightsSync(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double tempPaid = 0.0; double tempReceived = 0.0;
    double tempCompulsory = 0.0; double tempAdditional = 0.0;

    for (var doc in docs) {
      final data = doc.data();
      final double amount = (data['amount'] ?? 0).toDouble();
      final bool isReceived = data['isReceived'] ?? false;
      final String category = data['paymentCategory'] ?? "";

      if (isReceived) tempReceived += amount;
      else tempPaid += amount;

      if (category == "Compulsory") tempCompulsory += amount;
      else if (category == "Additional") tempAdditional += amount;
    }
    totalPaid = tempPaid; totalReceived = tempReceived;
    totalCompulsory = tempCompulsory; totalAdditional = tempAdditional;
    notifyListeners();
  }

  void _calculateDisputeInsightsSync(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int tempComm = 0; int tempTransfer = 0; int tempPayment = 0;
    for (var doc in docs) {
      final category = doc.data()['category'] ?? "";
      if (category == "Communication") tempComm++;
      else if (category == "Transfer Issues") tempTransfer++;
      else if (category == "Payment Disputes") tempPayment++;
    }
    communicationCount = tempComm; transferIssuesCount = tempTransfer;
    paymentDisputesCount = tempPayment; totalDisputes = docs.length;
    notifyListeners();
  }

  void _calculateFlaggedInsightsSync(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int tempC = 0; int tempP = 0; int tempD = 0; int tempB = 0;
    for (var doc in docs) {
      final String origin = doc.data()['originCollection'] ?? "";
      if (origin == "paymentRecords") tempP++;
      else if (origin == "disputeRecords") tempD++;
      else if (origin == "nonComplianceRecords") tempB++;
      else tempC++;
    }
    flaggedCustodyCount = tempC; flaggedPaymentsCount = tempP;
    flaggedDisputesCount = tempD; flaggedNonComplianceCount = tempB;
    notifyListeners();
  }

  /// 4. CUSTODY LOGIC: Remains Future-based as it aggregates multiple steps
  Future<void> calculateCustodyCompliance() async {
    if (_selectedCase == null) return;
    final userId = _auth.currentUser!.uid;
    final caseId = _selectedCase!.id;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    try {
      final rulesSnap = await _firestore.collection('users').doc(userId).collection('cases').doc(caseId).collection('scheduledRules').get();
      if (rulesSnap.docs.isEmpty) { _resetCustodyStats(); return; }

      Set<String> scheduledDates = {};
      for (var doc in rulesSnap.docs) {
        final data = doc.data();
        // Skip rules with a missing/malformed startDate instead of letting one
        // bad row throw and silently zero out the entire compliance result.
        final DateTime? start = DateTime.tryParse(data['startDate']?.toString() ?? '');
        if (start == null) continue;
        final DateTime? end = DateTime.tryParse(data['endDate']?.toString() ?? '');
        DateTime calcEnd = (end != null && end.isBefore(today)) ? end : today;

        for (DateTime date = DateTime(start.year, start.month, start.day); !date.isAfter(calcEnd); date = date.add(const Duration(days: 1))) {
          scheduledDates.add(DateFormat('yyyy-MM-dd').format(date));
        }
      }

      final recordsSnap = await _firestore.collection('users').doc(userId).collection('cases').doc(caseId).collection('custodyRecords').get();
      int tempF = 0; int tempJ = 0;

      for (var doc in recordsSnap.docs) {
        final data = doc.data();
        if (!(data['isScheduled'] ?? false)) continue;
        String dateKey = DateFormat('yyyy-MM-dd').format((data['startDate'] as Timestamp).toDate());
        if (scheduledDates.contains(dateKey)) {
          if (data['isFulfilled'] ?? false) tempF++; else tempJ++;
        }
      }

      fulfilledDays = tempF; justifiedDays = tempJ;
      missedDays = (scheduledDates.length - (tempF + tempJ)).clamp(0, 999999);
      complianceRate = scheduledDates.isNotEmpty ? ((tempF + tempJ) / scheduledDates.length) * 100 : 0.0;
      notifyListeners();
    } catch (e) { debugPrint("Custody Insight Error: $e"); }
  }

  // --- UTILS & CLEANUP ---

  void _resetStats() {
    totalPaid = 0.0; totalReceived = 0.0; totalCompulsory = 0.0; totalAdditional = 0.0;
    totalNonComplianceCount = 0; totalDisputes = 0; communicationCount = 0;
    transferIssuesCount = 0; paymentDisputesCount = 0;
    flaggedCustodyCount = 0; flaggedPaymentsCount = 0; flaggedDisputesCount = 0; flaggedNonComplianceCount = 0;
    fulfilledDays = 0; justifiedDays = 0; missedDays = 0; complianceRate = 0.0;
  }

  void _resetCustodyStats() {
    fulfilledDays = 0; justifiedDays = 0; missedDays = 0; complianceRate = 0.0;
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

  Future<void> fetchAllEventsForReport() async {
    if (_selectedCase == null) return;
    try {
      _isLoading = true; notifyListeners();
      final userId = _auth.currentUser!.uid;
      final caseId = _selectedCase!.id;
      final snaps = await Future.wait([
        _firestore.collection('users').doc(userId).collection('cases').doc(caseId).collection('paymentRecords').get(),
        _firestore.collection('users').doc(userId).collection('cases').doc(caseId).collection('custodyRecords').get(),
        _firestore.collection('users').doc(userId).collection('cases').doc(caseId).collection('disputeRecords').get(),
        _firestore.collection('users').doc(userId).collection('cases').doc(caseId).collection('nonComplianceRecords').get(),
      ]);
      _allEvents = snaps.expand((s) => s.docs.map((d) => CalendarEvent.fromMap(d.data(), docId: d.id))).toList();
      _allEvents.sort((a, b) => b.date.compareTo(a.date));
    } finally { _isLoading = false; notifyListeners(); }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    CaseSelectionService.instance.removeListener(_onSharedSelectionChanged);
    _authSubscription?.cancel();
    _casesSubscription?.cancel();
    for (var sub in _caseDetailSubscriptions) { sub.cancel(); }
    super.dispose();
  }

  // Guard against notifying after disposal (in-flight async fetches).
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}