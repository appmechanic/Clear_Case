import 'package:cloud_firestore/cloud_firestore.dart';

class CustodyRecordModel {
  String? id;
  String? caseId;
  List<String>? childIds;
  DateTime? startDate;
  DateTime? startTime;
  DateTime? endTime;
  bool? isScheduled;
  String? location;
  bool? isFulfilled;
  String? notes;
  bool? flagEntry;
  DateTime? createdAt;
  List<String>? attachmentUrls; // Added field for multiple files

  CustodyRecordModel({
    this.id,
    this.caseId,
    this.childIds,
    this.startDate,
    this.startTime,
    this.endTime,
    this.isScheduled,
    this.location,
    this.isFulfilled,
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
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isScheduled': isScheduled,
      'location': location,
      'isFulfilled': isFulfilled,
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
      startTime: (map['startTime'] as Timestamp?)?.toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      isScheduled: map['isScheduled'] as bool?,
      location: map['location'] as String?,
      isFulfilled: map['isFulfilled'] as bool?,
      notes: map['notes'] as String?,
      flagEntry: map['flagEntry'] as bool?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      attachmentUrls: map['attachmentUrls'] != null ? List<String>.from(map['attachmentUrls']) : null,
    );
  }}
