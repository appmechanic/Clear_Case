import 'package:clearcase/core/utils/custody_span.dart';
import 'package:clearcase/core/utils/timeframe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Timeframe (Australian financial year)', () {
    test('current FY runs 1 Jul – 30 Jun around the given date', () {
      final w = Timeframe.windowFor(Timeframe.currentFinancialYear, now: DateTime(2026, 9, 11));
      expect(w.start, DateTime(2026, 7, 1));
      expect(w.end, DateTime(2027, 6, 30));
    });

    test('before July belongs to the FY that started last year', () {
      final w = Timeframe.windowFor(Timeframe.currentFinancialYear, now: DateTime(2026, 6, 30));
      expect(w.start, DateTime(2025, 7, 1));
      expect(w.end, DateTime(2026, 6, 30));
    });

    test('previous FY is the year before', () {
      final w = Timeframe.windowFor(Timeframe.previousFinancialYear, now: DateTime(2026, 9, 11));
      expect(w.start, DateTime(2025, 7, 1));
      expect(w.end, DateTime(2026, 6, 30));
    });

    test('legacy "Current Financial year" spelling maps to the AU FY', () {
      final w = Timeframe.windowFor("Current Financial year", now: DateTime(2026, 9, 11));
      expect(w.start, DateTime(2026, 7, 1));
    });

    test('window bounds are inclusive and All Time is unbounded', () {
      final w = Timeframe.windowFor(Timeframe.currentFinancialYear, now: DateTime(2026, 9, 11));
      expect(w.contains(DateTime(2027, 6, 30, 23, 59)), isTrue);
      expect(w.contains(DateTime(2027, 7, 1)), isFalse);
      expect(Timeframe.windowFor(Timeframe.allTime).isUnbounded, isTrue);
    });

    test('label names the financial year', () {
      expect(Timeframe.label(Timeframe.currentFinancialYear, now: DateTime(2026, 9, 11)),
          'Current FY (FY 2026–27)');
    });
  });

  group('CustodySpan', () {
    test('29 Sep – 5 Oct covers 7 days and 6 nights across the month change', () {
      final span = CustodySpan(DateTime(2026, 9, 29), DateTime(2026, 10, 5));
      expect(span.nights, 6);
      expect(span.days.length, 7);
      expect(span.days.last, DateTime(2026, 10, 5));
      expect(span.label, '29 Sep – 5 Oct 2026');
    });

    test('same-day entry covers no nights', () {
      final span = CustodySpan(DateTime(2026, 9, 29, 9), DateTime(2026, 9, 29, 17));
      expect(span.nights, 0);
      expect(span.isMultiDay, isFalse);
    });

    test('legacy record without endDate is a single day', () {
      final span = CustodySpan.fromMap({'startDate': Timestamp.fromDate(DateTime(2026, 9, 29))})!;
      expect(span.start, span.end);
    });

    test('nights are not lost across the April DST change', () {
      // Australian DST ends on the first Sunday of April.
      final span = CustodySpan(DateTime(2027, 4, 3), DateTime(2027, 4, 6));
      expect(span.nights, 3);
    });
  });

  group('CustodyTotals', () {
    final fy = Timeframe.windowFor(Timeframe.currentFinancialYear, now: DateTime(2026, 9, 11));

    test('counts entries and nights', () {
      final totals = CustodyTotals.from([
        CustodySpan(DateTime(2026, 9, 29), DateTime(2026, 10, 5)), // 6 nights
        CustodySpan(DateTime(2026, 11, 6), DateTime(2026, 11, 8)), // 2 nights
        CustodySpan(DateTime(2026, 12, 1), DateTime(2026, 12, 1)), // day visit
      ], fy);
      expect(totals.entries, 3);
      expect(totals.nights, 8);
    });

    test('overlapping entries (one per child) do not double-count nights', () {
      final totals = CustodyTotals.from([
        CustodySpan(DateTime(2026, 9, 1), DateTime(2026, 9, 4)),
        CustodySpan(DateTime(2026, 9, 1), DateTime(2026, 9, 4)),
      ], fy);
      expect(totals.entries, 2);
      expect(totals.nights, 3);
    });

    test('an entry straddling the FY start only counts nights inside the year', () {
      final totals = CustodyTotals.from([
        CustodySpan(DateTime(2026, 6, 28), DateTime(2026, 7, 3)),
      ], fy);
      expect(totals.entries, 1);
      expect(totals.nights, 2); // nights starting 1 Jul and 2 Jul
    });

    test('entries outside the period are excluded', () {
      final totals = CustodyTotals.from([
        CustodySpan(DateTime(2025, 1, 1), DateTime(2025, 1, 5)),
      ], fy);
      expect(totals.entries, 0);
      expect(totals.nights, 0);
    });
  });
}
