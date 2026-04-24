import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType { custody, payment, dispute, breach, reminder }

class CalendarEvent {
  String id;
  final String title;
  final DateTime date;
  final EventType type;
  final String? description;
  final double? amount;
  final List<String> childNames;
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
  final bool isFulfilled;
  final bool isScheduled;
  final bool isReceived;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.description,
    this.amount,
    this.childNames = const [],
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
    this.isFulfilled = false,
    this.isScheduled = false,
    this.isReceived = false,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> map, {String? docId}) {
    String origin = map['originCollection'] ?? '';

    EventType detectedType;
    if (origin.contains('custody') || map.containsKey('isFulfilled')) {
      detectedType = EventType.custody;
    } else if (origin.contains('payment') || map.containsKey('paymentCategory')) {
      detectedType = EventType.payment;
    } else if (origin.contains('dispute') || map.containsKey('issue')) {
      detectedType = EventType.dispute;
    } else if (origin.contains('breach') || map.containsKey('severity')) {
      detectedType = EventType.breach;
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
      isFlagged: map['flagEntry'] == true,
      attachmentUrls: List<String>.from(map['attachmentUrls'] ?? []),
      location: map['location'],
      party: map['party'],
      paymentCategory: map['paymentCategory'],
      category: map['category'],
      status: map['transactionType'],
      paymentMethod: map['paymentMethod'],
      transactionType: map['transactionType'],
      proof: map['proof'],
      severity: map['severity'],
       isFulfilled: (map['isFulfilled'] == true),
      isScheduled: (map['isScheduled'] == true),
      isReceived: (map['isReceived'] == true),
    );
  }

  static EventType _parseEventType(dynamic type) {
    String typeStr = type.toString().toLowerCase();
    if (typeStr.contains('custody')) return EventType.custody;
    if (typeStr.contains('payment')) return EventType.payment;
    if (typeStr.contains('dispute')) return EventType.dispute;
    if (typeStr.contains('breach')) return EventType.breach;
    return EventType.reminder;
  }
}