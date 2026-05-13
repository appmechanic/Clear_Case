import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/attachments.dart';

class BreachRecordModel {
  String id;
  String name;
  String type;
  String party; // e.g., "Mother", "Father"
  String severity; // "Minor", "Significant", "Serious"
  String description;
  String proof;
  DateTime? date;
  List<String>? attachments;
  bool flagEntry;

  BreachRecordModel({
    required this.id,
    required this.name,
    required this.type,
    required this.party,
    required this.severity,
    required this.description,
    required this.proof,
    this.date,
    this.attachments,
    this.flagEntry = false,
  });

  factory BreachRecordModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BreachRecordModel(
      id: documentId,
      name: map['name'] ?? '',
      type: map['type'] ?? 'General Violation',
      party: map['party'] ?? 'Unknown',
      severity: map['severity'] ?? 'Minor',
      description: map['description'] ?? '',
      proof: map['proof'] ?? '',
      flagEntry: map['flagEntry'] ?? false,
      attachments: readAttachmentUrls(map),
      date: (map['date'] as Timestamp?)?.toDate(),
    );
  }
}