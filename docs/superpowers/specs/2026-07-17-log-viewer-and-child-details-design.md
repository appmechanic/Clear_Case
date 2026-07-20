# Dispute Log Viewer & Child Details — Design

Date: 2026-07-17
Author: taran-bansal (via Claude Code)
Status: Approved pending spec review

Two independent features. They share no code and can ship in either order.

**Working-tree note:** an earlier reviewed 5-task batch is intentionally uncommitted on `main`
(user instruction). This work stacks on top of it. `case_setup_screen.dart` and
`case_setup_provider.dart` are touched by both efforts — read their CURRENT working-tree state,
not `git show HEAD:`, which predates the batch.

---

## Feature 1 — Full-screen dispute log viewer

### Problem, corrected

The report was that dispute logs "appear as minimised cards" that "truncate the content".
The code says otherwise, and the distinction changes the work:

- Log rows are **not truncated** — they render `title` + `createdAt` date and **nothing else**
  (`dispute_log_details_screen.dart:137-161`). There is no description preview, no `maxLines`,
  no ellipsis, no expand/collapse. The body simply isn't rendered until you tap through.
- **A full detail view already exists**, with working Previous/Next
  (`_buildDetailView`, `:163-195`; nav buttons `:542-549`).

The genuine gaps:

1. The detail view is an **inline swap**, not a route. `int? _selectedLogIndex` (`:22`) drives
   `_selectedLogIndex == null ? _buildListView(...) : _buildDetailView(...)`, and back-navigation
   is **faked** via `PopScope` (`:53-55`) plus a custom AppBar leading (`:60-63`) that pops the
   state instead of the route.
2. **No swipe.** Navigation is index arithmetic. No `PageView`/`PageController` exists anywhere
   in this codebase — this is a new pattern.
3. **Edit and delete are missing from the detail view.** They exist only in the list rows'
   trailing (`:153-154`). So the reading view — the one the user wants to focus on — is the one
   place you cannot act on the entry.

### Design

New pushed screen `lib/views/insights/dispute_log_viewer_screen.dart`,
`static const routeName = '/dispute-log-viewer'`, registered in `lib/core/utils/routers.dart`.

**Arguments** — a `Map<String, dynamic>`, matching the `RuleConfigurationScreen` precedent
(`routers.dart:46-54`):

| Key | Type | Purpose |
|---|---|---|
| `caseId` | `String` | stream scope |
| `disputeId` | `String` | stream scope |
| `initialIndex` | `int` | which log to open on |
| `isClosed` | `bool` | hides edit/delete on a closed dispute, matching `:151` |

**It streams its own data.** The screen subscribes to
`DisputeInsightsProvider.getDisputeLogs(caseId, disputeId)` (`dispute_insight_provider.dart:391-396`)
rather than receiving a static list. Logs are already streamed and ordered
`createdAt descending`; an edit made in the viewer must reflect immediately, which a passed-in
list cannot do.

**Paging:** `PageView` driven by `PageController(initialPage: initialIndex)`. Swipe and the
existing Previous/Next both drive the same controller (`animateToPage`). Prev is disabled on the
first page, Next on the last — preserving current behaviour.

**Content per page** reuses `_buildDetailView`'s existing layout (`:163-195`): title,
`dd MMM yyyy hh:mm a` from `createdAt`, "Related Party" (from the *dispute*, not the log),
the unconstrained `description`, and the 80px horizontal `AttachmentThumbnail` list. The page
scrolls vertically so a long description is fully readable — the stated goal.

**Edit / delete** are added to the viewer's AppBar actions, hidden when `isClosed`. They call the
same paths the list rows use today: `_showLogDialog(...)` and
`deleteLogWithStorage(caseId, disputeId, log)` (`:455-462`).

### Index stability under a live stream

The list is `createdAt desc` and the viewer holds a page index into it. Three cases:

- **Delete the last remaining log** → pop the viewer (nothing left to read).
- **Delete any other log** → the stream emits a shorter list. Clamp the current page to
  `min(currentPage, logs.length - 1)` so the viewer never indexes out of range.
- **Edit a log** → `saveLog` writes `updatedAt`, not `createdAt`, so ordering is stable and the
  index still points at the same entry.

A log added from elsewhere while the viewer is open would shift indices, but `createdAt desc`
puts new logs at index 0 and there is no concurrent-add path from inside the viewer. Clamping
covers it.

### Refactors in code being touched

- **Extract `_showLogDialog`.** It is private to `dispute_log_details_screen.dart`
  (`:301-465`, ~165 lines) and both screens now need it. Move it to a shared widget/function
  (e.g. `lib/views/widgets/dispute_log_dialog.dart`) rather than duplicating 165 lines. It takes
  `(caseId, disputeId, {existingLog})` and already talks to the provider directly.
- **Delete the inline master/detail machinery** from `dispute_log_details_screen.dart`:
  `_selectedLogIndex` (`:22`), the ternary swap, `_buildDetailView` (`:163-195`), the prev/next
  buttons (`:542-549`), the `PopScope` (`:53-55`), and the custom AppBar leading (`:60-63`).
  The system back button then works normally. This meaningfully shrinks a 549-line file.
- Row `onTap` (`:145`) changes from `setState(() => _selectedLogIndex = entry.key)` to a
  `Navigator.pushNamed` carrying the index.

Row edit/delete stay where they are — removing them would be a regression.

---

## Feature 2 — School & address per child

### Problem

`ChildModel` (`case_model.dart:83-105`) has exactly three fields: `id`, `name`, `dob`. There is
no school, address, or any other per-child detail anywhere in the app. Grep confirms `school`
appears only as dropdown string literals ("School Fees", "School") and `address` only as
geocoded *event* location text on custody/payment entries — neither is child data.

`legalRep` and `caseNumber` are **case-level** (`case_model.dart:6-7`) and stay that way. A
per-child legal representative or case reference would let the cover page show conflicting
values for one case.

### Model

```dart
class ChildModel {
  String id;
  String name;
  DateTime dob;
  String? school;
  String? address;
  ...
}
```

Both nullable — every existing child document in Firestore has neither, so `fromMap` must
default them (`map['school']` / `map['address']`, no `?? ''` coercion; keep null distinct from
empty so the PDF can render "—"). `toMap` writes both.

Children are an **embedded array on the case doc** (`case_model.dart:41`), so no migration and
no schema change beyond the map — old children simply read back with nulls.

### Where children are edited

`case_setup_screen.dart`'s `_Step1Form` (`:300-378`) is the only functional child editor. It is
reachable for an existing case via the calendar's "Add Child" → edit mode (from the prior batch).

**Add form** (below the divider, `:321-335`): gains School and Address `CustomTextField`s
alongside the existing name field and DOB picker. Both optional — `_addChild`'s validation
(`:285-294`) still requires only name + DOB.

**Child list tiles** (`:347-361`): currently `title: name`, `subtitle: dob`. The subtitle gains
school and address when present. Keep it compact; a child with neither looks as it does today.

**New: tap-to-edit.** Step 1 today supports only add and delete — there is no way to update a
child. This is load-bearing, not convenience: a child's `id` is referenced by
`options.childIds.contains(c.id)` in the PDF filter (`pdf_generator.dart:168`), by
`event.childIds` (`:44-46`), and by the rule docs' `appliedChildren`
(`rule_configuration_provider.dart:191-206`). **Deleting and re-adding a child mints a new id**
(`case_setup_provider.dart:109-116` uses `DateTime.now().millisecondsSinceEpoch`), silently
breaking rule targeting and export filters. So updating must be an edit, not a delete+re-add.

Tapping a child row opens a dialog to edit name, DOB, school, address — following the
`_showAddChildPopup` shape already in `rule_configuration_screen.dart:279-344`. It calls a new
`CaseSetupProvider.updateChild(String id, {name, dob, school, address})` that mutates the child
in place **preserving `id`**, then `notifyListeners()`.

Persistence is unchanged: `submitCase` writes `_caseData.toMap()` to the case doc, which
serializes the whole children array (`case_model.dart:41`).

### Known gap, deliberately not fixed

`RuleConfigurationProvider.addChild` (`:161-180`) builds a raw `{'id','name','dob'}` map — not a
`ChildModel` — and writes only to `scheduledRules/{category}.appliedChildren`, never to
`case.children`. It will not carry school/address. It is already dead code (its only call site is
commented out at `rule_configuration_screen.dart:187`) and out of scope. Do not revive it.

---

## Feature 2b — PDF cover page

### Current state

`_buildCoverPage` (`pdf_generator.dart:157-249`) prints a CASE INFORMATION block of exactly five
rows (`:211-215`), joining ALL children into single cells:

```dart
_coverInfoRow(children.length > 1 ? "Child Names" : "Child Name", childNames, bold),
_coverInfoRow("Case Number", caseName, bold),
_coverInfoRow("Date of Birth", dobs, bold),
_coverInfoRow("Legal Representative", legalRep, bold),
_coverInfoRow("Parent / Guardian", guardian, bold),
```

where `childNames` is `.join(", ")` and `dobs` is `.join("\n")` (`:171-176`). With two children
you get "Ava, Noah" over "12/03/2015\n03/07/2018" — already positional guesswork, and adding
per-child school and address to that shape would be unreadable.

### Design

Restructure into case-level rows followed by **one block per child**:

```
CASE INFORMATION
  Case Number            12345
  Legal Representative   Jane Smith
  Parent / Guardian      John Doe

CHILDREN
  Ava
    Date of Birth   12/03/2015
    School          Springfield Primary
    Address         12 Oak Street, Springfield

  Noah
    Date of Birth   03/07/2018
    School          —
    Address         —
```

- Reuse `_coverInfoRow` (`:253-270`, 170pt label column) for the rows; add a small per-child
  heading. Keep the existing fonts, spacing, and section-heading treatment — this must look like
  the same document.
- **The existing child filter still applies.** `:167-169` already filters by
  `options.childIds`; a filtered report shows only the selected children's blocks. Do not
  regress this.
- Null/empty school or address renders `"—"`, matching how the file already handles empty
  children (`:172`).
- No children → the CHILDREN section renders a single `"—"`, matching current behaviour.
- `caseName`, `legalRep`, and `guardian` sources are unchanged (`:177-178`, `_fetchParentDetails`
  at `:282+`).

---

## Testing

`flutter test` fails: `test/widget_test.dart` is the stock counter template requiring Firebase.
There is no test suite, no mocks, no `integration_test/`. This work does not add one.

Gate is `flutter analyze` — **0 errors**, no new warnings. Current working-tree baseline is
**136 issues, all info/warning, 0 errors**. New code uses `.withValues(alpha:)`, never the
deprecated `.withOpacity()`.

Manual verification:

1. **Log viewer** — tap a log → opens full-screen on the tapped entry; swipe left/right moves
   between logs; Previous/Next agree with swipe; a long description is fully readable and
   scrolls; edit updates the entry and the view reflects it without reopening; delete removes it
   and stays in range; deleting the last log pops back; system back button returns to the list;
   a closed dispute shows no edit/delete.
2. **Child details** — add a child with school + address; reopen the case in edit mode and
   confirm both persisted; tap a child, change the school, save, and confirm the child's **id is
   unchanged** in Firestore (check any scheduled rule's `appliedChildren` still matches); a child
   added before this change (no school/address) still renders.
3. **PDF** — generate a report for a case with 2+ children; each child gets their own block with
   school and address; a report filtered to one child shows only that child; a child with no
   school/address shows "—".

## Out of scope

- A dedicated "Case Management" screen (does not exist; explicitly deferred).
- Per-child `legalRep` or case reference — both stay case-level.
- Repointing the Settings pencil, which opens `ScheduledDatesScreen` (rules) rather than case
  editing (`settings_screen.dart:285-290`).
- Fixing or reviving `RuleConfigurationProvider.addChild`'s partial child write.
- A test suite.
