import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/filter_model.dart'; // Ensure this matches your project structure

class CustodyInsightProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'clearcase',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  bool _isLoading = false;

  // Filter State
  String _currentSearchQuery = "";
  FilterOptions _currentFilters = FilterOptions(
    selectedTimePeriod: "All Time",
    selectedCategory: "All Records", // Categories: "Fulfilled", "Unfulfilled", "All Records"
  );

  // Stats for Header Card
  int fulfilledCount = 0;
  int unfulfilledCount = 0;
  int justifiedCount = 0; // If you have a 'justified' field in DB later
  double complianceRate = 0.0;

  List<Map<String, dynamic>> get records => _filteredRecords;
  bool get isLoading => _isLoading;

  Future<void> fetchCustodyRecords(String caseId) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _isLoading = true;

    // RESET filters on every fetch (Case switch/App start)
    _currentSearchQuery = "";
    _currentFilters = FilterOptions(
      selectedTimePeriod: "All Time",
      selectedCategory: "All Records",
      selectedChildIds: [],
    );

    notifyListeners();

    try {
      final snapshot = await _db
          .collection('users').doc(userId)
          .collection('cases').doc(caseId)
          .collection('custodyRecords')
          .orderBy('startDate', descending: true)
          .get();

      _allRecords = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _runCombinedFilters();
    } catch (e) {
      debugPrint("Error fetching custody: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _runCombinedFilters() {
    List<Map<String, dynamic>> results = List.from(_allRecords);

    results = results.where((record) {
      // 1. Child Filter
      final List<dynamic> childIds = record['childIds'] ?? [];
      bool matchesChild = _currentFilters.selectedChildIds.isEmpty ||
          childIds.any((id) => _currentFilters.selectedChildIds.contains(id.toString()));

      // 2. Custody Type Filter (Scheduled, Non-Scheduled, All)
      bool matchesType = true;
      final bool isScheduled = record['isScheduled'] ?? false;
      if (_currentFilters.selectedCategory == "Scheduled") {
        matchesType = isScheduled == true;
      } else if (_currentFilters.selectedCategory == "Non-Scheduled") {
        matchesType = isScheduled == false;
      }

      // 3. Time Filter
      final DateTime? date = (record['startDate'] as Timestamp?)?.toDate();
      bool matchesTime = _checkTimePeriod(date, _currentFilters.selectedTimePeriod);

      return matchesChild && matchesType && matchesTime;
    }).toList();

    // 4. Search Query (Search notes only - removed location)
    if (_currentSearchQuery.isNotEmpty) {
      final q = _currentSearchQuery.toLowerCase();
      results = results.where((r) => (r['notes'] ?? "").toString().toLowerCase().contains(q)).toList();
    }

    _filteredRecords = results;
    _calculateStats(_filteredRecords);
    notifyListeners();
  }

    void _calculateStats(List<Map<String, dynamic>> list) {
    fulfilledCount = list.where((r) => r['isFulfilled'] == true).length;
    unfulfilledCount = list.where((r) => r['isFulfilled'] == false).length;

    if (list.isNotEmpty) {
      complianceRate = (fulfilledCount / list.length) * 100;
    } else {
      complianceRate = 0.0;
    }
  }

  bool _checkTimePeriod(DateTime? date, String period) {
    if (date == null || period == "All Time") return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case "Last month": return date.isAfter(today.subtract(const Duration(days: 30)));
      case "Quarter": return date.isAfter(today.subtract(const Duration(days: 90)));
      case "Bi-annual": return date.isAfter(today.subtract(const Duration(days: 182)));
      case "Yearly": return date.isAfter(today.subtract(const Duration(days: 365)));
      default: return true;
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
}