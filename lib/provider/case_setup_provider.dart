
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

  // Case Data. Not final — loadExistingCase() replaces it when the screen is
  // opened for an existing case.
  CaseModel _caseData = CaseModel(
    userId: '',
    createdAt: DateTime.now(),
    children: []
  );
  CaseModel get caseData => _caseData;

  // Non-null when editing an existing case. Drives submitCase's update-vs-create
  // branch — without it, saving an edit creates a duplicate case.
  String? _editingCaseId;
  bool get isEditing => _editingCaseId != null;

  // Existing scheduledRules docs, keyed by lower-cased category, so a wizard
  // re-run edits the current rule instead of overwriting it from blank.
  Map<String, Map<String, dynamic>> _existingRules = {};
  Map<String, dynamic>? existingRuleFor(String category) =>
      _existingRules[category.toLowerCase()];

  // False only while an edit-mode rule load is in flight. Starts true so the
  // create flow — which never loads rules — is never gated on anything; it is
  // flipped false by loadExistingCase when we actually enter edit mode, and back
  // to true by loadExistingRules on every exit path (success, empty, failure).
  //
  // Step 3 seeds its form once in initState from existingRuleFor(). If it were
  // allowed to build while this is false, it would seed blank and a save would
  // then fully overwrite the case's real rule (submitCase writes the rule with
  // batch.set and no merge). The screen must not render Step 3 until this is
  // true.
  bool _rulesLoaded = true;
  bool get rulesLoaded => _rulesLoaded;

  void _markRulesLoaded() {
    _rulesLoaded = true;
  }

  // True only when an edit-mode rule load actually THREW (set in
  // loadExistingRules' catch, cleared on every attempt and on success).
  //
  // A failed load and a case that legitimately has no rules both leave
  // _existingRules empty, so without this flag Step 3 cannot tell them apart and
  // renders a blank form either way. That is fine for the "no rules yet" case,
  // but catastrophic for the failure case: submitCase writes the rule with
  // batch.set and NO merge, so saving the blank form fully overwrites the case's
  // real, court-order-derived rule. Step 3 must surface this and block saving.
  //
  // Always false in the create flow — nothing is ever loaded there.
  bool _rulesLoadFailed = false;
  bool get rulesLoadFailed => _rulesLoadFailed;

  /// Re-attempts the edit-mode rule load after a failure. No-op outside edit
  /// mode so the create flow can never be gated on it.
  Future<void> retryLoadExistingRules() async {
    final id = _editingCaseId;
    if (id == null) return;
    _rulesLoaded = false;
    _rulesLoadFailed = false;
    notifyListeners();
    await loadExistingRules(id);
  }

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

  void addChild(String name, DateTime dob, {String? school, String? address}) {
    _caseData.children.add(ChildModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      dob: dob,
      school: school,
      address: address,
    ));
    notifyListeners();
  }

  /// Edits a child in place. The id is deliberately preserved: it is referenced
  /// by the PDF export filter (options.childIds), by event.childIds, and by the
  /// scheduledRules docs' appliedChildren. Delete-and-re-add would mint a new id
  /// (addChild uses millisecondsSinceEpoch) and silently break all three.
  void updateChild(
    String id, {
    required String name,
    required DateTime dob,
    String? school,
    String? address,
  }) {
    final index = _caseData.children.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final child = _caseData.children[index];
    child.name = name;
    child.dob = dob;
    child.school = school;
    child.address = address;
    notifyListeners();
  }

  void removeChild(String id) {
    _caseData.children.removeWhere((element) => element.id == id);
    notifyListeners();
  }

  // --- EDIT MODE ---

  void loadExistingCase(CaseModel c) {
    // DEEP COPY — DO NOT "optimize" this into `_caseData = c`.
    // Callers hand us the LIVE CaseModel instance that CalendarProvider (and the
    // other list providers) still hold in their own collections. CaseModel and
    // ChildModel are mutable, and the wizard mutates _caseData in place on every
    // keystroke (updateCaseInfo) and on every addChild/removeChild. Aliasing the
    // caller's object would push those unsaved edits straight into the calendar's
    // dropdown — a phantom child, a deleted child, or a half-typed case number
    // would appear as if saved, and survive until an unrelated snapshot or an app
    // restart. Round-tripping through toMap()/fromMap() also rebuilds the
    // children list with fresh ChildModel instances, so nothing is shared.
    // toMap() deliberately omits 'id' (it is the Firestore doc id, not a field),
    // so fromMap yields id: '' and we must re-attach it explicitly.
    _caseData = CaseModel.fromMap(c.toMap())..id = c.id;
    // CaseModel.toMap() never persists 'id', so CaseModel.fromMap(doc.data())
    // always yields id: ''. Callers are expected to patch c.id = doc.id after
    // fromMap (see setting_provider.dart, calender_provider.dart,
    // insight_provider.dart, scheduled_dates_provider.dart), but if a caller
    // ever forgets, we must not treat a blank id as a valid editing target —
    // isEditing would become true and submitCase would call casesCol.doc(''),
    // which throws. Only enter edit mode when we actually have an id.
    _editingCaseId = c.id.trim().isEmpty ? null : c.id;
    // Entering edit mode means a rule load is expected: gate Step 3 until
    // loadExistingRules reports back. A blank id leaves us in create mode, where
    // there are no rules to wait for, so the flag stays true.
    if (_editingCaseId != null) {
      _rulesLoaded = false;
      _rulesLoadFailed = false;
    }
    notifyListeners();
  }

  Future<void> loadExistingRules(String caseId) async {
    final user = _auth.currentUser;
    if (user == null) {
      // No user means no load will ever happen — don't strand Step 3 behind a
      // spinner waiting for a result that isn't coming.
      _markRulesLoaded();
      notifyListeners();
      return;
    }
    _rulesLoadFailed = false;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(caseId)
          .collection('scheduledRules')
          .get();
      _existingRules = {
        for (final doc in snap.docs) doc.id: doc.data(),
      };
      // In edit mode, pre-select the existing rule's type so Step 2 shows it as
      // chosen and Step 3 seeds from it — otherwise both look blank until the
      // user re-picks the type. A case can hold several rule docs (one per
      // category); the wizard edits one at a time, so default to the first and
      // leave the rest untouched (submitCase only writes the selected type).
      if (isEditing && _selectedRuleType == null && _existingRules.isNotEmpty) {
        final entry = _existingRules.entries.first;
        final category = entry.value['category'];
        if (category is String && category.trim().isNotEmpty) {
          _selectedRuleType = category;
        } else if (entry.key.isNotEmpty) {
          // Rule docs written elsewhere may lack the readable `category` field;
          // derive it from the doc id ('custody' -> 'Custody').
          _selectedRuleType = entry.key[0].toUpperCase() + entry.key.substring(1);
        }
      }
      // A completed-but-empty collection IS loaded — the case simply has no
      // rules yet, and Step 3 should proceed to its blank defaults.
      _markRulesLoaded();
      notifyListeners();
    } catch (e) {
      debugPrint('loadExistingRules failed: $e');
      // Don't leave stale rules from a previously-loaded case sitting around —
      // the form could otherwise prefill from the wrong case's data.
      _existingRules = {};
      // Record that this emptiness is a FAILURE, not "no rules yet". Step 3 keys
      // off this to show an error and disable saving instead of presenting a
      // blank form whose save would clobber the case's real rule.
      _rulesLoadFailed = true;
      // A failed load is still a finished load — release the gate so the user
      // gets the error rather than an inescapable spinner.
      _markRulesLoaded();
      notifyListeners();
    }
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
      // Only stamp createdAt when creating. On an edit this would silently reset
      // the case's real creation date, since mainCaseData carries it into the
      // merge below.
      if (!isEditing) {
        _caseData.createdAt = DateTime.now();
      }

      // 1. Prepare Main Case Data
      Map<String, dynamic> mainCaseData = _caseData.toMap();
      mainCaseData.remove('custodyRule');
      mainCaseData.remove('paymentRule');
      mainCaseData.remove('customRule');

      WriteBatch batch = _firestore.batch();

      // 2. Case Document Reference — .doc() with no argument mints a NEW doc,
      // so editing must pass the existing id or every save duplicates the case.
      final casesCol = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases');
      DocumentReference caseRef =
          isEditing ? casesCol.doc(_editingCaseId) : casesCol.doc();

      if (isEditing) {
        batch.set(caseRef, mainCaseData, SetOptions(merge: true));
      } else {
        batch.set(caseRef, mainCaseData);
      }
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

      await batch.commit();

      _isSubmitting = false;
      notifyListeners();

      if (context.mounted) {
        if (isEditing) {
          Navigator.pop(context);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: 0);
        }
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