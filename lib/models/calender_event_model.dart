import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType { custody, payment, dispute, breach }

class CalendarEvent {
  String id; // Changed to non-final so we can set it from Doc ID
  final String title;
  final DateTime date;
  final EventType type;
  final String? description;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.description,
  });

  // --- FROM MAP (Reading from Firebase) ---
  factory CalendarEvent.fromMap(Map<String, dynamic> map, {String? docId}) {
    return CalendarEvent(
      id: docId ?? map['id'] ?? '',
      title: map['title'] ?? '',
      // Handles Firestore Timestamp to DateTime conversion
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // Safely converts String to Enum
      type: _parseEventType(map['type']),
      description: map['description'],
    );
  }

  // --- TO MAP (Saving to Firebase) ---
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'type': type.name, // Saves enum as "custody", "payment", etc.
      'description': description,
    };
  }

  // Helper to safely parse the enum
  static EventType _parseEventType(dynamic type) {
    return EventType.values.firstWhere(
          (e) => e.name == type.toString(),
      orElse: () => EventType.dispute, // Fallback type
    );
  }
}