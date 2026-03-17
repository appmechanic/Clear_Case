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

  // Map to store events: Date -> List of Events
  final Map<DateTime, List<CalendarEvent>> _events = {};

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
        // This will trigger setSelectedCase which then fetches events
        setSelectedCase(_allCases.first);
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching cases: $e");
    }
  }

  // --- EVENT FETCHING LOGIC (DYNAMIC) ---

  void setSelectedCase(CaseModel? selected) {
    if (_selectedCase?.id == selected?.id) return; // Prevent redundant reloads

    _selectedCase = selected;

    // Clear old events so the UI updates immediately to a clean state
    _events.clear();

    if (selected != null) {
      fetchEventsForCase(selected.id);
    }

    notifyListeners();
  }

  Future<void> fetchEventsForCase(String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _events.clear();
      final caseDocRef = _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId);

      // 1. Fetch records in parallel
      final snapshots = await Future.wait([
        caseDocRef.collection('paymentRecords').get(),
        caseDocRef.collection('custodyRecords').get(),
        caseDocRef.collection('disputeRecords').get(),
        caseDocRef.collection('breachRecords').get(),
      ]);

      // 2. Fetch reminders
      await fetchRemindersForCase(caseId);

      // 3. Process Payments
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
            isFlagged: data['flagEntry'] ?? false, // <-- Added
            attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []), // ADD THIS
          ));
        }
      }

      // 4. Process Custody
      for (var doc in snapshots[1].docs) {
        final data = doc.data();
        if (data.containsKey('frequency') || data.containsKey('notificationPref')) continue;

        final Timestamp? timestamp = data['startDate'] as Timestamp?;
        if (timestamp != null) {
          List<String> childIds = List<String>.from(data['childIds'] ?? []);
          List<String> names = childIds.map((id) {
            return _selectedCase?.children
                .firstWhere((c) => c.id == id, orElse: () => ChildModel(id: '', name: 'Unknown', dob: DateTime.now()))
                .name ?? 'Unknown';
          }).toList();

          final DateTime recordDate = timestamp.toDate();
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['notes'] ?? 'Custody Record',
            date: recordDate,
            type: EventType.custody,
            description: data['notes'],
            childNames: names,
            isFlagged: data['flagEntry'] ?? false, // <-- Added
            attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []), // ADD THIS
          ));
        }
      }

      // 5. Process Disputes
      for (var doc in snapshots[2].docs) {
        final data = doc.data();
        final DateTime? recordDate = (data['date'] as Timestamp?)?.toDate();
        if (recordDate != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['issue'] ?? 'Dispute',
            date: recordDate,
            type: EventType.dispute,
            description: data['description'], // Added description if needed
            isFlagged: data['flagEntry'] ?? false, // <-- Added
            attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []), // ADD THIS
          ));
        }
      }

      // 6. Process Breaches
      for (var doc in snapshots[3].docs) {
        final data = doc.data();
        final DateTime? recordDate = (data['date'] as Timestamp?)?.toDate();
        if (recordDate != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['type'] ?? 'Breach',
            date: recordDate,
            type: EventType.breach,
            description: data['description'],
            isFlagged: data['flagEntry'] ?? false, // <-- Added
            attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []), // ADD THIS
          ));
        }
      }
    } catch (e) {
      debugPrint("Error loading calendar events: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

 // Helper to ensure events are grouped by day (removing time part)
  void _addEventToMap(CalendarEvent event) {
    final dayKey = DateTime(event.date.year, event.date.month, event.date.day);
    if (_events[dayKey] == null) {
      _events[dayKey] = [];
    }
    _events[dayKey]!.add(event);
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _events[normalizedDate] ?? [];
  }

  void onDaySelected(DateTime selected, DateTime focused) {
    if (!isSameDay(_selectedDay, selected)) {
      _selectedDay = selected;
      _focusedDay = focused;
      notifyListeners();
    }
  }

  void onPageChanged(DateTime focused) {
    _focusedDay = focused;
    notifyListeners();
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String getCaseDisplayName(CaseModel caseItem) {
    if (caseItem.children.isEmpty) return caseItem.caseNumber;
    String childrenString = caseItem.children.map((c) => c.name.trim()).join(' & ');
    return "${caseItem.caseNumber} ($childrenString)";
  }

  // Inside CalendarProvider

  Future<void> fetchRemindersForCase(String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(caseId)
          .collection('reminders') // Assuming this is your collection name
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        DateTime startDate = (data['date'] as Timestamp).toDate();
        DateTime? endDate = (data['ruleEndDate'] as Timestamp?)?.toDate();
        String repeat = data['repeatOption'] ?? "None";

        // Generate instances based on repeat logic
        List<DateTime> dates = _generateRecurringDates(startDate, endDate, repeat);

        for (DateTime date in dates) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['title'] ?? 'Reminder',
            date: date,
            type: EventType.reminder, // Make sure to add 'reminder' to your EventType enum
            description: data['description'],
          ));
        }
      }
    } catch (e) {
      debugPrint("Error fetching reminders: $e");
    }
  }

// Logic to expand recurring events
  List<DateTime> _generateRecurringDates(DateTime start, DateTime? end, String repeat) {
    List<DateTime> dates = [start];
    DateTime limit = end ?? start.add(const Duration(days: 365)); // Default 1 year if no end date

    DateTime current = start;
    while (current.isBefore(limit)) {
      if (repeat == "Daily") {
        current = current.add(const Duration(days: 1));
      } else if (repeat == "Weekly") current = current.add(const Duration(days: 7));
      else if (repeat == "Monthly") current = DateTime(current.year, current.month + 1, current.day);
      else break; // "None" or Custom not fully implemented here

      if (!current.isAfter(limit)) dates.add(current);
    }
    return dates;
  }

  List<String> _resolveChildNames(List<dynamic> childIds) {
    if (_selectedCase == null) return [];

    return childIds.map((id) {
      return _selectedCase!.children
          .firstWhere(
            (c) => c.id == id,
        orElse: () => ChildModel(id: '', name: 'Unknown', dob: DateTime.now()),
      )
          .name;
    }).toList();
  }

  // Inside CalendarProvider class

  Future<void> deleteRecord({
    required BuildContext context,
    required String recordId, // caseId can be taken from _selectedCase
    required EventType type,
    required List<String> attachmentUrls,
  }) async {
    final user = _auth.currentUser;
    final caseId = _selectedCase?.id;

    if (user == null || caseId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Delete Attachments from Storage
      // Use FirebaseStorage.instance directly if not defined as a variable
      final storage = FirebaseStorage.instance;
      for (String url in attachmentUrls) {
        try {
          await storage.refFromURL(url).delete();
        } catch (e) {
          debugPrint("Storage delete skip: $e");
        }
      }

      // 2. Collection Mapping
      String collectionName;
      switch (type) {
        case EventType.custody: collectionName = 'custodyRecords'; break;
        case EventType.payment: collectionName = 'paymentRecords'; break;
        case EventType.dispute: collectionName = 'disputeRecords'; break;
        case EventType.breach: collectionName = 'breachRecords'; break;
        case EventType.reminder: collectionName = 'reminders'; break;
      }

      WriteBatch batch = _firestore.batch();

      // 3. Delete from flaggedEvents
      var flaggedQuery = await _firestore
          .collection('users').doc(user.uid)
          .collection('cases').doc(caseId)
          .collection('flaggedEvents')
          .where('originId', isEqualTo: recordId)
          .get();

      for (var doc in flaggedQuery.docs) {
        batch.delete(doc.reference);
      }

      // 4. Delete main record
      DocumentReference mainDoc = _firestore
          .collection('users').doc(user.uid)
          .collection('cases').doc(caseId)
          .collection(collectionName).doc(recordId);

      batch.delete(mainDoc);

      await batch.commit();

      // 5. Refresh local data
      await fetchEventsForCase(caseId);

      if (context.mounted) {
        // Clear existing snackbars first to make sure this one shows up immediately
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Record deleted successfully"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}