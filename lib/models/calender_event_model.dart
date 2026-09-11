import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/attachments.dart';
import '../core/utils/custody_span.dart';

enum EventType { custody, payment, dispute, nonCompliance, reminder }

class CalendarEvent {
  String id;
  final String title;
  final DateTime date;
  final EventType type;
  final String? description;
  final double? amount;
  final List<String> childNames;
  final List<String> childIds;
  final bool isFlagged;
  final List<String> attachmentUrls;
  final String? location;
  final String? party;
  final String? paymentCategory;
  final String? category;
  final String? status;
  final String? paymentMethod;
  final String? transactionType;
  final String? proof;
  final String? severity;
  final bool isReceived;
  // Custody only: last day the entry covers (null = single day), and the
  // handover times on the first and last day.
  final DateTime? endDate;
  final DateTime? startTime;
  final DateTime? endTime;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.description,
    this.amount,
    this.childNames = const [],
    this.childIds = const [],
    this.isFlagged = false,
    this.attachmentUrls = const [],
    this.location,
    this.party,
    this.paymentCategory,
    this.category,
    this.status,
    this.paymentMethod,
    this.transactionType,
    this.proof,
    this.severity,
    this.isReceived = false,
    this.endDate,
    this.startTime,
    this.endTime,
  });

  /// Days covered by a custody entry; a single day for every other type.
  CustodySpan get span => CustodySpan(date, endDate ?? date);

  bool get isScheduledRule => id.startsWith("rule_");

  factory CalendarEvent.fromMap(Map<String, dynamic> map, {String? docId}) {
    String origin = map['originCollection'] ?? '';

    EventType detectedType;
    // 'isFulfilled' only identifies custody docs written before the toggle was
    // removed; newer ones rely on originCollection.
    if (origin.contains('custody') || map.containsKey('isFulfilled')) {
      detectedType = EventType.custody;
    } else if (origin.contains('payment') || map.containsKey('paymentCategory')) {
      detectedType = EventType.payment;
    } else if (origin.contains('dispute') || map.containsKey('issue')) {
      detectedType = EventType.dispute;
    } else if (origin.toLowerCase().contains('noncompliance') || map.containsKey('severity')) {
      detectedType = EventType.nonCompliance;
    } else {
      detectedType = _parseEventType(map['type'] ?? origin);
    }

    return CalendarEvent(
      id: docId ?? map['id'] ?? '',
      title: map['title'] ?? map['paymentType'] ?? map['issue'] ?? 'Record',
       date: (map['startDate'] as Timestamp?)?.toDate() ??
          (map['date'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      type: detectedType,
      description: map['notes'] ?? map['description'],
      amount: (map['amount'] as num?)?.toDouble(),
      childNames: List<String>.from(map['childNames'] ?? []),
      childIds: List<String>.from(map['childIds'] ?? []),
      isFlagged: map['flagEntry'] == true,
      attachmentUrls: readAttachmentUrls(map),
      location: map['location'],
      party: map['party'],
      paymentCategory: map['paymentCategory'],
      category: map['category'],
      status: map['transactionType'],
      paymentMethod: map['paymentMethod'],
      transactionType: map['transactionType'],
      proof: map['proof'],
      severity: map['severity'],
      isReceived: (map['isReceived'] == true),
      endDate: detectedType == EventType.custody ? _timestamp(map['endDate']) : null,
      startTime: _timestamp(map['startTime']),
      endTime: _timestamp(map['endTime']),
    );
  }

  static DateTime? _timestamp(dynamic value) => value is Timestamp ? value.toDate() : null;

  static EventType _parseEventType(dynamic type) {
    String typeStr = type.toString().toLowerCase();
    if (typeStr.contains('custody')) return EventType.custody;
    if (typeStr.contains('payment')) return EventType.payment;
    if (typeStr.contains('dispute')) return EventType.dispute;
    if (typeStr.contains('noncompliance') || typeStr.contains('non-compliance')) return EventType.nonCompliance;
    return EventType.reminder;
  }
}
