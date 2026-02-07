enum EventType { custody, payment, dispute, breach }

class CalendarEvent {
  final String id;
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
}