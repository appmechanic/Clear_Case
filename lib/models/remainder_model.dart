import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  String? id;
  String caseId;
  DateTime date;
  String title;
  String type;
  bool isRepeat; // Replaced repeatOption String
  String? days;
  DateTime? ruleEndDate;
  String description;
  String remindMeOption;
  DateTime? createdAt;

  ReminderModel({
    this.id,
    required this.caseId,
    required this.date,
    required this.title,
    required this.type,
    required this.isRepeat,
    this.days,
    this.ruleEndDate,
    required this.description,
    required this.remindMeOption,
     this.createdAt,
  });

  ReminderModel copyWith({
    String? id,
    String? caseId,
    DateTime? date,
    String? title,
    String? type,
    bool? isRepeat,
    String? days,
    DateTime? ruleEndDate,
    String? description,
    String? remindMeOption,
    bool? enableNotifications,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      date: date ?? this.date,
      title: title ?? this.title,
      type: type ?? this.type,
      isRepeat: isRepeat ?? this.isRepeat,
      days: days ?? this.days,
      ruleEndDate: ruleEndDate ?? this.ruleEndDate,
      description: description ?? this.description,
      remindMeOption: remindMeOption ?? this.remindMeOption,
       createdAt: createdAt ?? this.createdAt,
    );
  }
  factory ReminderModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReminderModel(
      id: docId,
      caseId: map['caseId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      isRepeat: map['isRepeat'] ?? false, // Defaulting to false
      days: map['days'],
      ruleEndDate: (map['ruleEndDate'] as Timestamp?)?.toDate(),
      description: map['description'] ?? '',
      remindMeOption: map['remindMeOption'] ?? '' ,
       createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'caseId': caseId,
      'date': Timestamp.fromDate(date),
      'title': title,
      'type': type,
      'isRepeat': isRepeat, // Storing as boolean
      'days': days,
      'ruleEndDate': ruleEndDate != null ? Timestamp.fromDate(ruleEndDate!) : null,
      'description': description,
      'remindMeOption': remindMeOption,
     };

    // Only add createdAt if it's a new record
    if (createdAt != null) {
      data['createdAt'] = Timestamp.fromDate(createdAt!);
    } else if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    return data;
  }
}