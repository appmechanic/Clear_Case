import 'dart:ui';

import 'package:clearcase/core/utils/calendar_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Weeks start on Monday. September 2026 starts on a Tuesday and spans 5
  // week rows; October 2026 starts on a Thursday and also spans 5.
  const rowHeight = 52.0;
  const width = 350.0; // 50px per column
  final sept = CalendarGrid(month: DateTime(2026, 9, 1), rowHeight: rowHeight);
  // Header + weekday row above the grid: 80px.
  final size = Size(width, 80 + sept.weekCount * rowHeight);

  Offset cell(int row, int col) =>
      Offset(col * 50 + 25, 80 + row * rowHeight + rowHeight / 2);

  test('week rows match the month', () {
    expect(sept.weekCount, 5);
    expect(CalendarGrid(month: DateTime(2026, 8, 1), rowHeight: rowHeight).weekCount, 6); // Sat 1st
    expect(CalendarGrid(month: DateTime(2026, 3, 1), rowHeight: rowHeight).weekCount, 6); // Sun 1st, 31 days
    expect(CalendarGrid(month: DateTime(2027, 2, 1), rowHeight: rowHeight).weekCount, 4); // Mon 1st, 28 days
    expect(sept.firstVisibleDay, DateTime(2026, 8, 31));
  });

  test('the top-left cell is the Monday on or before the 1st', () {
    expect(CalendarGrid(month: DateTime(2026, 10, 1), rowHeight: rowHeight).firstVisibleDay,
        DateTime(2026, 9, 28)); // Thu 1st
    expect(CalendarGrid(month: DateTime(2026, 6, 1), rowHeight: rowHeight).firstVisibleDay,
        DateTime(2026, 6, 1)); // Mon 1st
    expect(CalendarGrid(month: DateTime(2026, 3, 1), rowHeight: rowHeight).firstVisibleDay,
        DateTime(2026, 2, 23)); // Sun 1st
  });

  test('maps cells to days', () {
    expect(sept.dayAt(cell(0, 1), size), DateTime(2026, 9, 1)); // Tue
    expect(sept.dayAt(cell(1, 4), size), DateTime(2026, 9, 11)); // Fri
    expect(sept.dayAt(cell(4, 2), size), DateTime(2026, 9, 30)); // Wed
  });

  test('header and blank cells are not days', () {
    expect(sept.dayAt(const Offset(100, 40), size), isNull);
    expect(sept.dayAt(cell(0, 0), size), isNull); // 31 Aug, hidden
    expect(sept.dayAt(cell(4, 4), size), isNull); // 2 Oct, hidden
  });

  test('clamped lookups snap to the grid and the month', () {
    expect(sept.dayAt(cell(0, 0), size, clamp: true), DateTime(2026, 9, 1));
    expect(sept.dayAt(cell(4, 6), size, clamp: true), DateTime(2026, 9, 30));
    // Dragged below the grid and past the right edge.
    expect(sept.dayAt(Offset(width + 40, size.height + 30), size, clamp: true), DateTime(2026, 9, 30));
    // Dragged up into the weekday row: stays on the first week.
    expect(sept.dayAt(const Offset(75, 60), size, clamp: true), DateTime(2026, 9, 1));
  });

  // September 2026: the 1st is a Tuesday (row 0, col 1), the 30th a
  // Wednesday (row 4, col 2).
  test('edgeDirection: past the last day turns forward', () {
    expect(sept.edgeDirection(Offset(width / 2, size.height + 10), size), 1); // below the grid
    expect(sept.edgeDirection(cell(4, 3), size), 1); // blank cell after the 30th
    expect(sept.edgeDirection(cell(4, 6), size), 1);
    expect(sept.edgeDirection(cell(4, 2), size), 0); // on the 30th itself
  });

  test('edgeDirection: before the first day turns back', () {
    expect(sept.edgeDirection(const Offset(75, 60), size), -1); // weekday row
    expect(sept.edgeDirection(cell(0, 0), size), -1); // blank cell before the 1st
    expect(sept.edgeDirection(cell(0, 1), size), 0); // on the 1st itself
  });

  test('edgeDirection: the outer edge only counts on the first / last row', () {
    expect(sept.edgeDirection(Offset(width - 5, 80 + 2 * rowHeight + 10), size), 0); // middle row
    expect(sept.edgeDirection(Offset(5, 80 + 2 * rowHeight + 10), size), 0);
    // A month ending on a Sunday: the right edge of its last cell turns forward.
    final may = CalendarGrid(month: DateTime(2026, 5, 1), rowHeight: rowHeight); // Fri 1st, Sun 31st
    final maySize = Size(width, 80 + may.weekCount * rowHeight);
    final lastRowY = maySize.height - rowHeight / 2;
    expect(may.edgeDirection(Offset(width - 5, lastRowY), maySize), 1);
    expect(may.edgeDirection(Offset(width - 25, lastRowY), maySize), 0);
  });
}
