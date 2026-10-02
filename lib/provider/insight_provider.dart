import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../core/utils/child_names.dart';
import '../core/utils/custody_span.dart';
import '../core/utils/timeframe.dart';
import '../models/calender_event_model.dart';
import '../models/case_model.dart';
import '../services/case_selection_service.dart';

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

  // Reporting period for every stat below. Defaults to the Australian
  // financial year; the Insights screen's dropdown changes it.
  String _timeframe = Timeframe.defaultOption;
  String get timeframe => _timeframe;
  TimeWindow get timeWindow => Timeframe.windowFor(_timeframe);

  // Latest raw docs per collection, kept so a timeframe change can recompute
  // without waiting for Firestore to emit again.
  List<Map<String, dynamic>> _paymentDocs = [];
  List<Map<String, dynamic>> _custodyDocs = [];
  List<Map<String, dynamic>> _nonComplianceDocs = [];
  List<Map<String, dynamic>> _disputeDocs = [];
  List<Map<String, dynamic>> _flaggedDocs = [];

  // Custody: what actually happened in the period, not measured against
  // scheduled rules.
  int totalCustodyNights = 0;
  int totalCustodyEntries = 0;

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

  // Raw flaggedEvents docs backing FlaggedEventsScreen. Each entry is the doc's
  // data with `id` overwritten by `originId` — a flaggedEvents doc's own id is an
  // auto-id, NOT the origin record's, and the detail screens look records up by id.
  List<Map<String, dynamic>> flaggedEvents = [];

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
    _timeframe = Timeframe.defaultOption;
    _clearCachedDocs();
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
    _clearCachedDocs();
    _resetStats();
    _startListeningToCaseDetails();
    notifyListeners();
  }

  /// Changes the reporting period and recomputes every stat from cached docs.
  void setTimeframe(String option) {
    if (option == _timeframe) return;
    _timeframe = option;
    _recomputeAll();
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

    List<Map<String, dynamic>> dataOf(QuerySnapshot<Map<String, dynamic>> snap) =>
        snap.docs.map((d) => d.data()).toList();

    _caseDetailSubscriptions.add(
        caseDoc.collection('paymentRecords').snapshots().listen((snap) {
          _paymentDocs = dataOf(snap);
          _calculatePaymentInsights();
          notifyListeners();
        })
    );

    // Custody insights come from recorded entries only — scheduled rules are
    // reminders and don't feed any calculation.
    _caseDetailSubscriptions.add(
        caseDoc.collection('custodyRecords').snapshots().listen((snap) {
          _custodyDocs = dataOf(snap);
          _calculateCustodyInsights();
          notifyListeners();
        })
    );

    _caseDetailSubscriptions.add(
        caseDoc.collection('nonComplianceRecords').snapshots().listen((snap) {
          _nonComplianceDocs = dataOf(snap);
          _calculateNonComplianceInsights();
          notifyListeners();
        })
    );

    _caseDetailSubscriptions.add(
        caseDoc.collection('disputeRecords').snapshots().listen((snap) {
          _disputeDocs = dataOf(snap);
          _calculateDisputeInsights();
          notifyListeners();
        })
    );

    _caseDetailSubscriptions.add(
        caseDoc.collection('flaggedEvents').snapshots().listen((snap) {
          // originId, not doc.id — see the flaggedEvents field comment above.
          _flaggedDocs = snap.docs
              .map((doc) => {...doc.data(), 'id': doc.data()['originId'] ?? doc.id})
              .toList();
          _calculateFlaggedInsights();
          notifyListeners();
        })
    );
  }

  // --- CALCULATORS (all scoped to the selected timeframe) ---

  void _recomputeAll() {
    _calculatePaymentInsights();
    _calculateCustodyInsights();
    _calculateNonComplianceInsights();
    _calculateDisputeInsights();
    _calculateFlaggedInsights();
  }

  bool _inWindow(Map<String, dynamic> data) =>
      timeWindow.contains((data['date'] as Timestamp?)?.toDate());

  void _calculatePaymentInsights() {
    double tempPaid = 0.0; double tempReceived = 0.0;
    double tempCompulsory = 0.0; double tempAdditional = 0.0;

    for (final data in _paymentDocs.where(_inWindow)) {
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
    totalPaid = tempPaid; totalReceived = tempReceived;
    totalCompulsory = tempCompulsory; totalAdditional = tempAdditional;
  }

  void _calculateCustodyInsights() {
    final spans = _custodyDocs.map(CustodySpan.fromMap).whereType<CustodySpan>();
    final totals = CustodyTotals.from(spans, timeWindow);
    totalCustodyEntries = totals.entries;
    totalCustodyNights = totals.nights;
  }

  void _calculateNonComplianceInsights() {
    totalNonComplianceCount = _nonComplianceDocs.where(_inWindow).length;
  }

  void _calculateDisputeInsights() {
    int tempComm = 0; int tempTransfer = 0; int tempPayment = 0;
    final inRange = _disputeDocs.where(_inWindow).toList();
    for (final data in inRange) {
      final category = data['category'] ?? "";
      if (category == "Communication") {
        tempComm++;
      } else if (category == "Transfer Issues") {
        tempTransfer++;
      } else if (category == "Payment Disputes") {
        tempPayment++;
      }
    }
    communicationCount = tempComm; transferIssuesCount = tempTransfer;
    paymentDisputesCount = tempPayment; totalDisputes = inRange.length;
  }

  void _calculateFlaggedInsights() {
    int tempC = 0; int tempP = 0; int tempD = 0; int tempB = 0;
    final List<Map<String, dynamic>> tempEvents = [];
    for (final data in _flaggedDocs) {
      final String origin = data['originCollection'] ?? "";
      // Custody copies carry startDate/endDate; the rest carry `date`.
      final span = origin == "custodyRecords" ? CustodySpan.fromMap(data) : null;
      final inRange = span != null ? timeWindow.overlaps(span.start, span.end) : _inWindow(data);
      if (!inRange) continue;

      if (origin == "paymentRecords") {
        tempP++;
      } else if (origin == "disputeRecords") {
        tempD++;
      } else if (origin == "nonComplianceRecords") {
        tempB++;
      } else {
        tempC++;
      }
      tempEvents.add(data);
    }
    flaggedCustodyCount = tempC; flaggedPaymentsCount = tempP;
    flaggedDisputesCount = tempD; flaggedNonComplianceCount = tempB;
    flaggedEvents = tempEvents;
  }

  // --- UTILS & CLEANUP ---

  void _clearCachedDocs() {
    _paymentDocs = [];
    _custodyDocs = [];
    _nonComplianceDocs = [];
    _disputeDocs = [];
    _flaggedDocs = [];
  }

  void _resetStats() {
    totalPaid = 0.0; totalReceived = 0.0; totalCompulsory = 0.0; totalAdditional = 0.0;
    totalNonComplianceCount = 0; totalDisputes = 0; communicationCount = 0;
    transferIssuesCount = 0; paymentDisputesCount = 0;
    flaggedCustodyCount = 0; flaggedPaymentsCount = 0; flaggedDisputesCount = 0; flaggedNonComplianceCount = 0;
    flaggedEvents = [];
    totalCustodyNights = 0; totalCustodyEntries = 0;
  }

  String getCaseDisplayName(dynamic caseItem) {
    if (caseItem is! CaseModel) return "Select Case";
    return caseDisplayName(caseItem, emptyFallback: "No Case Reference Number");
  }

  Future<void> fetchAllEventsForReport() async {
    if (_selectedCase == null) return;
    try {
      _isLoading = true; notifyListeners();
      final userId = _auth.currentUser!.uid;
      final caseId = _selectedCase!.id;
      const collections = ['paymentRecords', 'custodyRecords', 'disputeRecords', 'nonComplianceRecords'];
      final snaps = await Future.wait(collections.map((c) =>
          _firestore.collection('users').doc(userId).collection('cases').doc(caseId).collection(c).get()));
      // Tag each doc with its collection: record docs don't store their type,
      // and newer custody docs no longer carry the 'isFulfilled' key that
      // CalendarEvent.fromMap used to sniff them out by.
      _allEvents = [
        for (var i = 0; i < collections.length; i++)
          ...snaps[i].docs.map((d) => CalendarEvent.fromMap(
              {...d.data(), 'originCollection': collections[i]}, docId: d.id)),
      ];
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
