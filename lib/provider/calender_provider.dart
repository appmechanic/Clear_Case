import 'package:clearcase/models/calender_event_model.dart';
import 'package:flutter/material.dart';

class CalendarProvider extends ChangeNotifier {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Map to store events: Date -> List of Events
  final Map<DateTime, List<CalendarEvent>> _events = {};

  CalendarProvider() {
    _selectedDay = _focusedDay;
    _loadMockEvents();
  }

  DateTime get focusedDay => _focusedDay;
  DateTime? get selectedDay => _selectedDay;

  List<CalendarEvent> getEventsForDay(DateTime day) {
    // Normalize date to remove time part for map lookup
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _events[normalizedDate] ?? [];
  }

  void onDaySelected(DateTime selected, DateTime focused) {
    if (!isSameDay(_selectedDay, selected)) {
      _selectedDay = selected;
      _focusedDay = focused;
      notifyListeners();
    }
  }

  void onPageChanged(DateTime focused) {
    _focusedDay = focused;
    notifyListeners();
  }

  // Helper to normalize dates
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _loadMockEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Mock Data based on your screenshots
    _events[today] = [
      CalendarEvent(id: '1', title: 'Custody Handover', date: today, type: EventType.custody),
    ];
    
    _events[today.add(const Duration(days: 2))] = [
      CalendarEvent(id: '2', title: 'Child Support', date: today, type: EventType.payment),
      CalendarEvent(id: '3', title: 'Dispute', date: today, type: EventType.dispute),
    ];
    
    notifyListeners();
  }
}