import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:clearcase/models/case_model.dart';



class RuleConfigurationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'clearcase');
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
  String repeatFrequency = "Weekly";
  bool isEnabled = true;

  final TextEditingController notesController = TextEditingController();
  final FocusNode notesNode = FocusNode();

  // --- Children Logic ---
  // List of maps containing: 'id' (string), 'name' (string), 'dob' (Timestamp)
  List<Map<String, dynamic>> _appliedChildrenList = [];
  List<Map<String, dynamic>> get appliedChildrenList => _appliedChildrenList;

  void init(String? recordId, String? caseId, String category, List<ChildModel> available) {
    reset();
    if (recordId != null) {
      fetchExistingData(recordId, caseId!, category);
    } else {
      // Default for new records: use the children passed from the previous screen
      _appliedChildrenList = available.map((child) => child.toMap()).toList();
      notifyListeners();
    }
  }

  Future<void> fetchExistingData(String recordId, String caseId, String category) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(caseId)
          .collection('${category}Records').doc(recordId).get();

      if (doc.exists) {
        final data = doc.data()!;
        startDate = DateTime.tryParse(data['startDate'] ?? "");
        endDate = DateTime.tryParse(data['endDate'] ?? "");
        if (data['startTime'] != null) startTime = _parseTime(data['startTime']);
        if (data['endTime'] != null) endTime = _parseTime(data['endTime']);

        isRepeat = data['isRepeat'] ?? true;
        repeatFrequency = data['frequency'] ?? "Weekly";
        notificationPref = data['notificationPref'] ?? "On the Scheduled day";
        notesController.text = data['notes'] ?? "";
        isEnabled = data['isEnabled'] ?? true;

        // Fetch the appliedChildren array directly from Firestore
        final List<dynamic> applied = data['appliedChildren'] ?? [];
        _appliedChildrenList = List<Map<String, dynamic>>.from(applied);
      }
    } catch (e) {
      debugPrint("Provider Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Child Management Logic ---

  /// Adds a child locally with a unique ID and Firestore-compatible Timestamp
  void addChild(String name, DateTime dob) {
    _appliedChildrenList.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'dob': Timestamp.fromDate(dob), // Store as Timestamp for Firestore consistency
    });
    notifyListeners();
  }

  /// Removes a child from the list based on index
  void removeChild(int index) {
    if (index >= 0 && index < _appliedChildrenList.length) {
      _appliedChildrenList.removeAt(index);
      notifyListeners();
    }
  }

  // --- UI State Setters ---

  void updateStartDate(DateTime date) { startDate = date; notifyListeners(); }
  void updateEndDate(DateTime date) { endDate = date; notifyListeners(); }
  void updateStartTime(TimeOfDay time) { startTime = time; notifyListeners(); }
  void updateEndTime(TimeOfDay time) { endTime = time; notifyListeners(); }
  void toggleRepeat(bool val) { isRepeat = val; notifyListeners(); }
  void setFrequency(String freq) { repeatFrequency = freq; notifyListeners(); }
  void setNotification(String val) { notificationPref = val; notifyListeners(); }
  void toggleEnabled(bool val) { isEnabled = val; notifyListeners(); }

  // --- Firestore Update Sync ---

  Future<bool> updateRuleInFirestore({
    required String? caseId,
    required String? recordId,
    required String category
  }) async {
    if (caseId == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> data = {
        "startDate": startDate?.toIso8601String(),
        "startTime": startTime != null ? "${startTime!.hour}:${startTime!.minute}" : null,
        "isRepeat": isRepeat,
        "frequency": isRepeat ? repeatFrequency : "One-time",
        "endDate": endDate?.toIso8601String(),
        "endTime": endTime != null ? "${endTime!.hour}:${endTime!.minute}" : null,
        "notificationPref": notificationPref,
        "notes": notesController.text.trim(),
        "isEnabled": isEnabled,
        "appliedChildren": _appliedChildrenList,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      final collectionRef = _firestore
          .collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(caseId)
          .collection('${category}Records');

      if (recordId != null) {
        // EDIT MODE
        await collectionRef.doc(recordId).update(data);
      } else {
        // ADD MODE
        await collectionRef.add(data);
      }

      return true;
    } catch (e) {
      debugPrint("Save Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add to RuleConfigurationProvider

  void toggleChildSelection(ChildModel child) {
    final index = _appliedChildrenList.indexWhere((c) => c['id'] == child.id);
    if (index != -1) {
      _appliedChildrenList.removeAt(index);
    } else {
      _appliedChildrenList.add(child.toMap());
    }
    notifyListeners();
  }

  void selectAllChildren(List<ChildModel> available) {
    _appliedChildrenList = available.map((c) => c.toMap()).toList();
    notifyListeners();
  }

  void clearAllChildren() {
    _appliedChildrenList = [];
    notifyListeners();
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
    repeatFrequency = "Weekly";
    isEnabled = true;
    notesController.clear(); // Important to clear the text controller
    _appliedChildrenList = [];
    _isLoading = false;
  }
}