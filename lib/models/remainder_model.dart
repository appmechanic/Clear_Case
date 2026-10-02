import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// "Remind me" choices. The labels are matched in functions/index.js
/// (REMIND_OFFSET_DAYS / REMINDER_OFF) — change both together.
const List<String> remindMeOptions = [
  "On day of event",
  "1 day before",
  "A week before",
  reminderNotificationsOff,
];
const String reminderNotificationsOff = "No notification";

/// Repeat frequency in weeks → label. "Fortnightly" on Mon + Fri means every
/// second Monday and Friday.
const Map<int, String> reminderFrequencies = {
  1: "Weekly",
  2: "Fortnightly",
  3: "Every 3 weeks",
  4: "Every 4 weeks",
};

/// Colours a reminder's tag can take (ARGB ints, as stored in Firestore).
const List<int> reminderColors = [
  0xFF8E24AA, // purple
  0xFF43A047, // green
  0xFF1E88E5, // blue
  0xFF00ACC1, // teal
  0xFFFB8C00, // orange
  0xFFE53935, // red
  0xFFD81B60, // pink
  0xFF6D4C41, // brown
  0xFF546E7A, // slate
  0xFF3949AB, // indigo
];

/// Suggested tags, each with the colour it starts on. Users can type any tag
/// and pick any colour.
const Map<String, int> reminderTagSuggestions = {
  "Custody": 0xFF8E24AA,
  "Payment": 0xFF43A047,
  "School": 0xFF1E88E5,
  "Medical": 0xFFE53935,
  "Birthday": 0xFFD81B60,
  "Court": 0xFF546E7A,
};

/// Reminders written before tags had colours.
const int defaultReminderColor = 0xFFE040FB; // Colors.purpleAccent

/// A reminder on one date, or repeated on chosen weekdays every
/// [intervalWeeks] weeks.
///
/// Stored in `cases/{caseId}/reminders`. functions/index.js reads the same
/// fields to send notifications and must stay in step with [occursOn].
class ReminderModel {
  String? id;
  String caseId;

  /// Single: the reminder's date. Repeated: the date it starts from — its
  /// week is "week one" of the cycle.
  DateTime date;
  String title;

  /// Free-text label, e.g. "Custody". Stored as `type` (the field's name
  /// before tags were free text).
  String tag;
  int color;
  bool isRepeat;

  /// Repeated only: DateTime.weekday values (Mon = 1 … Sun = 7).
  List<int> weekdays;

  /// Repeated only: 1 = weekly, 2 = fortnightly, 3, 4.
  int intervalWeeks;

  /// Repeated only: last day it can occur on; null repeats indefinitely.
  /// Stored as `ruleEndDate`.
  DateTime? endDate;
  String description;
  String remindMeOption;
  DateTime? createdAt;

  ReminderModel({
    this.id,
    required this.caseId,
    required this.date,
    required this.title,
    required this.tag,
    this.color = defaultReminderColor,
    this.isRepeat = false,
    this.weekdays = const [],
    this.intervalWeeks = 1,
    this.endDate,
    this.description = '',
    this.remindMeOption = "On day of event",
    this.createdAt,
  });

  ReminderModel copyWith({String? id, String? caseId}) {
    return ReminderModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      date: date,
      title: title,
      tag: tag,
      color: color,
      isRepeat: isRepeat,
      weekdays: weekdays,
      intervalWeeks: intervalWeeks,
      endDate: endDate,
      description: description,
      remindMeOption: remindMeOption,
      createdAt: createdAt,
    );
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map, String docId) {
    final weekdays = ((map['weekdays'] as List?) ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();
    final interval = (map['intervalWeeks'] as num?)?.toInt() ?? 1;
    return ReminderModel(
      id: docId,
      caseId: map['caseId'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: map['title'] ?? '',
      tag: map['type'] ?? '',
      color: (map['color'] as num?)?.toInt() ?? defaultReminderColor,
      // A repeat with no days can't occur; treat it as a single reminder
      // (covers docs from the old, never-shipped "repeat N days" field).
      isRepeat: map['isRepeat'] == true && weekdays.isNotEmpty,
      weekdays: weekdays,
      intervalWeeks: reminderFrequencies.containsKey(interval) ? interval : 1,
      endDate: (map['ruleEndDate'] as Timestamp?)?.toDate(),
      description: map['description'] ?? '',
      remindMeOption: map['remindMeOption'] ?? "On day of event",
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'caseId': caseId,
      'date': Timestamp.fromDate(_day(date)),
      'title': title,
      'type': tag,
      'color': color,
      'isRepeat': isRepeat,
      'weekdays': isRepeat ? (weekdays.toSet().toList()..sort()) : <int>[],
      'intervalWeeks': isRepeat ? intervalWeeks : 1,
      'ruleEndDate': (isRepeat && endDate != null) ? Timestamp.fromDate(_day(endDate!)) : null,
      'description': description,
      'remindMeOption': remindMeOption,
    };

    // Only add createdAt if it's a new record
    if (createdAt != null) {
      data['createdAt'] = Timestamp.fromDate(createdAt!);
    } else if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    return data;
  }

  Color get colorValue => Color(color);

  // --- Schedule -------------------------------------------------------------

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  // Whole days from a to b, immune to DST shifts in local time.
  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static DateTime _mondayOf(DateTime d) => _day(d).subtract(Duration(days: d.weekday - DateTime.monday));

  /// Whether the reminder falls on [day].
  bool occursOn(DateTime day) {
    final d = _day(day);
    if (!isRepeat) return d == _day(date);
    if (d.isBefore(_day(date))) return false;
    if (endDate != null && d.isAfter(_day(endDate!))) return false;
    if (!weekdays.contains(d.weekday)) return false;
    final weeks = _daysBetween(_mondayOf(date), _mondayOf(d)) ~/ 7;
    return weeks % intervalWeeks == 0;
  }

  /// Every day in [from]..[to] (inclusive) the reminder falls on.
  List<DateTime> occurrencesBetween(DateTime from, DateTime to) {
    final start = _day(from);
    final end = _day(to);
    if (!isRepeat) {
      final d = _day(date);
      return (d.isBefore(start) || d.isAfter(end)) ? const [] : [d];
    }
    final result = <DateTime>[];
    var cursor = start.isBefore(_day(date)) ? _day(date) : start;
    final last = (endDate != null && _day(endDate!).isBefore(end)) ? _day(endDate!) : end;
    while (!cursor.isAfter(last)) {
      if (occursOn(cursor)) result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return result;
  }

  /// The first day on or after [from] (default today) it falls on, looking up
  /// to a year ahead; null when it has ended.
  DateTime? nextOccurrence({DateTime? from}) {
    final start = _day(from ?? DateTime.now());
    final hits = occurrencesBetween(start, start.add(const Duration(days: 366)));
    return hits.isEmpty ? null : hits.first;
  }

  /// A repeated reminder that hasn't passed its end date.
  bool get isActiveRepeat {
    if (!isRepeat) return false;
    return endDate == null || !_day(endDate!).isBefore(_day(DateTime.now()));
  }

  String get frequencyLabel => reminderFrequencies[intervalWeeks] ?? "Weekly";

  /// e.g. "Mon, Fri · Fortnightly".
  String get scheduleSummary {
    if (!isRepeat) return "Once";
    return "${weekdayList(weekdays)} · $frequencyLabel";
  }

  static const _shortDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  static const _longDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  /// "Mon, Fri" — Monday first, whatever order they were picked in.
  static String weekdayList(Iterable<int> days, {bool long = false}) {
    final names = long ? _longDays : _shortDays;
    final sorted = days.toSet().toList()..sort();
    return sorted.map((d) => names[d - 1]).join(", ");
  }

  /// Plain-English description of a repeat, e.g. "every second Monday and
  /// Friday".
  static String describeRepeat(Iterable<int> days, int intervalWeeks) {
    final sorted = days.toSet().toList()..sort();
    if (sorted.isEmpty) return "";
    final names = sorted.map((d) => _longDays[d - 1]).toList();
    final dayText = names.length == 1
        ? names.first
        : "${names.sublist(0, names.length - 1).join(", ")} and ${names.last}";
    const ordinals = {1: "every", 2: "every second", 3: "every third", 4: "every fourth"};
    return "${ordinals[intervalWeeks] ?? "every"} $dayText";
  }
}
