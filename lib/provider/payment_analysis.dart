import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../models/payment_model.dart';

class PaymentProvider with ChangeNotifier {
  // Using your specific named instance and auth
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'clearcase',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<PaymentRecordModel> _payments = [];
  List<PaymentRecordModel> _filteredPayments = [];
  bool _isLoading = false;

  double totalPaid = 0;
  double totalReceived = 0;
  double totalCompulsory = 0;
  double totalAdditional = 0;

  List<PaymentRecordModel> get payments => _filteredPayments;
  bool get isLoading => _isLoading;

  double get totalVolume => totalPaid + totalReceived + totalCompulsory + totalAdditional;

  Future<void> fetchPaymentsByCase(String caseId) async {
    // Dynamically get UID from your _auth instance
    final String? userId = _auth.currentUser?.uid;

    if (userId == null) {
      debugPrint("Error: No authenticated user found.");
      return;
    }

    _isLoading = true;
    _payments = [];
    _resetTotals();
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('cases')
          .doc(caseId)
          .collection('paymentRecords')
          .orderBy('date', descending: true)
          .get();

      _payments = snapshot.docs.map((doc) {
        return PaymentRecordModel.fromMap(doc.data(), doc.id);
      }).toList();

      _filteredPayments = List.from(_payments);
      _calculateTotals();
    } catch (e) {
      debugPrint("Error fetching payments from 'clearcase' DB: $e");
      _payments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateTotals() {
    _resetTotals();
    for (var record in _payments) {
      double amount = record.amount ?? 0;

      if (record.transactionType == "PaymentReceived") {
        totalReceived += amount;
      } else if (record.transactionType == "PaymentPaid") {
        totalPaid += amount;
      }

      if (record.paymentCategory == "Compulsory") {
        totalCompulsory += amount;
      } else if (record.paymentCategory == "Additional") {
        totalAdditional += amount;
      }
    }
  }

  void _resetTotals() {
    totalPaid = 0;
    totalReceived = 0;
    totalCompulsory = 0;
    totalAdditional = 0;
  }

  // Change dynamic to CaseModel? to access the children list properly
  String getChildNamesFromIds(List<String>? ids, CaseModel? selectedCase) {
    if (ids == null || ids.isEmpty || selectedCase == null) return "N/A";

    try {
      List<String> names = [];

      for (var id in ids) {
        // Use .where to find matching IDs in the ChildModel list
        final matchingChildren = selectedCase.children.where((child) => child.id == id);

        if (matchingChildren.isNotEmpty) {
          names.add(matchingChildren.first.name);
        }
      }

      // If we found names, join them (e.g., "Job, Priya")
      return names.isEmpty ? "Unknown Child" : names.join(", ");
    } catch (e) {
      debugPrint("Error mapping child names: $e");
      return "Child";
    }
  }
  void filterPayments(String query) {
    if (query.isEmpty) {
      _filteredPayments = List.from(_payments);
    } else {
      final lowercaseQuery = query.toLowerCase();
      _filteredPayments = _payments.where((record) {
        final title = (record.paymentType ?? "").toLowerCase();
        final method = (record.paymentMethod ?? "").toLowerCase();
        final amount = (record.amount?.toString() ?? "");

        // Search across Title, Method, and Amount
        return title.contains(lowercaseQuery) ||
            method.contains(lowercaseQuery) ||
            amount.contains(lowercaseQuery);
      }).toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _filteredPayments = List.from(_payments);
    notifyListeners();
  }

}