import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  String? id; // Make nullable
  String caseId;
  DateTime date;
  String title;
  String type;
  String repeatOption;
  String? days;
  DateTime? ruleEndDate;
  String description;
  String remindMeOption;
  bool enableNotifications;
  DateTime? createdAt; // Make nullable

  ReminderModel({
    this.id,
    required this.caseId,
    required this.date,
    required this.title,
    required this.type,
    required this.repeatOption,
    this.days,
    this.ruleEndDate,
    required this.description,
    required this.remindMeOption,
    required this.enableNotifications,
    this.createdAt,
  });

  factory ReminderModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReminderModel(
      id: docId,
      caseId: map['caseId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      repeatOption: map['repeatOption'] ?? 'None',
      days: map['days'],
      ruleEndDate: (map['ruleEndDate'] as Timestamp?)?.toDate(),
      description: map['description'] ?? '',
      remindMeOption: map['remindMeOption'] ?? '',
      enableNotifications: map['enableNotifications'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'date': Timestamp.fromDate(date),
      'title': title,
      'type': type,
      'repeatOption': repeatOption,
      'days': days,
      'ruleEndDate': ruleEndDate != null ? Timestamp.fromDate(ruleEndDate!) : null,
      'description': description,
      'remindMeOption': remindMeOption,
      'enableNotifications': enableNotifications,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}