import 'package:intl/intl.dart';

/// Date-only local calendar day for [d] (time of day dropped).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// An inclusive span of calendar days. A null bound means "unbounded" on that
/// side, so `TimeWindow()` matches everything.
class TimeWindow {
  final DateTime? start;
  final DateTime? end;

  TimeWindow({DateTime? start, DateTime? end})
      : start = start == null ? null : dateOnly(start),
        end = end == null ? null : dateOnly(end);

  bool get isUnbounded => start == null && end == null;

  /// True when [date]'s calendar day falls inside the window. A null date
  /// passes, matching how the Insights filters have always treated undated rows.
  bool contains(DateTime? date) {
    if (date == null) return true;
    final day = dateOnly(date);
    if (start != null && day.isBefore(start!)) return false;
    if (end != null && day.isAfter(end!)) return false;
    return true;
  }

  /// True when the day span [from]..[to] shares at least one day with the window.
  bool overlaps(DateTime from, DateTime to) {
    if (end != null && dateOnly(from).isAfter(end!)) return false;
    if (start != null && dateOnly(to).isBefore(start!)) return false;
    return true;
  }
}

/// Reporting periods shared by Insights, the Insights detail screens and the
/// PDF export. The Australian financial year (1 July – 30 June) is the default
/// everywhere.
class Timeframe {
  static const String currentFinancialYear = "Current Financial Year";
  static const String previousFinancialYear = "Previous Financial Year";
  static const String lastMonth = "Last month";
  static const String quarter = "Quarter";
  static const String biAnnual = "Bi-annual";
  static const String yearly = "Yearly";
  static const String allTime = "All Time";

  static const String defaultOption = currentFinancialYear;

  static const List<String> options = [
    currentFinancialYear,
    previousFinancialYear,
    lastMonth,
    quarter,
    biAnnual,
    yearly,
    allTime,
  ];

  /// First day (1 July) of the Australian financial year containing [date].
  static DateTime financialYearStart(DateTime date) =>
      DateTime(date.month >= DateTime.july ? date.year : date.year - 1, DateTime.july, 1);

  /// The calendar window [option] covers, relative to [now].
  static TimeWindow windowFor(String? option, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    switch (_normalise(option)) {
      case currentFinancialYear:
        final start = financialYearStart(today);
        return TimeWindow(start: start, end: DateTime(start.year + 1, DateTime.june, 30));
      case previousFinancialYear:
        final start = DateTime(financialYearStart(today).year - 1, DateTime.july, 1);
        return TimeWindow(start: start, end: DateTime(start.year + 1, DateTime.june, 30));
      // Rolling windows keep their historical meaning: everything from N days
      // ago onward, with no upper bound.
      case lastMonth:
        return TimeWindow(start: today.subtract(const Duration(days: 30)));
      case quarter:
        return TimeWindow(start: today.subtract(const Duration(days: 90)));
      case biAnnual:
        return TimeWindow(start: today.subtract(const Duration(days: 182)));
      case yearly:
        return TimeWindow(start: today.subtract(const Duration(days: 365)));
      default:
        return TimeWindow();
    }
  }

  static bool contains(String? option, DateTime? date) => windowFor(option).contains(date);

  /// Short label for dropdowns, e.g. "FY 2026–27" for the current financial year.
  static String label(String option, {DateTime? now}) {
    switch (_normalise(option)) {
      case currentFinancialYear:
        return "Current FY (${_fyName(windowFor(option, now: now).start!)})";
      case previousFinancialYear:
        return "Previous FY (${_fyName(windowFor(option, now: now).start!)})";
      default:
        return option;
    }
  }

  /// Human-readable date span, e.g. "1 Jul 2026 – 30 Jun 2027" or "All Time".
  static String describe(String? option, {DateTime? now}) {
    final window = windowFor(option, now: now);
    return describeWindow(window, fallback: option ?? allTime);
  }

  static String describeWindow(TimeWindow window, {String fallback = allTime, String pattern = 'd MMM yyyy'}) {
    final fmt = DateFormat(pattern);
    if (window.start != null && window.end != null) {
      return "${fmt.format(window.start!)} – ${fmt.format(window.end!)}";
    }
    if (window.start != null) return "From ${fmt.format(window.start!)}";
    if (window.end != null) return "Up to ${fmt.format(window.end!)}";
    return fallback;
  }

  static String _fyName(DateTime fyStart) =>
      "FY ${fyStart.year}–${((fyStart.year + 1) % 100).toString().padLeft(2, '0')}";

  // Older builds persisted/passed different spellings of the FY option.
  static String? _normalise(String? option) {
    switch (option) {
      case "Current Financial year":
      case "Current FY":
        return currentFinancialYear;
      default:
        return option;
    }
  }
}
