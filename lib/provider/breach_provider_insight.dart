import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/breach_model.dart';
import '../models/filter_model.dart'; // Ensure this path is correct

// class BreachProviderInsight with ChangeNotifier {
//   final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
//     app: Firebase.app(),
//     databaseId: 'clearcase',
//   );
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   List<BreachRecordModel> _allBreaches = [];
//   List<BreachRecordModel> _filteredBreaches = [];
//   bool _isLoading = false;
//
//   // Severity Stats for the Header Card
//   int totalSerious = 0;
//   int totalModerate = 0;
//   int totalMinor = 0;
//
//   // Getters
//   List<BreachRecordModel> get breaches => _filteredBreaches;
//   bool get isLoading => _isLoading;
//
//   /// Fetch all breach records for a specific case
//   Future<void> fetchBreaches(String caseId) async {
//     final String? userId = _auth.currentUser?.uid;
//
//     if (userId == null) {
//       debugPrint("BreachProvider Error: No authenticated user found.");
//       return;
//     }
//
//     _isLoading = true;
//     _allBreaches = [];
//     _filteredBreaches = [];
//     _resetTotals();
//     notifyListeners();
//
//     try {
//       final snapshot = await _db
//           .collection('users')
//           .doc(userId)
//           .collection('cases')
//           .doc(caseId)
//           .collection('breachRecords')
//           .orderBy('date', descending: true)
//           .get();
//
//       _allBreaches = snapshot.docs.map((doc) {
//         return BreachRecordModel.fromMap(doc.data(), doc.id);
//       }).toList();
//
//       _filteredBreaches = List.from(_allBreaches);
//       _calculateSeverityTotals(_filteredBreaches);
//
//     } catch (e) {
//       debugPrint("Error fetching breach records: $e");
//       _allBreaches = [];
//       _filteredBreaches = [];
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Filters the list based on type, name, or severity
//   void filterBreaches(String query) {
//     if (query.isEmpty) {
//       _filteredBreaches = List.from(_allBreaches);
//     } else {
//       final q = query.toLowerCase();
//       _filteredBreaches = _allBreaches.where((b) {
//         final typeMatch = b.type.toLowerCase().contains(q);
//         final nameMatch = b.name.toLowerCase().contains(q);
//         final severityMatch = b.severity.toLowerCase().contains(q);
//         final partyMatch = b.party.toLowerCase().contains(q);
//
//         return typeMatch || nameMatch || severityMatch || partyMatch;
//       }).toList();
//     }
//
//     // Update the header stats based on what is currently on screen
//     _calculateSeverityTotals(_filteredBreaches);
//     notifyListeners();
//   }
//
//   /// Calculates totals for the summary card
//   void _calculateSeverityTotals(List<BreachRecordModel> list) {
//     _resetTotals();
//     for (var b in list) {
//       // Logic handles "Significant" as "Moderate" based on your preference
//       if (b.severity == "Serious") {
//         totalSerious++;
//       } else if (b.severity == "Moderate" || b.severity == "Significant") {
//         totalModerate++;
//       } else if (b.severity == "Minor") {
//         totalMinor++;
//       }
//     }
//   }
//
//   void _resetTotals() {
//     totalSerious = 0;
//     totalModerate = 0;
//     totalMinor = 0;
//   }
//
//   /// Clears the search filter
//   void clearSearch() {
//     _filteredBreaches = List.from(_allBreaches);
//     _calculateSeverityTotals(_filteredBreaches);
//     notifyListeners();
//   }
// }



class BreachProviderInsight with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'clearcase',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // MASTER LIST: Always holds every record from Firestore
  List<BreachRecordModel> _allBreaches = [];
  // DISPLAY LIST: What the UI actually shows
  List<BreachRecordModel> _filteredBreaches = [];

  bool _isLoading = false;
  String _currentSearchQuery = "";

  // DEFAULT FILTERS: Resets on every fetch
  FilterOptions _currentFilters = FilterOptions(
    selectedTimePeriod: "All Time",
    selectedCategory: "All Severities(Combined)",
  );

  // Severity Stats for the Header Card
  int totalSerious = 0;
  int totalModerate = 0;
  int totalMinor = 0;

  // Getters
  List<BreachRecordModel> get breaches => _filteredBreaches;
  bool get isLoading => _isLoading;

  /// Fetch all breach records for a specific case
  /// Fetch all breach records for a specific case
  Future<void> fetchBreaches(String caseId) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _isLoading = true;

    // --- FIXED: Use the exact string "All Severities(Combined)" ---
    _currentSearchQuery = "";
    _currentFilters = FilterOptions(
      selectedTimePeriod: "All Time",
      selectedCategory: "All Severities(Combined)", // Match this everywhere
    );

    _resetTotals();
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('users').doc(userId)
          .collection('cases').doc(caseId)
          .collection('breachRecords')
          .orderBy('date', descending: true)
          .get();

      _allBreaches = snapshot.docs.map((doc) {
        return BreachRecordModel.fromMap(doc.data(), doc.id);
      }).toList();

      _runCombinedFilters();
    } catch (e) {
      debugPrint("Error fetching breach records: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// THE ENGINE
  void _runCombinedFilters() {
    List<BreachRecordModel> results = List.from(_allBreaches);

    results = results.where((breach) {
      // 1. Severity Filter
      bool matchesSeverity = true;

      // IMPROVED LOGIC: Only filter if the category isn't "All" or the "Combined" string
      if (_currentFilters.selectedCategory != "All Severities(Combined)" &&
          _currentFilters.selectedCategory != "All") {
        matchesSeverity = breach.severity == _currentFilters.selectedCategory;
      }

      // 2. Time Filter
      bool matchesTime = _checkTimePeriod(breach.date, _currentFilters.selectedTimePeriod);

      return matchesSeverity && matchesTime;
    }).toList();

    // 3. Search Query
    if (_currentSearchQuery.isNotEmpty) {
      final q = _currentSearchQuery.toLowerCase();
      results = results.where((b) {
        return b.type.toLowerCase().contains(q) ||
            b.name.toLowerCase().contains(q) ||
            b.party.toLowerCase().contains(q);
      }).toList();
    }

    _filteredBreaches = results;
    _calculateSeverityTotals(_filteredBreaches);
    notifyListeners();
  }

  bool _checkTimePeriod(DateTime? date, String period) {
    if (date == null || period == "All Time") return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case "Last month":
        return date.isAfter(today.subtract(const Duration(days: 30)));
      case "Quarter":
        return date.isAfter(today.subtract(const Duration(days: 90)));
      case "Bi-annual":
        return date.isAfter(today.subtract(const Duration(days: 182)));
      case "Yearly":
        return date.isAfter(today.subtract(const Duration(days: 365)));
      case "Current Financial year":
      // FY starts April 1st
        int startYear = now.month >= 4 ? now.year : now.year - 1;
        DateTime fyStart = DateTime(startYear, 4, 1);
        return date.isAfter(fyStart) || date.isAtSameMomentAs(fyStart);
      default:
        return true;
    }
  }

  void filterBySearch(String query) {
    _currentSearchQuery = query;
    _runCombinedFilters();
  }

  void applyAdvancedFilters(FilterOptions options) {
    _currentFilters = options;
    _runCombinedFilters();
  }

  void clearAll() {
    _currentSearchQuery = "";
    _currentFilters = FilterOptions(
        selectedTimePeriod: "All Time",
        selectedCategory: "All Severities(Combined)"
    );
    _runCombinedFilters();
  }

  void _calculateSeverityTotals(List<BreachRecordModel> list) {
    _resetTotals();
    for (var b in list) {
      if (b.severity == "Serious") totalSerious++;
      else if (b.severity == "Moderate") totalModerate++;
      else if (b.severity == "Minor") totalMinor++;
    }
  }

  void _resetTotals() {
    totalSerious = 0; totalModerate = 0; totalMinor = 0;
  }
}