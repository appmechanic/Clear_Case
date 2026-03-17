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
  final List<String> attachmentUrls; // Added for storage cleanup

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.description,
    this.amount,
    this.childNames = const [],
    this.isFlagged = false,
    this.attachmentUrls = const [], // Default to empty list
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> map, {String? docId}) {
    return CalendarEvent(
      id: docId ?? map['id'] ?? '',
      title: map['title'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: _parseEventType(map['type']),
      description: map['description'] ?? map['notes'],
      amount: (map['amount'] as num?)?.toDouble(),
      childNames: List<String>.from(map['childNames'] ?? []),
      isFlagged: map['flagEntry'] ?? false,
      attachmentUrls: List<String>.from(map['attachmentUrls'] ?? []), // Added
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'description': description,
      'amount': amount,
      'childNames': childNames,
      'flagEntry': isFlagged,
      'attachmentUrls': attachmentUrls, // Added
    };
  }

  static EventType _parseEventType(dynamic type) {
    return EventType.values.firstWhere(
          (e) => e.name == type.toString(),
      orElse: () => EventType.dispute,
    );
  }
}