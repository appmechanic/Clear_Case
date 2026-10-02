import 'package:clearcase/models/remainder_model.dart';
import 'package:flutter_test/flutter_test.dart';

// functions/index.js (reminderOccursOn) mirrors ReminderModel.occursOn — keep
// these cases in step with it.
void main() {
  ReminderModel repeated({
    required DateTime start,
    required List<int> days,
    int interval = 1,
    DateTime? end,
  }) =>
      ReminderModel(
        caseId: 'c',
        date: start,
        title: 't',
        tag: 'Custody',
        isRepeat: true,
        weekdays: days,
        intervalWeeks: interval,
        endDate: end,
      );

  // Monday 5 Oct 2026.
  final monday = DateTime(2026, 10, 5);

  test('fortnightly Monday + Friday repeats every second week', () {
    final r = repeated(start: monday, days: [DateTime.monday, DateTime.friday], interval: 2);
    final hits = r.occurrencesBetween(monday, DateTime(2026, 11, 1));
    expect(hits, [
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 9),
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 23),
    ]);
  });

  test('a start mid-week counts that week as week one', () {
    // Wednesday start, Monday + Friday fortnightly: the Friday of the start
    // week is first, then the Monday/Friday two weeks on.
    final r = repeated(start: DateTime(2026, 10, 7), days: [1, 5], interval: 2);
    expect(r.nextOccurrence(from: DateTime(2026, 10, 7)), DateTime(2026, 10, 9));
    expect(r.occursOn(DateTime(2026, 10, 12)), isFalse);
    expect(r.occursOn(DateTime(2026, 10, 19)), isTrue);
  });

  test('every 3 and 4 weeks', () {
    final three = repeated(start: monday, days: [DateTime.saturday], interval: 3);
    expect(three.occurrencesBetween(monday, DateTime(2026, 11, 30)),
        [DateTime(2026, 10, 10), DateTime(2026, 10, 31), DateTime(2026, 11, 21)]);
    final four = repeated(start: monday, days: [DateTime.sunday], interval: 4);
    expect(four.occurrencesBetween(monday, DateTime(2026, 12, 31)),
        [DateTime(2026, 10, 11), DateTime(2026, 11, 8), DateTime(2026, 12, 6)]);
  });

  test('end date is inclusive and stops the series', () {
    final r = repeated(start: monday, days: [DateTime.monday], end: DateTime(2026, 10, 19));
    expect(r.occurrencesBetween(monday, DateTime(2026, 12, 31)),
        [DateTime(2026, 10, 5), DateTime(2026, 10, 12), DateTime(2026, 10, 19)]);
    expect(r.nextOccurrence(from: DateTime(2026, 10, 20)), isNull);
  });

  test('nothing before the start date', () {
    final r = repeated(start: monday, days: [DateTime.monday]);
    expect(r.occursOn(DateTime(2026, 9, 28)), isFalse);
  });

  test('stays on cycle across a daylight-saving change', () {
    // Spans the Australian (5 Oct) and northern (25 Oct / 1 Nov) DST shifts.
    final r = repeated(start: DateTime(2026, 9, 7), days: [DateTime.monday], interval: 2);
    expect(r.occursOn(DateTime(2026, 11, 2)), isTrue);
    expect(r.occursOn(DateTime(2026, 11, 9)), isFalse);
  });

  test('single reminder occurs only on its date', () {
    final r = ReminderModel(caseId: 'c', date: DateTime(2026, 10, 9, 15), title: 't', tag: 'School');
    expect(r.occursOn(DateTime(2026, 10, 9)), isTrue);
    expect(r.occursOn(DateTime(2026, 10, 16)), isFalse);
    expect(r.isActiveRepeat, isFalse);
  });

  test('describes the repeat in words', () {
    expect(ReminderModel.describeRepeat([5, 1], 2), 'every second Monday and Friday');
    expect(ReminderModel.describeRepeat([6, 7, 3], 1), 'every Wednesday, Saturday and Sunday');
  });
}
