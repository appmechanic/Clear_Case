import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'timeframe.dart';

/// The calendar days one custody entry covers, from its start day to its end
/// day inclusive. Entries saved before multi-day custody have no `endDate` and
/// cover only their start day.
class CustodySpan {
  final DateTime start;
  final DateTime end;

  CustodySpan(DateTime start, DateTime end)
      : start = dateOnly(start),
        end = dateOnly(end).isBefore(dateOnly(start)) ? dateOnly(start) : dateOnly(end);

  /// Reads `startDate` / `endDate` from a custodyRecords (or flaggedEvents copy) map.
  static CustodySpan? fromMap(Map<String, dynamic> data) {
    final start = _toDate(data['startDate']);
    if (start == null) return null;
    return CustodySpan(start, _toDate(data['endDate']) ?? start);
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// Overnight stays: a 29 Sep – 5 Oct entry covers 6 nights; a same-day
  /// entry covers none. Counted on UTC dates so DST shifts can't lose a day.
  int get nights => _utc(end).difference(_utc(start)).inDays;

  bool get isMultiDay => nights > 0;

  /// "29 Sep – 5 Oct 2026".
  String get label => formatDaySpan(start, end);

  bool covers(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  /// Every day in the span, start to end.
  Iterable<DateTime> get days sync* {
    for (var i = 0; i <= nights; i++) {
      yield DateTime(start.year, start.month, start.day + i);
    }
  }

  /// The date each night begins on (every day except the last).
  Iterable<DateTime> get nightDates => days.take(nights);

  static DateTime _utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}

class CustodyTotals {
  final int entries;
  final int nights;
  const CustodyTotals({this.entries = 0, this.nights = 0});

  /// Entries that overlap [window], and the distinct nights they cover inside
  /// it. Nights are de-duplicated so two entries for the same nights (e.g. one
  /// per child) aren't counted twice.
  factory CustodyTotals.from(Iterable<CustodySpan> spans, TimeWindow window) {
    var entries = 0;
    final nights = <DateTime>{};
    for (final span in spans) {
      if (!window.overlaps(span.start, span.end)) continue;
      entries++;
      for (final night in span.nightDates) {
        if (window.contains(night)) nights.add(night);
      }
    }
    return CustodyTotals(entries: entries, nights: nights.length);
  }
}

String nightsLabel(int nights) => nights == 1 ? "1 night" : "$nights nights";

String daysLabel(int days) => days == 1 ? "1 day" : "$days days";

/// "29 Sep – 5 Oct 2026", "29 Dec 2026 – 3 Jan 2027", or "29 Sep 2026" for a
/// single day.
String formatDaySpan(DateTime start, DateTime end) {
  final s = dateOnly(start);
  final e = dateOnly(end);
  final full = DateFormat('d MMM yyyy');
  if (!e.isAfter(s)) return full.format(s);
  if (s.year == e.year) return "${DateFormat('d MMM').format(s)} – ${full.format(e)}";
  return "${full.format(s)} – ${full.format(e)}";
}
