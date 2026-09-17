/// Date-range selection on a calendar that shows one month at a time.
///
/// A selection can span months, but the user only ever touches one month's
/// page. So a swipe or tap on a month *other* than the one the range sits in
/// continues the existing range rather than replacing it:
///
/// - on a later month it moves the **end** (26–30 Sep, then swipe 1–5 Oct on
///   the next page → 26 Sep – 5 Oct);
/// - on an earlier month it moves the **start**.
///
/// A swipe/tap within the same month as the range starts a new selection, as
/// before. Clearing (✕) is the way to start over once a range spans months.
class DateRangeSelection {
  final DateTime? start;
  final DateTime? end;

  const DateRangeSelection({this.start, this.end});

  bool get isEmpty => start == null;
  bool get isComplete => start != null && end != null;

  /// Range after swiping from [anchor] to [current], given [base] — the
  /// selection as it was when the swipe began.
  static DateRangeSelection swipe({
    required DateRangeSelection base,
    required DateTime anchor,
    required DateTime current,
  }) {
    final a = _day(anchor);
    final c = _day(current);
    final lo = c.isBefore(a) ? c : a;
    final hi = c.isBefore(a) ? a : c;

    // A lone start day (tapped, then paged) continues like a 1-day range.
    final continued = _continue(base, a, from: lo, to: hi);
    return continued ?? DateRangeSelection(start: lo, end: hi);
  }

  /// Range after tapping [day].
  static DateRangeSelection tap(DateRangeSelection base, DateTime day) {
    final d = _day(day);
    if (base.isEmpty) return DateRangeSelection(start: d);
    if (!base.isComplete) {
      // Second tap closes the range, in either order.
      final s = base.start!;
      return d.isBefore(s)
          ? DateRangeSelection(start: d, end: s)
          : DateRangeSelection(start: s, end: d);
    }
    return _continue(base, d, from: d, to: d) ?? DateRangeSelection(start: d);
  }

  // Cross-month continuation, or null when [anchor] is on the range's own
  // month (i.e. the caller should start a new selection).
  static DateRangeSelection? _continue(
    DateRangeSelection base,
    DateTime anchor, {
    required DateTime from,
    required DateTime to,
  }) {
    if (base.isEmpty) return null;
    final s = base.start!;
    final e = base.end ?? s;
    if (_month(anchor) > _month(s) && !anchor.isBefore(s)) {
      return DateRangeSelection(start: s, end: to);
    }
    if (_month(anchor) < _month(e) && !anchor.isAfter(e)) {
      return DateRangeSelection(start: from, end: e);
    }
    return null;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static int _month(DateTime d) => d.year * 12 + d.month;
}
