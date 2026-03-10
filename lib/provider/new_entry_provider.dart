import 'dart:io';

import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/custody_model.dart';
import 'package:clearcase/models/payment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Helper method to upload file and get URL
  Future<String?> uploadAttachment(File file, String category) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // Path: users/{uid}/{category}/timestamp_filename
      String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
      Reference ref = _storage.ref().child('users/${user.uid}/$category/$fileName');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Storage Error: $e");
      return null;
    }
  }

  // --- SAVE CUSTODY RECORD (Updated with Flag Logic) ---
  Future<void> addCustodyRecord(
      BuildContext context,
      CustodyRecordModel record,
      List<File> imageFiles, // Accepting List<File>
      ) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a case")));
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Upload all files to Firebase Storage
      List<String> downloadUrls = [];

      for (File file in imageFiles) {
        final String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
        final Reference storageRef = _storage
            .ref()
            .child('users/${user.uid}/cases/${_selectedCase!.id}/custody_attachments/$fileName');

        final UploadTask uploadTask = storageRef.putFile(file);
        final TaskSnapshot snapshot = await uploadTask;

        String url = await snapshot.ref.getDownloadURL();
        downloadUrls.add(url);
      }

      // 2. Prepare the data map with the list of URLs
      Map<String, dynamic> recordData = record.toMap();
      // Save the list of strings (URLs)
      recordData['attachmentUrls'] = downloadUrls;

      WriteBatch batch = _firestore.batch();

      // 3. Main Record Reference
      DocumentReference custodyRef = _firestore
          .collection('users').doc(user.uid)
          .collection('cases').doc(_selectedCase!.id)
          .collection('custodyRecords').doc();

      batch.set(custodyRef, recordData);

      // 4. Handle Flagged Event (Include the same list of URLs)
      if (record.flagEntry == true) {
        DocumentReference flaggedRef = _firestore
            .collection('users').doc(user.uid)
            .collection('flaggedEvents').doc();

        Map<String, dynamic> flaggedData = Map.from(recordData);
        flaggedData['originCollection'] = 'custodyRecords';
        flaggedData['originId'] = custodyRef.id;

        batch.set(flaggedRef, flaggedData);
      }

      // 5. Commit
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving record: $e")));
      }
    }
  }
  Future<void> addPaymentRecord(
      BuildContext context,
      PaymentRecordModel record,
      List<File> imageFiles // Add this parameter
      ) async {
    final user = _auth.currentUser;
    if (user == null || _selectedCase == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Upload Attachments
      List<String> downloadUrls = [];
      for (File file in imageFiles) {
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
        Reference ref = _storage.ref().child('users/${user.uid}/cases/${_selectedCase!.id}/payment_attachments/$fileName');
        TaskSnapshot snapshot = await ref.putFile(file);
        downloadUrls.add(await snapshot.ref.getDownloadURL());
      }

      // 2. Add URLs to Map
      Map<String, dynamic> recordData = record.toMap();
      recordData['attachmentUrls'] = downloadUrls;

      WriteBatch batch = _firestore.batch();
      DocumentReference paymentRef = _firestore
          .collection('users').doc(user.uid)
          .collection('cases').doc(_selectedCase!.id)
          .collection('paymentRecords').doc();

      batch.set(paymentRef, recordData);

      // 3. Flagging logic
      if (record.flagEntry == true) {
        DocumentReference flaggedRef = _firestore.collection('users').doc(user.uid).collection('flaggedEvents').doc();
        Map<String, dynamic> flaggedData = Map.from(recordData);
        flaggedData['originCollection'] = 'paymentRecords';
        flaggedData['originId'] = paymentRef.id;
        batch.set(flaggedRef, flaggedData);
      }

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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }}
