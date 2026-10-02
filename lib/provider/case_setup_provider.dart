
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/remainder_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Case setup wizard. Creating a case: Step 1 (case, related party,
/// children) → Step 2 (optional repeated reminders). Editing a case: Step 1
/// only — its reminders are managed from the Reminders screen.
class CaseSetupProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentStep = 1;
  int get currentStep => _currentStep;
  int get stepCount => isEditing ? 1 : 2;

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

  // Step 2: repeated reminders set up during onboarding, saved with the case.
  final List<ReminderModel> _reminderDrafts = [];
  List<ReminderModel> get reminderDrafts => List.unmodifiable(_reminderDrafts);

  // --- NAVIGATION ---
  void nextStep() {
    if (_currentStep < stepCount) {
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

  /// Blank values clear the related party.
  void updateRelatedParty({String? relation, String? name}) {
    _caseData.relatedPartyRelation = (relation ?? '').trim().isEmpty ? null : relation!.trim();
    _caseData.relatedPartyName = (name ?? '').trim().isEmpty ? null : name!.trim();
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
    notifyListeners();
  }

  // --- STEP 2: LOGIC ---

  void addReminderDraft(ReminderModel draft) {
    _reminderDrafts.add(draft);
    notifyListeners();
  }

  void replaceReminderDraft(int index, ReminderModel draft) {
    if (index < 0 || index >= _reminderDrafts.length) return;
    _reminderDrafts[index] = draft;
    notifyListeners();
  }

  void removeReminderDraft(int index) {
    if (index < 0 || index >= _reminderDrafts.length) return;
    _reminderDrafts.removeAt(index);
    notifyListeners();
  }

  // --- SUBMIT ---
  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  /// Saves the case and, unless [skipReminders], the reminder drafts.
  Future<void> submitCase(BuildContext context, {bool skipReminders = false}) async {
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

      // 3. Reminders set up in Step 2.
      if (!skipReminders) {
        for (final draft in _reminderDrafts) {
          batch.set(
            caseRef.collection('reminders').doc(),
            draft.copyWith(caseId: caseRef.id).toMap(),
          );
        }
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
