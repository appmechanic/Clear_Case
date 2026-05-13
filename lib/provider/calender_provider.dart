import 'package:clearcase/models/calender_event_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../core/utils/attachments.dart';
import '../models/case_model.dart';
import 'dart:async';


class CalendarProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Loader state. The 6 collection-listeners all call fetchEventsForCase in
  // parallel on every Firestore notification, so a single bool would flap
  // (true → false → true → false) as each fetch finishes. A counter keeps
  // the loader on until *every* in-flight fetch is done. The latch covers
  // the gap between app open and the first fetch firing.
  bool _initialLoad = true;
  int _ongoing = 0;
  bool get isLoading => _initialLoad || _ongoing > 0;

  void _beginBusy() {
    _ongoing++;
    notifyListeners();
  }

  void _endBusy() {
    if (_ongoing > 0) _ongoing--;
    if (_initialLoad) _initialLoad = false;
    notifyListeners();
  }
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<ChildModel> get children => _selectedCase?.children ?? [];

  final Map<DateTime, List<CalendarEvent>> _events = {};
  List<CalendarEvent> get allEvents =>
      _events.values.expand((element) => element).toList();
  List<CaseModel> _allCases = [];
  CaseModel? _selectedCase;

  // Stream Subscriptions for automatic updates
  StreamSubscription? _casesSubscription;
  final List<StreamSubscription> _eventSubscriptions = [];

  // Debouncer + reentrancy guard for the 6 sub-collection listeners. Any
  // single record write fires all 6 listeners; the timer coalesces those
  // into one fetch, and the in-flight flag prevents the next fetch from
  // racing with an unfinished one (which would clear+repopulate `_events`
  // concurrently and lose data).
  Timer? _refetchDebounce;
  bool _fetchInFlight = false;
  bool _pendingRefetch = false;

  List<CaseModel> get allCases => _allCases;
  CaseModel? get selectedCase => _selectedCase;
  DateTime get focusedDay => _focusedDay;
  DateTime? get selectedDay => _selectedDay;

  CalendarProvider() {
    _selectedDay = _focusedDay;
    listenToUserCases();
  }

  @override
  void dispose() {
    _refetchDebounce?.cancel();
    _casesSubscription?.cancel();
    for (var sub in _eventSubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  /// Coalesces bursty Firestore notifications into a single fetch ~200ms
  /// after the last change. If a fetch is already running, marks a pending
  /// follow-up so the next refetch picks up anything that arrived mid-flight.
  void _scheduleRefetch(String caseId) {
    _refetchDebounce?.cancel();
    _refetchDebounce = Timer(const Duration(milliseconds: 200), () {
      _runRefetch(caseId);
    });
  }

  Future<void> _runRefetch(String caseId) async {
    if (_fetchInFlight) {
      _pendingRefetch = true;
      return;
    }
    _fetchInFlight = true;
    try {
      await fetchEventsForCase(caseId);
    } finally {
      _fetchInFlight = false;
      if (_pendingRefetch) {
        _pendingRefetch = false;
        _scheduleRefetch(caseId);
      }
    }
  }

  // --- AUTOMATIC CASE UPDATES ---

  void listenToUserCases() {
    final user = _auth.currentUser;
    if (user == null) return;

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

      if (_allCases.isNotEmpty) {
        if (_selectedCase == null) {
          setSelectedCase(_allCases.first);
        } else {
          // Update the selected case object if metadata changed
          final stillExists = _allCases.any((c) => c.id == _selectedCase!.id);
          if (stillExists) {
            _selectedCase = _allCases.firstWhere((c) => c.id == _selectedCase!.id);
          } else {
            setSelectedCase(_allCases.first);
          }
        }
      }
      notifyListeners();
    }, onError: (e) => debugPrint("Cases Stream Error: $e"));
  }

  void setSelectedCase(CaseModel? selected) {
    // If the same case is selected, do nothing
    if (_selectedCase?.id == selected?.id && _events.isNotEmpty) return;

    _selectedCase = selected;
    _events.clear();

     _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    // -----------------------

    if (selected != null) {
      listenToEventsForCase(selected.id);
    }

    notifyListeners();
  }
  // --- AUTOMATIC EVENT UPDATES ---

  void listenToEventsForCase(String caseId) {
    final user = _auth.currentUser;
    if (user == null) return;

    // Clear old subscriptions
    for (var sub in _eventSubscriptions) {
      sub.cancel();
    }
    _eventSubscriptions.clear();

    final caseDocRef = _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId);

    // List of collections to watch for changes
    final collections = [
      'paymentRecords',
      'custodyRecords',
      'disputeRecords',
      'breachRecords',
      'reminders',
      'scheduledRules'
    ];

    for (var coll in collections) {
      final sub = caseDocRef.collection(coll).snapshots().listen((_) {
        // Debounced + serialised so the 6 sub-collection listeners trigger
        // ONE refetch per burst of changes instead of six concurrent ones.
        _scheduleRefetch(caseId);
      });
      _eventSubscriptions.add(sub);
    }
  }

  // --- CORE DATA PROCESSING ---

  Future<void> fetchEventsForCase(String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _beginBusy();
    _events.clear();

    try {
      final caseDocRef = _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId);

      final snapshots = await Future.wait([
        caseDocRef.collection('paymentRecords').get(),
        caseDocRef.collection('custodyRecords').get(),
        caseDocRef.collection('disputeRecords').get(),
        caseDocRef.collection('breachRecords').get(),
      ]);

      await fetchRemindersForCase(caseId);
      await _fetchScheduledRulesForCase(caseId);

      // 1. Process Payments
      for (var doc in snapshots[0].docs) {
        final data = doc.data();
        final DateTime? recordDate = (data['date'] as Timestamp?)?.toDate();

        if (recordDate != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['paymentType'] ?? 'Payment',
            date: recordDate,
            type: EventType.payment,
            description: data['notes'],
            amount: (data['amount'] as num?)?.toDouble(),
            childNames: _resolveChildNames(data['childIds'] ?? []),
            isFlagged: data['flagEntry'] == true,
            location: data['location'],
            isReceived: data['isReceived'] == true,
            isFulfilled: data['isReceived'] == true,
            isScheduled: data['isScheduled'] == true,
            paymentCategory: data['paymentCategory'],
            paymentMethod: data['paymentMethod'],
            transactionType: data['transactionType'],
            status: data['transactionType'],
            attachmentUrls: readAttachmentUrls(data),
          ));
        }
      }

      // 2. Process Custody
      for (var doc in snapshots[1].docs) {
        final data = doc.data();
        if (data.containsKey('frequency') || data.containsKey('notificationPref')) continue;

        final Timestamp? timestamp = data['startDate'] as Timestamp?;
        if (timestamp != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['notes'] ?? 'Custody Record',
            date: timestamp.toDate(),
            type: EventType.custody,
            description: data['notes'],
            childNames: _resolveChildNames(data['childIds'] ?? []),
            isFlagged: data['flagEntry'] == true,
            attachmentUrls: readAttachmentUrls(data),
            isFulfilled: data['isFulfilled'] == true,
            isScheduled: data['isScheduled'] == true,
            location: data['location'],
          ));
        }
      }

      // 3. Process Disputes
      for (var doc in snapshots[2].docs) {
        final data = doc.data();
        final DateTime? date = (data['date'] as Timestamp?)?.toDate();
        if (date != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['issue'] ?? 'Dispute',
            date: date,
            type: EventType.dispute,
            description: data['description'],
            category: data['category'],
            party: data['party'],
            isFlagged: data['flagEntry'] == true,
            attachmentUrls: readAttachmentUrls(data),
          ));
        }
      }

      // 4. Process Breaches
      for (var doc in snapshots[3].docs) {
        final data = doc.data();
        final DateTime? date = (data['date'] as Timestamp?)?.toDate();
        if (date != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['type'] ?? 'Breach',
            date: date,
            type: EventType.breach,
            description: data['description'],
            isFlagged: data['flagEntry'] == true,
            party: data['party'],
            severity: data['severity'],
            proof: data['proof'],
            attachmentUrls: readAttachmentUrls(data),
          ));
        }
      }
    } catch (e) {
      debugPrint("Error loading events: $e");
    } finally {
      _endBusy();
    }
  }

  // --- RULE GENERATION ---

  Future<void> _fetchScheduledRulesForCase(String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users').doc(user.uid)
          .collection('cases').doc(caseId)
          .collection('scheduledRules')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        String category = doc.id.toLowerCase();
        DateTime? startDate = DateTime.tryParse(data['startDate'] ?? "");
        DateTime? endDate = DateTime.tryParse(data['endDate'] ?? "");
        String? freq = data['repeatFrequency'];
        bool hasValidFrequency = freq != null && freq != "None" && freq != "null";
        String frequency = hasValidFrequency ? freq : "None";

        if (startDate == null) continue;

        List<DateTime> instances = _generateRuleInstances(
          startDate: startDate,
          endDate: endDate,
          isRepeat: hasValidFrequency,
          frequency: frequency,
        );

        for (DateTime instanceDate in instances) {
          String dateKey = "${instanceDate.year}-${instanceDate.month}-${instanceDate.day}";
          _addEventToMap(CalendarEvent(
            id: "rule_${category}_${doc.id}_$dateKey",
            title: "Scheduled ${category[0].toUpperCase()}${category.substring(1)}",
            date: instanceDate,
            type: category == 'custody'
                ? EventType.custody
                : (category == 'payment' ? EventType.payment : EventType.reminder),
            description: data['notes'],
            childNames: _resolveChildNames(
              (data['appliedChildren'] as List? ?? [])
                  .map((c) => c['id'].toString())
                  .toList(),
            ),
          ));
        }
      }
    } catch (e) {
      debugPrint("Error fetching rules: $e");
    }
  }

  List<DateTime> _generateRuleInstances({
    required DateTime startDate,
    DateTime? endDate,
    required bool isRepeat,
    required String frequency,
  }) {
    List<DateTime> instances = [];
    DateTime currentStart = DateTime(startDate.year, startDate.month, startDate.day);

    if (!isRepeat && endDate != null) {
      DateTime rangeEnd = DateTime(endDate.year, endDate.month, endDate.day);
      while (!currentStart.isAfter(rangeEnd)) {
        instances.add(currentStart);
        currentStart = currentStart.add(const Duration(days: 1));
      }
      return instances;
    }

    DateTime ruleLimit = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day)
        : currentStart.add(const Duration(days: 730));

    while (!currentStart.isAfter(ruleLimit)) {
      instances.add(currentStart);
      if (isRepeat) {
        if (frequency == "Weekly") currentStart = currentStart.add(const Duration(days: 7));
        else if (frequency == "Fortnightly") currentStart = currentStart.add(const Duration(days: 14));
        else if (frequency == "Monthly") currentStart = DateTime(currentStart.year, currentStart.month + 1, currentStart.day);
        else if (frequency == "Daily") currentStart = currentStart.add(const Duration(days: 1));
        else break;
      } else {
        break;
      }
    }
    return instances;
  }

  void _addEventToMap(CalendarEvent event) {
    final dayKey = DateTime(event.date.year, event.date.month, event.date.day);
    if (_events[dayKey] == null) _events[dayKey] = [];
    if (!_events[dayKey]!.any((existing) => existing.id == event.id)) {
      _events[dayKey]!.add(event);
    }
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void onDaySelected(DateTime selected, DateTime focused) {
    if (!isSameDay(_selectedDay, selected)) {
      _selectedDay = selected;
      _focusedDay = focused;
      notifyListeners();
    }
  }

  void onPageChanged(DateTime focused) => { _focusedDay = focused, notifyListeners() };

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String getCaseDisplayName(CaseModel caseItem) {
    if (caseItem.children.isEmpty) return caseItem.caseNumber;
    return "${caseItem.caseNumber} (${caseItem.children.map((c) => c.name.trim()).join(' & ')})";
  }

  Future<void> fetchRemindersForCase(String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snapshot = await _firestore.collection('users').doc(user.uid)
          .collection('cases').doc(caseId).collection('reminders').get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        DateTime start = (data['date'] as Timestamp).toDate();
        DateTime? end = (data['ruleEndDate'] as Timestamp?)?.toDate();
        String repeat = data['repeatOption'] ?? "None";

        List<DateTime> dates = _generateRecurringDates(start, end, repeat);
        for (DateTime date in dates) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['title'] ?? 'Reminder',
            date: date,
            type: EventType.reminder,
            description: data['description'],
          ));
        }
      }
    } catch (e) { debugPrint("Reminder error: $e"); }
  }

  List<DateTime> _generateRecurringDates(DateTime start, DateTime? end, String repeat) {
    List<DateTime> dates = [start];
    DateTime limit = end ?? start.add(const Duration(days: 365));
    DateTime current = start;
    if (repeat == "None") return dates;
    while (current.isBefore(limit)) {
      if (repeat == "Daily") current = current.add(const Duration(days: 1));
      else if (repeat == "Weekly") current = current.add(const Duration(days: 7));
      else if (repeat == "Monthly") current = DateTime(current.year, current.month + 1, current.day);
      else break;
      if (!current.isAfter(limit)) dates.add(current);
    }
    return dates;
  }

  List<String> _resolveChildNames(List<dynamic> childIds) {
    if (_selectedCase == null) return [];
    return childIds.map((id) => _selectedCase!.children.firstWhere((c) => c.id == id,
        orElse: () => ChildModel(id: '', name: 'Unknown', dob: DateTime.now())).name).toList();
  }

  Future<void> deleteRecord({
    required BuildContext context,
    required String recordId,
    required EventType type,
    required List<String> attachmentUrls,
  }) async {
    final user = _auth.currentUser;
    final caseId = _selectedCase?.id;
    if (user == null || caseId == null) return;

    _beginBusy();

    try {
      final storage = FirebaseStorage.instance;
      for (String url in attachmentUrls) {
        try { await storage.refFromURL(url).delete(); } catch (_) {}
      }

      String coll = '';
      switch (type) {
        case EventType.custody: coll = 'custodyRecords'; break;
        case EventType.payment: coll = 'paymentRecords'; break;
        case EventType.dispute: coll = 'disputeRecords'; break;
        case EventType.breach: coll = 'breachRecords'; break;
        case EventType.reminder: coll = 'reminders'; break;
      }

      WriteBatch batch = _firestore.batch();
      var flagged = await _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId)
          .collection('flaggedEvents').where('originId', isEqualTo: recordId).get();
      for (var d in flagged.docs) batch.delete(d.reference);

      batch.delete(_firestore.collection('users').doc(user.uid).collection('cases').doc(caseId).collection(coll).doc(recordId));
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Record deleted successfully")));
      }
    } catch (e) { debugPrint("Delete error: $e"); } finally { _endBusy(); }
  }
}

