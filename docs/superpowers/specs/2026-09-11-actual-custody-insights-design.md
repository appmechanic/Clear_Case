# Actual-activity custody insights, multi-day entries, AU financial year

Client feedback batch (Sep 2026): scheduled rules, calendar, insights and reports.

## Principle

Scheduled rules are for **reminders and planned dates only**. Nothing calculates
compliance, fulfilment or percentages from them any more. Insights and reports
describe what was actually recorded.

## Data model

`custodyRecords/{id}` gains `endDate` (Timestamp, date-only, last day covered).
`startTime` is on the first day, `endTime` on the last day. The form no longer
writes `isScheduled` or `isFulfilled`; existing docs keep them but nothing reads
them. Docs without `endDate` are single-day entries.

`CustodySpan` (`lib/core/utils/custody_span.dart`) is the single reader for
this: `CustodySpan.fromMap(data)`, `.nights` (end day − start day, on UTC dates
so DST can't drop a night), `.days`, `.label`.

## Metrics

- **Total Entries**: custody entries whose span overlaps the period.
- **Total Nights**: distinct nights (keyed by the date the night starts)
  covered by those entries *inside* the period. Distinct, so one entry per child
  for the same nights isn't double-counted. A same-day entry is 0 nights.

`CustodyTotals.from(spans, window)` computes both and is shared by
`InsightProvider`, `CustodyInsightProvider` and the PDF.

## Timeframe

`Timeframe` (`lib/core/utils/timeframe.dart`) holds the shared options and turns
one into a `TimeWindow`. The default everywhere is the **Australian financial
year** (1 Jul – 30 Jun). The previous "Current Financial year" filter used
1 April; the old spelling now maps to the AU FY.

- Insights: dropdown in the app bar (above Export). `InsightProvider` caches raw
  docs per collection and recomputes every card when the timeframe changes.
- Detail screens (custody, payments, disputes, non-compliance) open on the
  Insights timeframe; their filter sheets use the same options.
- Export: dropdown (defaults to the Insights timeframe, or AU FY from the
  calendar) plus "Custom range". Previously the preset chips were not applied
  to the report at all; only the manual dates were.

## Calendar

- Swipe paging disabled (`AvailableGestures.none`); months change via the arrows.
- Range selection lives in `CalendarProvider` (`startRangeSelection`,
  `selectRangeDay`, `cancelRangeSelection`), not in TableCalendar's internal
  state, so it survives month paging and the refetch loader. Entry: long-press a
  day, or "Select date range". Once both ends are set, "Add Custody Entry" opens
  `NewCustodyScreen` with a `DateTimeRange`.
- A custody entry is filed under every day it covers (capped at 400) and drawn
  as a bar along the bottom of each cell, flush where it continues. `allEvents`
  de-duplicates custody by id for the PDF.

## Report

- Child column on every record row; case-level records (disputes,
  non-compliance) show "All children".
- The Custody card shows Total Nights / Total Entries plus one row per child.
- Custody rows show the full period and the number of nights.
