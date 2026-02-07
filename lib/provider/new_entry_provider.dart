import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/custody_model.dart';
import 'package:clearcase/models/payment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class NewEntryProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(), 
    databaseId: 'clearcase'
  );

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<CaseModel> _userCases = [];
  List<CaseModel> get userCases => _userCases;

  CaseModel? _selectedCase;
  CaseModel? get selectedCase => _selectedCase;

  void init() {
    _fetchUserCases();
  }

  Future<void> _fetchUserCases() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cases')
            .orderBy('createdAt', descending: true)
            .get();

        _userCases = snapshot.docs.map((doc) {
          CaseModel c = CaseModel.fromMap(doc.data() as Map<String, dynamic>);
          c.id = doc.id;
          return c;
        }).toList();

        if (_userCases.isNotEmpty) _selectedCase = _userCases.first;
        notifyListeners();
      } catch (e) {
        debugPrint("Error fetching cases: $e");
      }
    }
  }

  void selectCase(CaseModel? newCase) {
    _selectedCase = newCase;
    notifyListeners();
  }

  // --- SAVE CUSTODY RECORD (Updated with Flag Logic) ---
  Future<void> addCustodyRecord(BuildContext context, CustodyRecordModel record) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a case")));
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      WriteBatch batch = _firestore.batch();

      // 1. Reference for Standard Custody Record
      // Path: users/{uid}/cases/{caseId}/custody_records/{newId}
      DocumentReference custodyRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases ')
          .doc(_selectedCase!.id)
          .collection('custodyRecords')
          .doc(); // Auto-ID

      batch.set(custodyRef, record.toMap());

      // 2. CHECK FLAG: Reference for Flagged Events
      // Path: users/{uid}/flagged_events/{newId}
      if (record.flagEntry == true) {
        DocumentReference flaggedRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('flaggedEvents')
            .doc(); // Auto-ID

        // Add extra metadata to identify origin
        Map<String, dynamic> flaggedData = record.toMap();
        flaggedData['originCollection'] = 'custodyRecords';
        flaggedData['originId'] = custodyRef.id; // Link back to original
        
        batch.set(flaggedRef, flaggedData);
      }

      // Commit both writes
      await batch.commit();

      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Custody record saved!")));
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> addPaymentRecord(BuildContext context, PaymentRecordModel record) async {
    final user = _auth.currentUser;
    // Basic Validation
    if (user == null) return;
    if (_selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a case")));
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      WriteBatch batch = _firestore.batch();

      // 1. Reference for Standard Payment Record
      // Path: users/{uid}/cases/{caseId}/paymentRecords/{newId}
      DocumentReference paymentRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(_selectedCase!.id)
          .collection('paymentRecords') 
          .doc(); // Auto-ID

      batch.set(paymentRef, record.toMap());

      // 2. CHECK FLAG: Reference for Flagged Events
      if (record.flagEntry == true) {
        DocumentReference flaggedRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('flaggedEvents')
            .doc(); 

        // Add extra metadata to identify origin
        Map<String, dynamic> flaggedData = record.toMap();
        flaggedData['originCollection'] = 'paymentRecords';
        flaggedData['originId'] = paymentRef.id; // Link back to original
        
        batch.set(flaggedRef, flaggedData);
      }

      // Commit both writes
      await batch.commit();

      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment record saved!")));
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}