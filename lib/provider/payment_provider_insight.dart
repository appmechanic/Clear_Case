import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../models/filter_model.dart';
import '../models/payment_model.dart';


class PaymentProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'clearcase',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // MASTER LIST: Always holds every record from Firestore
  List<PaymentRecordModel> _masterPayments = [];

  // DISPLAY LIST: What the UI actually shows (Filtered & Searched)
  List<PaymentRecordModel> _filteredPayments = [];

  bool _isLoading = false;
  String _currentSearchQuery = "";
  FilterOptions _currentFilters = FilterOptions(
      selectedTimePeriod: "All Time",
      selectedCategory: "All Payments(Combined)"
  );

  // Getters
  List<PaymentRecordModel> get payments => _filteredPayments;
  bool get isLoading => _isLoading;

  Future<void> fetchPaymentsByCase(String caseId) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _isLoading = true;

    // RESET state for the new session/case
    _currentSearchQuery = "";
    _currentFilters = FilterOptions(
        selectedTimePeriod: "All Time",
        selectedCategory: "All Payments(Combined)",
        selectedChildIds: [] // Ensures "Select All" behavior
    );

    notifyListeners();

    try {
      final snapshot = await _db
          .collection('users').doc(userId)
          .collection('cases').doc(caseId)
          .collection('paymentRecords')
          .orderBy('date', descending: true)
          .get();

      _masterPayments = snapshot.docs.map((doc) {
        return PaymentRecordModel.fromMap(doc.data(), doc.id);
      }).toList();

      _runCombinedFilters();
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// THE ENGINE: Combines Search and Advanced Filters
  void _runCombinedFilters() {
    List<PaymentRecordModel> results = List.from(_masterPayments);

    // 1. Apply Advanced Filters
    results = results.where((payment) {
      // Child Filter
      bool matchesChild = _currentFilters.selectedChildIds.isEmpty ||
          (payment.childIds?.any((id) => _currentFilters.selectedChildIds.contains(id)) ?? false);

      // Category Filter (Received/Paid)
      bool matchesCategory = true;
      if (_currentFilters.selectedCategory == "Payment Received") {
        matchesCategory = payment.transactionType == "PaymentReceived";
      } else if (_currentFilters.selectedCategory == "Payment Paid") {
        matchesCategory = payment.transactionType == "PaymentPaid";
      }

      // Time Filter
      bool matchesTime = _checkTimePeriod(payment.date, _currentFilters.selectedTimePeriod);

      return matchesChild && matchesCategory && matchesTime;
    }).toList();

    // 2. Apply Search Query
    if (_currentSearchQuery.isNotEmpty) {
      final query = _currentSearchQuery.toLowerCase();
      results = results.where((record) {
        return (record.paymentType ?? "").toLowerCase().contains(query) ||
            (record.paymentMethod ?? "").toLowerCase().contains(query) ||
            record.amount.toString().contains(query);
      }).toList();
    }

    _filteredPayments = results;
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
        selectedCategory: "All Payments(Combined)"
    );
    _runCombinedFilters();
  }

  String getChildNamesFromIds(List<String>? ids, CaseModel? selectedCase) {
    if (ids == null || ids.isEmpty || selectedCase == null) return "N/A";
    try {
      List<String> names = [];
      for (var id in ids) {
        final matchingChildren = selectedCase.children.where((child) => child.id == id);
        if (matchingChildren.isNotEmpty) {
          names.add(matchingChildren.first.name);
        }
      }
      return names.isEmpty ? "Unknown Child" : names.join(", ");
    } catch (e) {
      return "Child";
    }
  }
}