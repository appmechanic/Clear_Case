import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/attachments.dart';
import '../core/utils/child_names.dart';

class NonComplianceRecordModel {
  String id;
  String name;
  String type;
  String party; // e.g., "Mother", "Father"
  String severity; // "Minor", "Significant", "Serious"
  String description;
  String proof; // shown as "Evidence"
  // Children the record is about. Empty on records created before child
  // selection existed — those apply to every child.
  List<String> childIds;
  DateTime? date;
  List<String>? attachments;
  bool flagEntry;

  NonComplianceRecordModel({
    required this.id,
    required this.name,
    required this.type,
    required this.party,
    required this.severity,
    required this.description,
    required this.proof,
    this.childIds = const [],
    this.date,
    this.attachments,
    this.flagEntry = false,
  });

  factory NonComplianceRecordModel.fromMap(Map<String, dynamic> map, String documentId) {
    return NonComplianceRecordModel(
      id: documentId,
      name: map['name'] ?? '',
      type: map['type'] ?? 'General Violation',
      party: map['party'] ?? 'Unknown',
      severity: map['severity'] ?? 'Minor',
      description: map['description'] ?? '',
      proof: map['proof'] ?? '',
      childIds: readChildIds(map),
      flagEntry: map['flagEntry'] ?? false,
      attachments: readAttachmentUrls(map),
      date: (map['date'] as Timestamp?)?.toDate(),
    );
  }
}
