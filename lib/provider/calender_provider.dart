import 'package:clearcase/models/calender_event_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../core/utils/attachments.dart';
import '../core/utils/child_names.dart';
import '../core/utils/custody_span.dart';
import '../core/utils/date_range_selection.dart';
import '../models/case_model.dart';
import '../models/remainder_model.dart';
import '../services/case_selection_service.dart';
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

  /// Every event once. Multi-day custody entries are filed under each day they
  /// cover, so they're de-duplicated by id here (the PDF export reads this).
  List<CalendarEvent> get allEvents {
    final seenCustody = <String>{};
    return _events.values
        .expand((element) => element)
        .where((e) => e.type != EventType.custody || seenCustody.add(e.id))
        .toList();
  }

  // Date-range selection (long-press a day, or the "Select date range"
  // button). Held here rather than inside TableCalendar so it survives month
  // navigation and the loader that replaces the calendar during refetches.
  bool _isRangeMode = false;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool get isRangeMode => _isRangeMode;
  DateTime? get rangeStart => _rangeStart;
  DateTime? get rangeEnd => _rangeEnd;
  List<CaseModel> _allCases = [];
  CaseModel? _selectedCase;

  // Stream Subscriptions for automatic updates
  StreamSubscription? _casesSubscription;
  final List<StreamSubscription> _eventSubscriptions = [];
  StreamSubscription<User?>? _authSubscription;
  String? _currentUid;

  // Debouncer + reentrancy guard for the 6 sub-collection listeners. Any
  // single record write fires all 6 listeners; the timer coalesces those
  // into one fetch, and the in-flight flag prevents the next fetch from
  // racing with an unfinished one (which would clear+repopulate `_events`
  // concurrently and lose data).
  Timer? _refetchDebounce;
  bool _fetchInFlight = false;
  bool _pendingRefetch = false;

  // The selected case's reminders, and the schedules saved by the old
  // case-setup flow (`scheduledRules` docs, with 'id' added). Rebuilt on
  // every fetch alongside _events.
  List<ReminderModel> _reminders = [];
  List<Map<String, dynamic>> _scheduledRules = [];
  List<ReminderModel> get reminders => _reminders;
  List<Map<String, dynamic>> get scheduledRules => _scheduledRules;

  List<CaseModel> get allCases => _allCases;
  CaseModel? get selectedCase => _selectedCase;
  DateTime get focusedDay => _focusedDay;
  DateTime? get selectedDay => _selectedDay;

  CalendarProvider() {
    _selectedDay = _focusedDay;
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

  // Default selection on first load: honour a case already chosen elsewhere in
  // the app, otherwise fall back to the first case.
  CaseModel _initialCase() {
    final id = CaseSelectionService.instance.selectedCaseId;
    if (id != null) {
      final matches = _allCases.where((c) => c.id == id);
      if (matches.isNotEmpty) return matches.first;
    }
    return _allCases.first;
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
    _refetchDebounce?.cancel();
    _refetchDebounce = null;
    _casesSubscription?.cancel();
    _casesSubscription = null;
    for (var sub in _eventSubscriptions) {
      sub.cancel();
    }
    _eventSubscriptions.clear();
    _fetchInFlight = false;
    _pendingRefetch = false;
    _events.clear();
    _reminders = [];
    _scheduledRules = [];
    _allCases = [];
    _selectedCase = null;
    CaseSelectionService.instance.clear();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _isRangeMode = false;
    _rangeStart = null;
    _rangeEnd = null;
    _initialLoad = true;
    _ongoing = 0;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    CaseSelectionService.instance.removeListener(_onSharedSelectionChanged);
    _authSubscription?.cancel();
    _refetchDebounce?.cancel();
    _casesSubscription?.cancel();
    for (var sub in _eventSubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  // Guard against notifying after disposal (in-flight async fetches/timers).
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
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
          setSelectedCase(_initialCase());
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
    // If the same case is selected, do nothing (but keep shared state in sync).
    if (_selectedCase?.id == selected?.id && _events.isNotEmpty) {
      CaseSelectionService.instance.select(selected?.id);
      return;
    }

    _selectedCase = selected;
    // Broadcast AFTER updating local state so our own listener sees them in
    // sync and ignores the notification — this prevents reentrancy. Other
    // screens see a changed id and follow.
    CaseSelectionService.instance.select(selected?.id);
    _events.clear();
    _reminders = [];
    _scheduledRules = [];
    _isRangeMode = false;
    _rangeStart = null;
    _rangeEnd = null;

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
      'nonComplianceRecords',
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
        caseDocRef.collection('nonComplianceRecords').get(),
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
            childIds: List<String>.from(data['childIds'] ?? []),
            isFlagged: data['flagEntry'] == true,
            location: data['location'],
            isReceived: data['isReceived'] == true,
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

        final span = CustodySpan.fromMap(data);
        if (span != null) {
          final event = CalendarEvent(
            id: doc.id,
            title: data['notes'] ?? 'Custody Record',
            date: span.start,
            endDate: span.end,
            startTime: (data['startTime'] as Timestamp?)?.toDate(),
            endTime: (data['endTime'] as Timestamp?)?.toDate(),
            type: EventType.custody,
            description: data['notes'],
            childNames: _resolveChildNames(data['childIds'] ?? []),
            childIds: List<String>.from(data['childIds'] ?? []),
            isFlagged: data['flagEntry'] == true,
            attachmentUrls: readAttachmentUrls(data),
            location: data['location'],
          );
          // A multi-day entry sits on every day it covers so the calendar can
          // draw it as one continuous bar. Capped so a mistyped end year can't
          // generate thousands of map entries.
          for (final day in span.days.take(_maxCustodySpanDays)) {
            _addEventToMap(event, day: day);
          }
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
            childNames: _resolveChildNames(readChildIds(data)),
            childIds: readChildIds(data),
            isFlagged: data['flagEntry'] == true,
            attachmentUrls: readAttachmentUrls(data),
          ));
        }
      }

      // 4. Process Non-compliances
      for (var doc in snapshots[3].docs) {
        final data = doc.data();
        final DateTime? date = (data['date'] as Timestamp?)?.toDate();
        if (date != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['type'] ?? 'Non-compliance',
            date: date,
            type: EventType.nonCompliance,
            description: data['description'],
            childNames: _resolveChildNames(readChildIds(data)),
            childIds: readChildIds(data),
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

      _scheduledRules = snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        String category = doc.id.toLowerCase();
        DateTime? startDate = DateTime.tryParse(data['startDate'] ?? "");
        DateTime? endDate = DateTime.tryParse(data['endDate'] ?? "");
        String? freq = data['repeatFrequency'];
        bool hasValidFrequency = freq != null && freq != "None" && freq != "null";
        String frequency = hasValidFrequency ? freq : "None";

        // Selected weekdays for the "Custom" frequency (DateTime.weekday: Mon=1..Sun=7)
        final List<int> customDays =
            ((data['customDays'] as List?) ?? []).map((e) => (e as num).toInt()).toList();

        if (startDate == null) continue;

        List<DateTime> instances = _generateRuleInstances(
          startDate: startDate,
          endDate: endDate,
          isRepeat: hasValidFrequency,
          frequency: frequency,
          customDays: customDays,
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
            // The rule doc id, so a tap can open the rule for editing.
            category: doc.id,
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
    List<int> customDays = const [],
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

    // CUSTOM: highlight every selected weekday from start until end date,
    // or two years out when no end date is set (matches other frequencies).
    if (isRepeat && frequency == "Custom") {
      if (customDays.isEmpty) return instances;
      DateTime customLimit = endDate != null
          ? DateTime(endDate.year, endDate.month, endDate.day)
          : currentStart.add(const Duration(days: 730));
      DateTime cursor = currentStart;
      while (!cursor.isAfter(customLimit)) {
        if (customDays.contains(cursor.weekday)) instances.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
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

  static const int _maxCustodySpanDays = 400;

  /// Files [event] under [day] (defaults to the event's own date).
  void _addEventToMap(CalendarEvent event, {DateTime? day}) {
    final on = day ?? event.date;
    final dayKey = DateTime(on.year, on.month, on.day);
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

  // --- DATE-RANGE SELECTION ---

  /// Enters range mode. [from] (a long-pressed day) becomes the range start;
  /// without it the next tapped day does.
  void startRangeSelection([DateTime? from]) {
    _isRangeMode = true;
    _rangeStart = from == null ? null : DateTime(from.year, from.month, from.day);
    _rangeEnd = null;
    if (from != null) _focusedDay = from;
    notifyListeners();
  }

  DateRangeSelection get _selection => _isRangeMode
      ? DateRangeSelection(start: _rangeStart, end: _rangeEnd)
      : const DateRangeSelection();

  void _applySelection(DateRangeSelection r) {
    if (_isRangeMode && _rangeStart == r.start && _rangeEnd == r.end) return;
    _isRangeMode = true;
    _rangeStart = r.start;
    _rangeEnd = r.end;
    notifyListeners();
  }

  /// A tap while in range mode: the first tap sets the start, the second the
  /// end (in either order). After that, a tap on another month continues the
  /// range; a tap on the range's own month starts over.
  void selectRangeDay(DateTime day, DateTime focused) {
    _focusedDay = focused;
    _applySelection(DateRangeSelection.tap(_selection, day));
    notifyListeners();
  }

  // Selection as it was when the current swipe began.
  DateRangeSelection _swipeBase = const DateRangeSelection();

  /// Call once when a swipe starts, before [updateSwipe].
  void beginSwipe() => _swipeBase = _selection;

  /// A swipe across the calendar: [anchor] is the day the finger went down
  /// on, [current] the day it's over now (either direction). On a month the
  /// range doesn't start/end in, it continues the range (see
  /// DateRangeSelection) — so 26–30 Sep, then 1–5 Oct on the next page,
  /// gives 26 Sep – 5 Oct.
  void updateSwipe(DateTime anchor, DateTime current) {
    _applySelection(DateRangeSelection.swipe(
      base: _swipeBase,
      anchor: anchor,
      current: current,
    ));
  }

  void cancelRangeSelection() {
    if (!_isRangeMode && _rangeStart == null) return;
    _isRangeMode = false;
    _rangeStart = null;
    _rangeEnd = null;
    notifyListeners();
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String getCaseDisplayName(CaseModel caseItem) => caseDisplayName(caseItem);

  /// Saves [relation] / [name] as the case's related party, which pre-fills
  /// new disputes and non-compliance records. The cases stream picks it up.
  Future<void> saveRelatedParty(String caseId, {required String relation, required String name}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId).update({
        'relatedPartyRelation': relation,
        'relatedPartyName': name,
      });
    } catch (e) {
      debugPrint("Save related party error: $e");
    }
  }

  Future<void> fetchRemindersForCase(String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snapshot = await _firestore.collection('users').doc(user.uid)
          .collection('cases').doc(caseId).collection('reminders').get();

      _reminders = snapshot.docs.map((d) => ReminderModel.fromMap(d.data(), d.id)).toList();

      // Repeated reminders are generated from their start to two years past
      // today (or their end date), like the old scheduled rules.
      final horizon = DateTime.now().add(const Duration(days: 730));
      for (final reminder in _reminders) {
        final dates = reminder.isRepeat
            ? reminder.occurrencesBetween(reminder.date, horizon).take(_maxReminderOccurrences)
            : [reminder.date];
        for (final date in dates) {
          _addEventToMap(CalendarEvent(
            id: reminder.id!,
            title: reminder.title.isEmpty ? 'Reminder' : reminder.title,
            date: date,
            type: EventType.reminder,
            description: reminder.description,
            category: reminder.tag,
            color: reminder.color,
            isRepeatedReminder: reminder.isRepeat,
          ));
        }
      }
    } catch (e) { debugPrint("Reminder error: $e"); }
  }

  // Caps one repeated reminder's generated days (daily-ish for ~5 years).
  static const int _maxReminderOccurrences = 2000;

  /// Reminders from today onwards — single, repeated, and the old case-setup
  /// schedules — in date order, one entry per occurrence.
  List<CalendarEvent> upcomingReminders({int days = 90, int limit = 100}) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(Duration(days: days));
    final keys = _events.keys
        .where((d) => !d.isBefore(start) && !d.isAfter(end))
        .toList()
      ..sort();
    final result = <CalendarEvent>[];
    for (final day in keys) {
      for (final e in _events[day]!) {
        if (e.type == EventType.reminder || e.isScheduledRule) result.add(e);
      }
      if (result.length >= limit) break;
    }
    return result.take(limit).toList();
  }

  /// Deletes a schedule saved by the old case-setup flow.
  Future<void> deleteScheduledRule(String ruleId) async {
    final user = _auth.currentUser;
    final caseId = _selectedCase?.id;
    if (user == null || caseId == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId)
          .collection('scheduledRules').doc(ruleId).delete();
    } catch (e) {
      debugPrint("Delete rule error: $e");
    }
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
        case EventType.nonCompliance: coll = 'nonComplianceRecords'; break;
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

