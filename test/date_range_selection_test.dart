import 'package:clearcase/core/utils/date_range_selection.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int m, int day) => DateTime(2026, m, day);

void expectRange(DateRangeSelection r, DateTime start, DateTime? end) {
  expect(r.start, start);
  expect(r.end, end);
}

void main() {
  const none = DateRangeSelection();

  group('swipe', () {
    test('fresh swipe selects anchor..current in either direction', () {
      expectRange(DateRangeSelection.swipe(base: none, anchor: d(9, 26), current: d(9, 30)), d(9, 26), d(9, 30));
      expectRange(DateRangeSelection.swipe(base: none, anchor: d(9, 30), current: d(9, 26)), d(9, 26), d(9, 30));
    });

    test('swiping on the next month continues the range (the reported case)', () {
      final sept = DateRangeSelection(start: d(9, 26), end: d(9, 30));
      expectRange(DateRangeSelection.swipe(base: sept, anchor: d(10, 1), current: d(10, 5)), d(9, 26), d(10, 5));
    });

    test('adjusting the end on the later month keeps the start', () {
      final span = DateRangeSelection(start: d(9, 26), end: d(10, 5));
      expectRange(DateRangeSelection.swipe(base: span, anchor: d(10, 1), current: d(10, 8)), d(9, 26), d(10, 8));
      expectRange(DateRangeSelection.swipe(base: span, anchor: d(10, 1), current: d(10, 3)), d(9, 26), d(10, 3));
    });

    test('swiping on an earlier month moves the start', () {
      final oct = DateRangeSelection(start: d(10, 1), end: d(10, 5));
      expectRange(DateRangeSelection.swipe(base: oct, anchor: d(9, 26), current: d(9, 30)), d(9, 26), d(10, 5));
      final span = DateRangeSelection(start: d(9, 26), end: d(10, 5));
      expectRange(DateRangeSelection.swipe(base: span, anchor: d(9, 28), current: d(9, 29)), d(9, 28), d(10, 5));
    });

    test('a tapped start day continues into the next month', () {
      final startOnly = DateRangeSelection(start: d(9, 26));
      expectRange(DateRangeSelection.swipe(base: startOnly, anchor: d(10, 1), current: d(10, 5)), d(9, 26), d(10, 5));
    });

    test('swiping within the same month starts over', () {
      final sept = DateRangeSelection(start: d(9, 3), end: d(9, 5));
      expectRange(DateRangeSelection.swipe(base: sept, anchor: d(9, 15), current: d(9, 20)), d(9, 15), d(9, 20));
    });

    test('works across a year boundary', () {
      final dec = DateRangeSelection(start: DateTime(2026, 12, 28), end: DateTime(2026, 12, 31));
      final r = DateRangeSelection.swipe(base: dec, anchor: DateTime(2027, 1, 1), current: DateTime(2027, 1, 3));
      expectRange(r, DateTime(2026, 12, 28), DateTime(2027, 1, 3));
    });
  });

  group('tap', () {
    test('first tap starts, second closes (either order)', () {
      final one = DateRangeSelection.tap(none, d(9, 29));
      expectRange(one, d(9, 29), null);
      expectRange(DateRangeSelection.tap(one, d(10, 5)), d(9, 29), d(10, 5));
      expectRange(DateRangeSelection.tap(one, d(9, 20)), d(9, 20), d(9, 29));
    });

    test('tapping a later month extends a finished range', () {
      final sept = DateRangeSelection(start: d(9, 26), end: d(9, 30));
      expectRange(DateRangeSelection.tap(sept, d(10, 5)), d(9, 26), d(10, 5));
    });

    test('tapping the same month starts over', () {
      final sept = DateRangeSelection(start: d(9, 26), end: d(9, 30));
      expectRange(DateRangeSelection.tap(sept, d(9, 10)), d(9, 10), null);
    });
  });
}
