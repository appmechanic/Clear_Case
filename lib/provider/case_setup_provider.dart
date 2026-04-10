
import 'package:clearcase/models/case_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class CaseSetupProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentStep = 1;
  int get currentStep => _currentStep;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Case Data
  final CaseModel _caseData = CaseModel(
    userId: '', 
    createdAt: DateTime.now(),
    children: [] 
  );
  CaseModel get caseData => _caseData;

  // Step 2 Selection
  String? _selectedRuleType;
  String? get selectedRuleType => _selectedRuleType;

  // Step 3 Data (Holds the raw map of the rule config)
  Map<String, dynamic>? _configuredRuleData;

  // --- NAVIGATION ---
  void nextStep() {
    if (_currentStep < 3) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 1) {
      _currentStep--;
      notifyListeners();
    }
  }

  // --- STEP 1: LOGIC ---
  void updateCaseInfo(String number, String rep) {
    _caseData.caseNumber = number;
    _caseData.legalRep = rep;
    notifyListeners();
  }

  void addChild(String name, DateTime dob) {
    _caseData.children.add(ChildModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      dob: dob,
    ));
    notifyListeners();
  }

  void removeChild(String id) {
    _caseData.children.removeWhere((element) => element.id == id);
    notifyListeners();
  }

  // --- STEP 2: LOGIC ---
  void selectRuleType(String type) {
    _selectedRuleType = type;
    notifyListeners();
  }

  // --- STEP 3: LOGIC ---
  void setRuleConfiguration(Map<String, dynamic> data) {
    _configuredRuleData = data;
    
    // We only set the Boolean Flags here. 
    // The actual data map will be saved to a sub-collection in submitCase()
    if (_selectedRuleType == 'Custody') {
      _caseData.isCustodyRuleSet = true;
    } else if (_selectedRuleType == 'Payment') {
      _caseData.isPaymentRuleSet = true;
    } else if (_selectedRuleType == 'Custom') {
       // Assuming CustomRuleSet flag exists or logic handles it
       // _caseData.isCustomRuleSet = true; 
    }
    notifyListeners();
  }

  // --- SUBMIT (Updated Storage Paths) ---
  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  Future<void> submitCase(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isSubmitting = true;
    notifyListeners();

    try {
      _caseData.userId = user.uid;
      _caseData.createdAt = DateTime.now();

      // 1. Prepare Main Case Data
      Map<String, dynamic> mainCaseData = _caseData.toMap();
      mainCaseData.remove('custodyRule');
      mainCaseData.remove('paymentRule');
      mainCaseData.remove('customRule');

      WriteBatch batch = _firestore.batch();

      // 2. Create Case Document Reference
      DocumentReference caseRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc();

      batch.set(caseRef, mainCaseData);
      _caseData.id = caseRef.id;

      // 3. NEW LOGIC: Save ALL Rules to a dedicated 'scheduledRules' sub-collection
      if (_configuredRuleData != null && _selectedRuleType != null) {
        // Use the lower-case category as the ID (e.g., 'custody', 'payment', 'custom')
        // This ensures only one rule per category exists per case.
        DocumentReference ruleRef = caseRef
            .collection('scheduledRules')
            .doc(_selectedRuleType!.toLowerCase());

        Map<String, dynamic> rulePayload = Map.from(_configuredRuleData!);
        rulePayload['createdAt'] = FieldValue.serverTimestamp();
        rulePayload['category'] = _selectedRuleType; // Store the readable category name

        batch.set(ruleRef, rulePayload);
      }

      // 4. Save Children
      List<Map<String, dynamic>> childrenList = _caseData.children.map((c) => c.toMap()).toList();
      DocumentReference userRef = _firestore.collection('users').doc(user.uid);

      batch.set(
          userRef,
          {'children': FieldValue.arrayUnion(childrenList)},
          SetOptions(merge: true)
      );

      await batch.commit();

      _isSubmitting = false;
      notifyListeners();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: 0);
      }
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
 }