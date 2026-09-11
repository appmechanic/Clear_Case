import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/utils/custody_span.dart';
import '../core/utils/timeframe.dart';
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
  FilterOptions _currentFilters = FilterOptions();

  // Stats for Header Card — what the filtered entries actually cover.
  int totalNights = 0;
  int totalEntries = 0;

  StreamSubscription<User?>? _authSubscription;
  String? _currentUid;

  CustodyInsightProvider() {
    _currentUid = _auth.currentUser?.uid;
    // Clear cached custody records when the signed-in user changes, so a
    // fresh login never sees the previous account's data.
    _authSubscription = _auth.authStateChanges().listen(_handleAuthChanged);
  }

  void _handleAuthChanged(User? user) {
    if (_currentUid == user?.uid) return;
    _currentUid = user?.uid;
    _allRecords = [];
    _filteredRecords = [];
    _currentSearchQuery = "";
    _currentFilters = FilterOptions();
    totalNights = 0;
    totalEntries = 0;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get records => _filteredRecords;
  bool get isLoading => _isLoading;
  FilterOptions get currentFilters => _currentFilters;

  /// Loads a case's custody entries. Filters reset on every fetch (case
  /// switch / screen open) to [timePeriod] — the Insights screen's timeframe.
  Future<void> fetchCustodyRecords(String caseId, {String timePeriod = Timeframe.defaultOption}) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _isLoading = true;

    // RESET filters on every fetch (Case switch/App start)
    _currentSearchQuery = "";
    _currentFilters = FilterOptions(selectedTimePeriod: timePeriod);

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
    final window = Timeframe.windowFor(_currentFilters.selectedTimePeriod);
    List<Map<String, dynamic>> results = List.from(_allRecords);

    // 1. Apply Sidebar/Advanced Filters First
    results = results.where((record) {
      // Child Filter
      final List<dynamic> childIds = record['childIds'] ?? [];
      bool matchesChild = _currentFilters.selectedChildIds.isEmpty ||
          childIds.any((id) => _currentFilters.selectedChildIds.contains(id.toString()));

      // Time Filter — a multi-day entry counts when any of its days fall in
      // the period.
      final span = CustodySpan.fromMap(record);
      bool matchesTime = span == null || window.overlaps(span.start, span.end);

      return matchesChild && matchesTime;
    }).toList();

    // 2. Search Query (Notes + Location)
    if (_currentSearchQuery.isNotEmpty) {
      final q = _currentSearchQuery.toLowerCase().trim();
      results = results.where((r) {
        final String notes = (r['notes'] ?? "").toString().toLowerCase();
        final String location = (r['location'] ?? "").toString().toLowerCase();
        return notes.contains(q) || location.contains(q);
      }).toList();
    }

    _filteredRecords = results;
    final totals = CustodyTotals.from(
      _filteredRecords.map(CustodySpan.fromMap).whereType<CustodySpan>(),
      window,
    );
    totalNights = totals.nights;
    totalEntries = totals.entries;
    notifyListeners();
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
