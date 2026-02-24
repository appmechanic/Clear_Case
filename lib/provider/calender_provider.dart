import 'package:clearcase/models/calender_event_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/case_model.dart';

// class CalendarProvider extends ChangeNotifier {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase');
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//
//   bool _isLoading = false;
//   bool get isLoading => _isLoading;
//   DateTime _focusedDay = DateTime.now();
//   DateTime? _selectedDay;
//
//   // Map to store events: Date -> List of Events
//   final Map<DateTime, List<CalendarEvent>> _events = {};
//
//   CalendarProvider() {
//     _selectedDay = _focusedDay;
//     _loadMockEvents();
//     fetchUserCases(); // Start fetching from Firebase immediately
//
//   }
//
//   DateTime get focusedDay => _focusedDay;
//   DateTime? get selectedDay => _selectedDay;
//
//
//   List<CaseModel> _allCases = [];
//   CaseModel? _selectedCase;
//
//   List<CaseModel> get allCases => _allCases;
//   CaseModel? get selectedCase => _selectedCase;
//
//   // --- NEW LOGIC FOR CALENDAR DROPDOWN ---
//
//   // Formats: "12345 (Jack & Sam)"
//   String getCaseDisplayName(CaseModel caseItem) {
//     if (caseItem.children.isEmpty) return caseItem.caseNumber;
//     String childrenString = caseItem.children.map((c) => c.name.trim()).join(' & ');
//     return "${caseItem.caseNumber} ($childrenString)";
//   }
//
//   Future<void> fetchUserCases() async {
//     final user = _auth.currentUser;
//     if (user == null) return;
//
//     try {
//       final snapshot = await _firestore
//           .collection('users')
//           .doc(user.uid)
//           .collection('cases')
//           .get();
//
//       _allCases = snapshot.docs.map((doc) {
//         var model = CaseModel.fromMap(doc.data());
//         model.id = doc.id;
//         return model;
//       }).toList();
//
//       // Default selection to the first case if none is selected
//       if (_allCases.isNotEmpty && _selectedCase == null) {
//         _selectedCase = _allCases.first;
//       }
//       notifyListeners();
//     } catch (e) {
//       debugPrint("Error fetching cases: $e");
//     }
//   }
//
//   void setSelectedCase(CaseModel? selected) {
//     _selectedCase = selected;
//     notifyListeners();
//   }
//
//   List<CalendarEvent> getEventsForDay(DateTime day) {
//     // Normalize date to remove time part for map lookup
//     final normalizedDate = DateTime(day.year, day.month, day.day);
//     return _events[normalizedDate] ?? [];
//   }
//
//   void onDaySelected(DateTime selected, DateTime focused) {
//     if (!isSameDay(_selectedDay, selected)) {
//       _selectedDay = selected;
//       _focusedDay = focused;
//       notifyListeners();
//     }
//   }
//
//   void onPageChanged(DateTime focused) {
//     _focusedDay = focused;
//     notifyListeners();
//   }
//
//   // Helper to normalize dates
//   bool isSameDay(DateTime? a, DateTime? b) {
//     if (a == null || b == null) return false;
//     return a.year == b.year && a.month == b.month && a.day == b.day;
//   }
//
//   void _loadMockEvents() {
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//
//     // Mock Data based on your screenshots
//     _events[today] = [
//       CalendarEvent(id: '1', title: 'Custody Handover', date: today, type: EventType.custody),
//     ];
//
//     _events[today.add(const Duration(days: 2))] = [
//       CalendarEvent(id: '2', title: 'Child Support', date: today, type: EventType.payment),
//       CalendarEvent(id: '3', title: 'Dispute', date: today, type: EventType.dispute),
//     ];
//
//     notifyListeners();
//   }
// }


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
      _events.clear(); // Clear existing markers before fetching new ones
      final caseDocRef = _firestore.collection('users').doc(user.uid).collection('cases').doc(caseId);

      // Fetch all categories at once
      final snapshots = await Future.wait([
        caseDocRef.collection('paymentRecords').get(),
        caseDocRef.collection('custodyRecords').get(),
        caseDocRef.collection('disputeRecords').get(),
      ]);

      // 1. Process Payments (Green dots)
      for (var doc in snapshots[0].docs) {
        final data = doc.data();
        final DateTime? recordDate = (data['date'] as Timestamp?)?.toDate();
        if (recordDate != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['paymentType'] ?? 'Payment',
            date: recordDate,
            type: EventType.payment,
            description: "Amount: ${data['amount']}",
          ));
        }
      }

      // 2. Process Custody (Purple dots)
      for (var doc in snapshots[1].docs) {
        final data = doc.data();
        final DateTime? recordDate = (data['date'] as Timestamp?)?.toDate();
        if (recordDate != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['title'] ?? 'Custody',
            date: recordDate,
            type: EventType.custody,
          ));
        }
      }

      // 3. Process Disputes (Orange dots)
      for (var doc in snapshots[2].docs) {
        final data = doc.data();
        final DateTime? recordDate = (data['date'] as Timestamp?)?.toDate();
        if (recordDate != null) {
          _addEventToMap(CalendarEvent(
            id: doc.id,
            title: data['issue'] ?? 'Dispute',
            date: recordDate,
            type: EventType.dispute,
          ));
        }
      }

    } catch (e) {
      debugPrint("Error loading calendar events: $e");
    } finally {
      _isLoading = false;
      notifyListeners(); // This tells the TableCalendar to redraw with the new dots
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
}