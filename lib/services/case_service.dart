import 'package:flutter/material.dart';

// --- MODELS ---
class ChildModel {
  String id;
  String name;
  DateTime dob;
  
  ChildModel({required this.id, required this.name, required this.dob});
}

class CaseModel {
  String? caseNumber;
  String? legalRep;
  List<ChildModel> children = [];
  String? selectedRuleType; // "Custody", "Payments", "Custom"
  
  // Schedule Data
  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;
  String repeatFrequency; // "Weekly", "Fortnightly", "Monthly"
  List<String> appliedChildIds = []; // IDs of children this rule applies to

  CaseModel({
    this.repeatFrequency = "Weekly",
  });
}

// --- SERVICE ---
class CaseService {
  Future<void> createCase(CaseModel caseData) async {
    // Simulate API call or Firebase Firestore write
    await Future.delayed(const Duration(seconds: 2));
    print("Case Created: ${caseData.caseNumber} with ${caseData.children.length} children");
  }
}