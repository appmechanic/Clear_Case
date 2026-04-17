import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:clearcase/models/case_model.dart';

class RuleConfigurationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Form State
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String notificationPref = "On the Scheduled day";
  bool isRepeat = true;
  // bool isEnabled = true;
   bool hasEndDate = false;

  final TextEditingController notesController = TextEditingController();
  final FocusNode notesNode = FocusNode();

  // --- NEW: Tracking selection state ---
  Set<String> selectedChildIds = {};

  // Unified list for both Add and Edit modes
  List<Map<String, dynamic>> _appliedChildrenList = [];
  List<Map<String, dynamic>> get appliedChildrenList => _appliedChildrenList;

  String selectedFrequency = "Weekly";
  final List<String> frequencyOptions = ["Weekly", "Fortnightly", "Monthly"];

  void init(String? caseId, String category, List<ChildModel> available) {
    reset();
    _masterAvailableChildren = available; // Store the original list


    isRepeat = true;
    hasEndDate = false;

    if (caseId != null) {
      fetchExistingData(caseId, category);
    } else {

      _appliedChildrenList = available.map((child) => child.toMap()).toList();
      selectedChildIds = available.map((child) => child.id).toSet();
    }
    notifyListeners();
  }

  Future<void> fetchExistingData(String caseId, String category) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(caseId)
          .collection('scheduledRules')
          .doc(category.toLowerCase())
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        startDate = DateTime.tryParse(data['startDate'] ?? "");

        // LOGIC: If repeatFrequency is null or empty, it's not a repeating rule
        String? freq = data['repeatFrequency'];
        isRepeat = (freq != null && freq.isNotEmpty && freq != "None");
        selectedFrequency = freq ?? "Weekly";

        // LOGIC: If there is an endDate in DB, hasEndDate should be TRUE
        endDate = DateTime.tryParse(data['endDate'] ?? "");
        hasEndDate = (endDate != null);

        if (data['startTime'] != null) startTime = _parseTime(data['startTime']);
        if (data['endTime'] != null) endTime = _parseTime(data['endTime']);

        notificationPref = data['notificationPref'] ?? "On the Scheduled day";
        notesController.text = data['notes'] ?? "";

        // Sync Children
        final List<dynamic> applied = data['appliedChildren'] ?? [];
        _appliedChildrenList = List<Map<String, dynamic>>.from(applied);
        final Set<String> originalIds = _masterAvailableChildren.map((c) => c.id).toSet();
        _addedChildrenOnly = _appliedChildrenList
            .where((child) => !originalIds.contains(child['id'].toString()))
            .toList();
        selectedChildIds = _appliedChildrenList.map((c) => c['id'].toString()).toSet();
      }
    } catch (e) {
      debugPrint("Provider Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  void toggleHasEndDate(bool val) {
    hasEndDate = val;
    if (!val) {
      endDate = null;
      endTime = null;
    }
    notifyListeners();
  }


  void setFrequency(String val) {
    selectedFrequency = val;
    notifyListeners();
  }

  // --- NEW: Radio/Toggle Selection Logic ---

  void toggleChildSelection(String childId) {
    if (selectedChildIds.contains(childId)) {
      selectedChildIds.remove(childId);
    } else {
      selectedChildIds.add(childId);
    }
    notifyListeners();
  }



  void selectAllChildren(List<ChildModel> allAvailable) {
    selectedChildIds = allAvailable.map((c) => c.id).toSet();
    notifyListeners();
  }

  void clearSelectedChildren() {
    selectedChildIds.clear();
    notifyListeners();
  }

  // --- Keep Existing Child Management ---

  void addChild(String name, DateTime dob, String? caseId, String category) async {
    final newChild = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'dob': Timestamp.fromDate(dob),
    };
    // 1. Add to the list the UI is watching
    _addedChildrenOnly.add(newChild);

    // 2. ALSO add to the list that gets saved to Firestore
    _appliedChildrenList.add(newChild);

    // 3. Automatically select it
    selectedChildIds.add(newChild['id'] as String);

    notifyListeners();

    // Note: Only sync to DB if the case already exists
    if (caseId != null) _syncChildrenToDb(caseId, category);
  }

  // NOTE: We keep this for internal logic,
  // but your UI won't show the delete button anymore.
  void removeChild(int index, String? caseId, String category) async {
    if (index >= 0 && index < _appliedChildrenList.length) {
      _appliedChildrenList.removeAt(index);
      notifyListeners();
      if (caseId != null) await _syncChildrenToDb(caseId, category);
    }
  }

  Future<void> _syncChildrenToDb(String caseId, String category) async {
    try {
      await _firestore
          .collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(caseId)
          .collection('scheduledRules')
          .doc(category.toLowerCase())
          .update({
        "appliedChildren": _appliedChildrenList,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  // --- Existing Setters ---
  void updateStartDate(DateTime date) { startDate = date; notifyListeners(); }
  void updateEndDate(DateTime date) { endDate = date; notifyListeners(); }
  void updateStartTime(TimeOfDay time) { startTime = time; notifyListeners(); }
  void updateEndTime(TimeOfDay time) { endTime = time; notifyListeners(); }
  void toggleRepeat(bool val) {
    isRepeat = val;
    // Optional: If turning off repeat, you might want to clear End Date/Time?
    if (!val) {
      endDate = null;
      endTime = null;
    }
    notifyListeners();
  }
   void setNotification(String val) { notificationPref = val; notifyListeners(); }
  // void toggleEnabled(bool val) { isEnabled = val; notifyListeners(); }


  // Add this getter
  List<Map<String, dynamic>> get allChildrenOptions {
    // 1. Start with children passed from the case (converted to Map)
    // You need to pass the initial 'available' list to the provider during init
    return _masterAvailableChildren.map((c) => c.toMap()).toList()
      ..addAll(_addedChildrenOnly);
  }

// Add these tracking variables to your Provider class
  List<ChildModel> _masterAvailableChildren = [];
  List<Map<String, dynamic>> _addedChildrenOnly = [];

  void selectAllChildrenFromMap(List<Map<String, dynamic>> allChildrenMap) {
    selectedChildIds = allChildrenMap.map((c) => c['id'].toString()).toSet();
    notifyListeners();
  }


  Future<bool> updateRuleInFirestore({required String? caseId, required String category}) async {
    if (caseId == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. RECONCILE: Ensure allChildrenOptions (the UI list) are included in the applied list
      // This merges the original master list and the newly added children
      final currentMasterList = allChildrenOptions;

      // 2. FILTER: Now filter the combined list based on what the user actually selected
      _appliedChildrenList = currentMasterList
          .where((c) => selectedChildIds.contains(c['id'].toString()))
          .toList();

      final Map<String, dynamic> data = {
        "category": category,
        "startDate": startDate?.toIso8601String(),
        "startTime": startTime != null ? "${startTime!.hour}:${startTime!.minute}" : null,
         "repeatFrequency": isRepeat ? selectedFrequency : null,
        "endDate": (!isRepeat || (isRepeat && hasEndDate)) ? endDate?.toIso8601String() : null,
        "endTime": (!isRepeat || (isRepeat && hasEndDate)) && endTime != null
            ? "${endTime!.hour}:${endTime!.minute}" : null,
        "hasEndDate": hasEndDate,
        "notificationPref": notificationPref,
        "notes": notesController.text.trim(),
         "appliedChildren": _appliedChildrenList, // Now contains selected children
        "updatedAt": FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(caseId)
          .collection('scheduledRules')
          .doc(category.toLowerCase())
          .set(data, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint("Save Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  void dispose() {
    notesController.dispose();
    notesNode.dispose();
    super.dispose();
  }

  void reset() {
    startDate = null;
    endDate = null;
    startTime = null;
    endTime = null;
    notificationPref = "On the Scheduled day";
    isRepeat = true;
    // isEnabled = true;
    hasEndDate = false;
    notesController.clear();

    selectedFrequency = "Weekly";
    _appliedChildrenList = [];
    _addedChildrenOnly = [];
    _masterAvailableChildren = [];
    selectedChildIds = {};
    _isLoading = false;
  }
}