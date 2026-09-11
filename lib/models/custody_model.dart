import 'package:cloud_firestore/cloud_firestore.dart';

class CustodyRecordModel {
  String? id;
  String? caseId;
  List<String>? childIds;
  // First and last calendar day the entry covers (date-only). Records saved
  // before multi-day custody have no endDate and cover only startDate.
  DateTime? startDate;
  DateTime? endDate;
  DateTime? startTime;
  DateTime? endTime;
  String? location;
  String? notes;
  bool? flagEntry;
  DateTime? createdAt;
  List<String>? attachmentUrls; // Added field for multiple files

  CustodyRecordModel({
    this.id,
    this.caseId,
    this.childIds,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.location,
    this.notes,
    this.flagEntry,
    this.createdAt,
    this.attachmentUrls,
  });

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'childIds': childIds,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'location': location,
      'notes': notes,
      'flagEntry': flagEntry,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'attachmentUrls': attachmentUrls, // Added to map
    };
  }

// Make documentId optional with [] or {}
  factory CustodyRecordModel.fromMap(Map<String, dynamic> map, [String? documentId]) {
    return CustodyRecordModel(
      id: documentId ?? map['id'], // Use the passed ID or look for one in the map
      caseId: map['caseId'] as String?,
      childIds: map['childIds'] != null ? List<String>.from(map['childIds']) : null,
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      startTime: (map['startTime'] as Timestamp?)?.toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      flagEntry: map['flagEntry'] as bool?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      attachmentUrls: map['attachmentUrls'] != null ? List<String>.from(map['attachmentUrls']) : null,
    );
  }}
