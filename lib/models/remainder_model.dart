import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  String id;
  String caseId; // Links to specific case
  DateTime date;
  String title;
  String type;
  String repeatOption;
  String? days; // For custom interval
  DateTime? ruleEndDate;
  String description;
  String remindMeOption;
  bool enableNotifications;
  DateTime createdAt;

  ReminderModel({
    this.id = '',
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
    required this.createdAt,
  });

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
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}