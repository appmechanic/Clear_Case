import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/breach_model.dart'; // Ensure this path is correct

class BreachProviderInsight with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'clearcase',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<BreachRecordModel> _allBreaches = [];
  List<BreachRecordModel> _filteredBreaches = [];
  bool _isLoading = false;

  // Severity Stats for the Header Card
  int totalSerious = 0;
  int totalModerate = 0;
  int totalMinor = 0;

  // Getters
  List<BreachRecordModel> get breaches => _filteredBreaches;
  bool get isLoading => _isLoading;

  /// Fetch all breach records for a specific case
  Future<void> fetchBreaches(String caseId) async {
    final String? userId = _auth.currentUser?.uid;

    if (userId == null) {
      debugPrint("BreachProvider Error: No authenticated user found.");
      return;
    }

    _isLoading = true;
    _allBreaches = [];
    _filteredBreaches = [];
    _resetTotals();
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('cases')
          .doc(caseId)
          .collection('breachRecords')
          .orderBy('date', descending: true)
          .get();

      _allBreaches = snapshot.docs.map((doc) {
        return BreachRecordModel.fromMap(doc.data(), doc.id);
      }).toList();

      _filteredBreaches = List.from(_allBreaches);
      _calculateSeverityTotals(_filteredBreaches);

    } catch (e) {
      debugPrint("Error fetching breach records: $e");
      _allBreaches = [];
      _filteredBreaches = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filters the list based on type, name, or severity
  void filterBreaches(String query) {
    if (query.isEmpty) {
      _filteredBreaches = List.from(_allBreaches);
    } else {
      final q = query.toLowerCase();
      _filteredBreaches = _allBreaches.where((b) {
        final typeMatch = b.type.toLowerCase().contains(q);
        final nameMatch = b.name.toLowerCase().contains(q);
        final severityMatch = b.severity.toLowerCase().contains(q);
        final partyMatch = b.party.toLowerCase().contains(q);

        return typeMatch || nameMatch || severityMatch || partyMatch;
      }).toList();
    }

    // Update the header stats based on what is currently on screen
    _calculateSeverityTotals(_filteredBreaches);
    notifyListeners();
  }

  /// Calculates totals for the summary card
  void _calculateSeverityTotals(List<BreachRecordModel> list) {
    _resetTotals();
    for (var b in list) {
      // Logic handles "Significant" as "Moderate" based on your preference
      if (b.severity == "Serious") {
        totalSerious++;
      } else if (b.severity == "Moderate" || b.severity == "Significant") {
        totalModerate++;
      } else if (b.severity == "Minor") {
        totalMinor++;
      }
    }
  }

  void _resetTotals() {
    totalSerious = 0;
    totalModerate = 0;
    totalMinor = 0;
  }

  /// Clears the search filter
  void clearSearch() {
    _filteredBreaches = List.from(_allBreaches);
    _calculateSeverityTotals(_filteredBreaches);
    notifyListeners();
  }
}