import 'dart:ui';

/// Maps a touch point on a month-view TableCalendar to the day under it, for
/// swipe-to-select. Mirrors TableCalendar's layout: the day grid is the
/// bottom `weeks × rowHeight` of the widget (header and weekday row sit above
/// it), weeks start on Monday (`StartingDayOfWeek.monday`), and there's no
/// table padding.
class CalendarGrid {
  final DateTime month;
  final double rowHeight;

  const CalendarGrid({required this.month, required this.rowHeight});

  DateTime get _firstOfMonth => DateTime(month.year, month.month, 1);
  DateTime get _lastOfMonth => DateTime(month.year, month.month + 1, 0);

  /// Blank cells before the 1st in its week row (Monday = 0).
  int get _leadingBlanks => _firstOfMonth.weekday - DateTime.monday;

  /// Monday on or before the 1st — the top-left cell.
  DateTime get firstVisibleDay =>
      DateTime(month.year, month.month, 1 - _leadingBlanks);

  /// Week rows the month occupies (4–6), matching
  /// `sixWeekMonthsEnforced: false`.
  int get weekCount {
    final cells = _leadingBlanks + _lastOfMonth.day;
    return (cells / 7).ceil();
  }

  /// Top of the day grid within a calendar of [size].
  double gridTop(Size size) => size.height - weekCount * rowHeight;

  bool isInGrid(Offset local, Size size) =>
      local.dy >= gridTop(size) && local.dy <= size.height &&
      local.dx >= 0 && local.dx <= size.width;

  /// Day under [local], or null when the point is above the grid or on one of
  /// the blank cells outside the month. With [clamp], points past the grid's
  /// edges snap to the nearest row/column so a swipe that drifts slightly
  /// outside keeps selecting.
  DateTime? dayAt(Offset local, Size size, {bool clamp = false}) {
    final top = gridTop(size);
    if (!clamp && !isInGrid(local, size)) return null;
    final cellWidth = size.width / 7;
    final col = (local.dx / cellWidth).floor().clamp(0, 6);
    final row = ((local.dy - top) / rowHeight).floor().clamp(0, weekCount - 1);
    final first = firstVisibleDay;
    final day = DateTime(first.year, first.month, first.day + row * 7 + col);
    if (day.month != month.month || day.year != month.year) {
      if (!clamp) return null;
      // Blank lead-in / trailing cells snap to the month's first / last day.
      return day.isBefore(_firstOfMonth) ? _firstOfMonth : _lastOfMonth;
    }
    return day;
  }
}
