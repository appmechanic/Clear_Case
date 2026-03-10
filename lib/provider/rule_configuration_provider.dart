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
  String repeatFrequency = "Weekly";
  bool isEnabled = true;

  final TextEditingController notesController = TextEditingController();
  final FocusNode notesNode = FocusNode();

  // Unified list for both Add and Edit modes
  List<Map<String, dynamic>> _appliedChildrenList = [];
  List<Map<String, dynamic>> get appliedChildrenList => _appliedChildrenList;


  void init(String? caseId, String category, List<ChildModel> available) {
    reset();
    if (caseId != null) {
      fetchExistingData(caseId, category);
    } else {
      _appliedChildrenList = available.map((child) => child.toMap()).toList();
      notifyListeners();
    }
  }

  Future<void> fetchExistingData(String caseId, String category) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Pointing to the new 'scheduledRules' collection
      final doc = await _firestore
          .collection('users').doc(_auth.currentUser!.uid)
          .collection('cases').doc(caseId)
          .collection('scheduledRules')
          .doc(category.toLowerCase()) // Doc ID is the category name
          .get();

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

  // --- Unified Child Management ---



  void addChild(String name, DateTime dob, String? caseId, String category) async {
    final newChild = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'dob': Timestamp.fromDate(dob),
    };
    _appliedChildrenList.add(newChild);
    notifyListeners();
    if (caseId != null) await _syncChildrenToDb(caseId, category);
  }

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

  // --- Setters & Form Logic ---

  void updateStartDate(DateTime date) { startDate = date; notifyListeners(); }
  void updateEndDate(DateTime date) { endDate = date; notifyListeners(); }
  void updateStartTime(TimeOfDay time) { startTime = time; notifyListeners(); }
  void updateEndTime(TimeOfDay time) { endTime = time; notifyListeners(); }
  void toggleRepeat(bool val) { isRepeat = val; notifyListeners(); }
  void setFrequency(String freq) { repeatFrequency = freq; notifyListeners(); }
  void setNotification(String val) { notificationPref = val; notifyListeners(); }
  void toggleEnabled(bool val) { isEnabled = val; notifyListeners(); }


  Future<bool> updateRuleInFirestore({
    required String? caseId,
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

      // Set with merge: true handles both creating new and updating existing
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


  /// Returns null if valid, or an error message string if invalid
  String? validateDates() {
    if (startDate == null || startTime == null) return "Please set a Start Date and Time.";

    // If end is not set, it's valid (one-time occurrence or indefinite)
    if (endDate == null || endTime == null) return null;

    final startDateTime = DateTime(
      startDate!.year, startDate!.month, startDate!.day,
      startTime!.hour, startTime!.minute,
    );

    final endDateTime = DateTime(
      endDate!.year, endDate!.month, endDate!.day,
      endTime!.hour, endTime!.minute,
    );

    if (endDateTime.isAtSameMomentAs(startDateTime)) {
      return "End time cannot be the same as Start time.";
    }
    if (endDateTime.isBefore(startDateTime)) {
      return "End time cannot be before Start time.";
    }

    return null; // All good
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
    notesController.clear();
    _appliedChildrenList = [];
    _isLoading = false;
  }
}