import 'package:clearcase/models/calender_event_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../models/case_model.dart';

class CalendarProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<ChildModel> get children => _selectedCase?.children ?? [];
  // Map to store events: Date -> List of Events
  final Map<DateTime, List<CalendarEvent>> _events = {};
  List<CalendarEvent> get allEvents => _events.values.expand((element) => element).toList();
  List<CaseModel> _allCases = [];
  CaseModel? _selectedCase;

  List<CaseModel> get allCases => _allCases;
  CaseModel? get selectedCase => _selectedCase;
  DateTime get focusedDay => _focusedDay;
  DateTime? get selectedDay => _selectedDay;

  CalendarProvider() {
    _selectedDay = _focusedDay;
    fetchUserCases();
  }

  // --- CASE FETCHING LOGIC ---

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
        setSelectedCase(_allCases.first);
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching cases: $e");
    }
  }

  void setSelectedCase(CaseModel? selected) {
    if (_selectedCase?.id == selected?.id) return;
    _selectedCase = selected;
    _events.clear();
    if (selected != null) {
      fetchEventsForCase(selected.id);
    }
    notifyListeners();
  }

  // --- UPDATED RULE GENERATION LOGIC ---

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
        // Check if frequency exists and isn't a string "null" or "None"
        String? freq = data['repeatFrequency'];
        bool hasValidFrequency = freq != null && freq != "None" && freq != "null";

         bool shouldRepeat =  hasValidFrequency;

         String frequency = hasValidFrequency ? freq : "None";

        if (startDate == null) continue;

        List<DateTime> instances = _generateRuleInstances(
          startDate: startDate,
          endDate: endDate,
          isRepeat: shouldRepeat,
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
            description: data['notes'] ,
            childNames: _resolveChildNames(
              (data['appliedChildren'] as List? ?? [])
                  .map((c) => c['id'].toString())
                  .toList(),

            ),
          ));
        }
      }
    } catch (e) {
      debugPrint("Error fetching scheduled rules: $e");
    }
  }

  List<DateTime> _generateRuleInstances({
    required DateTime startDate,
    DateTime? endDate,
    required bool isRepeat,
    required String frequency,
  }) {
    List<DateTime> instances = [];
    // Normalize to midnight
    DateTime currentStart = DateTime(startDate.year, startDate.month, startDate.day);

    // Scenario 3: Non-Repeating Range (Case 2 in Table)
    // If no frequency and an end date exists, fill every day in between
    if (!isRepeat && endDate != null) {
      DateTime rangeEnd = DateTime(endDate.year, endDate.month, endDate.day);
      while (!currentStart.isAfter(rangeEnd)) {
        instances.add(currentStart);
        currentStart = currentStart.add(const Duration(days: 1));
      }
      return instances;
    }

    // Scenario 1 & 2: Repeating events (Case 3, 4, 5 in Table)
    // Set a rule limit (default 2 years if endDate is null)
    DateTime ruleLimit = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day)
        : currentStart.add(const Duration(days: 730));

    while (!currentStart.isAfter(ruleLimit)) {
      instances.add(currentStart);

      if (isRepeat) {
        if (frequency == "Weekly") {
          currentStart = currentStart.add(const Duration(days: 7));
        } else if (frequency == "Fortnightly") {
          currentStart = currentStart.add(const Duration(days: 14));
        } else if (frequency == "Monthly") {
          currentStart = DateTime(currentStart.year, currentStart.month + 1, currentStart.day);
        } else if (frequency == "Daily") {
          currentStart = currentStart.add(const Duration(days: 1));
        } else {
          break;
        }
      } else {
        break; // Scenario 1: One-time single event (Case 1 in Table)
      }
    }
    return instances;
  }

  // --- CORE DATA PROCESSING ---

  Future<void> fetchEventsForCase(String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _events.clear();
    notifyListeners();

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
            isFulfilled: data['isReceived'] == true, // PDF Logic
            isScheduled: data['isScheduled'] == true,
            paymentCategory: data['paymentCategory'],
            paymentMethod: data['paymentMethod'],
            transactionType: data['transactionType'],
            status: data['transactionType'],
            attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
          ));
        }
      }

      // 2. Process Custody (FIXED HERE)
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
            attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),

            // இந்த வரிகள் மிக முக்கியம் - இவைதான் PDF-இல் 'Completed' என காட்டும்
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
            attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
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
            attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
          ));
        }
      }
    } catch (e) {
      debugPrint("Error loading events: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  // --- HELPERS ---

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
    } catch (e) { debugPrint("Reminder fetch error: $e"); }
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

    _isLoading = true;
    notifyListeners();

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
      await fetchEventsForCase(caseId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Record deleted successfully"), behavior: SnackBarBehavior.floating));
      }
    } catch (e) { debugPrint("Delete error: $e"); } finally { _isLoading = false; notifyListeners(); }
  }
}