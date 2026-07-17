# Client Feedback Batch — Design

Date: 2026-07-17
Author: taran-bansal (via Claude Code)
Status: Approved pending spec review

Four independent client-feedback items. They share no code and can ship in any order,
though Task 4 is trivial and Task 2 is by far the largest.

---

## Task 1 — Auto-compress images, drop cropping, raise document limit

### Problem

Adding a photo to a record forces a mandatory crop and then rejects the result over 2 MB
with "Image exceeds 2MB after processing — try a tighter crop". The advice is misleading.

Root cause, from `lib/views/widgets/attachment_picker_widget.dart`:

- The **crop step is doing the compression** (`compressQuality: 90`, 1200px cap, line 132-158).
  Removing it removes size reduction, so compression must replace it — not merely supplement it.
- `_stampImage` (line 224-295) re-encodes camera photos to **PNG** via `dart:ui`
  (`ui.ImageByteFormat.png`, line 289-293). A 1200x1200 PNG photo routinely exceeds 2 MB.
  This is the actual bloat source; a tighter crop barely helps a PNG.
- Camera picks go through `ImagePicker` with `imageQuality: 85, maxWidth/maxHeight: 1600`
  (line 78-83) and are pre-shrunk. Gallery picks go through `FilePicker.platform.pickFiles`
  (line 93-103) with **no downscaling at all**. That asymmetry is where most >2 MB rejections
  originate.

### Decision

Auto-compress and remove cropping entirely. Raise the document limit to 10 MB.

### Design

Add `flutter_image_compress` to `pubspec.yaml`. Remove `image_cropper` from `pubspec.yaml`
and from the app.

Rewrite `_processAndAddFiles` (line 107-184). New flow per file:

1. Determine `isImage` by extension (existing logic, line 111-112: `jpg`/`jpeg`/`png`).
2. **Non-image branch** — keep rejecting, at the new 10 MB limit. PDFs, Word, Excel,
   PowerPoint and .txt cannot be compressed by this path.
3. **Image branch**:
   - Stamp timestamp + location (camera only, existing behaviour, line 164).
   - Compress.
   - Add to `processed`.
   - Delete the crop call (line 132-159) and the post-crop size rejection (line 172-179).

Compression helper, JPEG output:

- `FlutterImageCompress.compressWithFile` / `compressAndGetFile`, `format: CompressFormat.jpeg`,
  `minWidth: 1600, minHeight: 1600`, starting `quality: 85`.
- If still over the image budget, retry at quality 75, then 60, then 50. Cap at those four
  attempts; do not loop unbounded.
- Image budget: 10 MB hard ceiling as a safety net. After compression this should never fire.

`_stampImage` changes to emit **JPEG** rather than PNG. Since `dart:ui` only encodes PNG,
it keeps producing PNG bytes internally and then hands them to the compressor, which emits
the final JPEG. Output filename changes from `${source.path}_stamped.png` accordingly.

### Size limits

| Kind | Before | After |
|---|---|---|
| Images | reject > 2 MB | auto-compressed; 10 MB safety net |
| Documents | reject > 2 MB | reject > 10 MB |

**10 MB is bounded by an existing coupling, not chosen arbitrarily.**
`lib/views/widgets/attachment_preview.dart:99-105` downloads attachments via
`getData(20 * 1024 * 1024)`, and `getData` **throws** when a file exceeds maxSize. A document
above 20 MB would upload successfully and then be permanently un-previewable in the app.
10 MB leaves headroom. Going above 20 MB requires reworking `attachment_preview` to stream to
disk instead of loading a whole `Uint8List` into memory — out of scope, and an OOM risk on
low-end devices. **Update the stale comment at `attachment_preview.dart:100`**, which currently
reads "well above the 2 MB attachment limit".

### Copy

Line 68 currently reads:
`"Supports images, PDF, Word, Excel, PowerPoint and .txt\nfile size < 2 Mb"`

Becomes:
`"Supports images, PDF, Word, Excel, PowerPoint and .txt\nImages are compressed automatically · Documents < 10 MB"`

### Accepted consequences

- Gallery images lose the circular crop; all attachments become rectangular. The `useCircleCrop`
  branch (line 127-131) and its explanatory comment are deleted with it.
- Users lose the ability to frame a shot. Accepted deliberately: the client's report is that
  cropping is an unnecessary extra step.

### Blast radius

None outside the picker. Uploads happen in providers via `ref.putFile(file)` with no size or
compression logic (`new_entry_provider.dart:23-35`, `non_compliance_provider.dart:33-36`,
`dispute_provider.dart:45-52` and `:131-138`, `dispute_insight_provider.dart:418-420`), so
compressing at the widget covers all five consuming screens with no provider changes.

---

## Task 2 — "Add Child to Current Case" as primary, with case edit mode

### Problem

The client asked to make "Add Child to Current Case" primary over "Create New Case".
**Neither string exists, and neither does the feature.**

- The only case-creation affordance in the calendar's top-left is a sentinel
  `DropdownMenuItem(value: "add_new")` labelled "Add New Case", as the **last row** of the
  case-selector dropdown (`lib/views/home/calender_screen.dart:159-166`, handled at :167-175).
- **There is no way to add a child to an existing case.** `_buildAddNewChildButton`
  (`lib/views/home/rule_configuration_screen.dart:262-276`) exists but its only call site is
  commented out at `:187`. Adding a child works only inside the create wizard's Step 1.
- Reviving that dead button would be wrong regardless: `RuleConfigurationProvider.addChild`
  → `_syncChildrenToDb` (`rule_configuration_provider.dart:192-205`) writes only
  `scheduledRules/{category}.appliedChildren`, never the case document's own `children` array.
  A child added there is invisible to `CaseModel.children` and every other consumer.

So this task is: build the missing flow, then give it primary placement.

### Decision

Entry point is the **calendar top-left dropdown**. Tapping "Add Child" opens `CaseSetupScreen`
in edit mode for the selected case, running the **full wizard (steps 1→3)**, with **existing
scheduled rules loaded into the form** so a re-run edits rather than clobbers them.

### Design

#### Dropdown (`calender_screen.dart`, `_buildHeader`)

Order becomes:

```
Case #12345
Case #67890
────────────
+ Add Child        <- new sentinel "add_child", bold / AppColors.primary, primary emphasis
Add New Case       <- existing sentinel "add_new", demoted to plain styling
```

- "Add Child" is **hidden when no case is selected** (`provider.selectedCase == null`), since
  it has no target.
- `onChanged` gains an `add_child` branch:
  `Navigator.pushNamed(context, CaseSetupScreen.routeName, arguments: provider.selectedCase)`.
- The existing `add_new` branch is unchanged apart from styling.

#### Edit mode (`case_setup_screen.dart`)

`CaseSetupScreen` is create-only today. Three changes:

1. Read `ModalRoute.of(context)?.settings.arguments as CaseModel?`. Non-null ⇒ edit mode.
   The route builder at `lib/core/utils/routers.dart:39` drops `const`.
2. On init, when in edit mode, call `provider.loadExistingCase(caseModel)` and
   `await provider.loadExistingRules(caseModel.id)`.
3. Step 1 renders prefilled: case number, legal rep, and the existing children list with its
   delete affordances. The inline add-child form below the divider is unchanged.

`isNewUser` (`:60`, `!Navigator.canPop(context)`) is unaffected — edit mode is always pushed,
so it stays false.

#### Provider (`case_setup_provider.dart`)

- `_caseData` is `final` and constructed empty (`:19-23`). It becomes **non-final** so
  `loadExistingCase` can replace it wholesale.
- New `String? _editingCaseId`; `bool get isEditing => _editingCaseId != null`.
- New `loadExistingCase(CaseModel c)` — sets `_caseData` and `_editingCaseId`, `notifyListeners()`.
- New `loadExistingRules(String caseId)` — reads `users/{uid}/cases/{caseId}/scheduledRules`,
  keeps the docs by category. When the user picks a category on Step 2, Step 3 prefills from
  that category's existing doc if present.

  Note rules are stored **one doc per category**: `scheduledRules/{ruleType.toLowerCase()}`
  with the config map plus `createdAt` and `category` (`case_setup_provider.dart:126-137`).
  `submitCase` writes only the single `_selectedRuleType`, so other categories are untouched
  by a save — no wipe risk beyond the edited category.

  Implementation note: check `RuleConfigurationProvider` for an existing rule-loading path to
  reuse before writing a new one.

- **`submitCase` must branch on edit — this is the load-bearing change.** Today:

  ```dart
  DocumentReference caseRef = _firestore
      .collection('users').doc(user.uid).collection('cases')
      .doc();          // no id argument = new auto-id doc EVERY save
  batch.set(caseRef, mainCaseData);
  ```

  Without a branch, editing an existing case **silently creates a duplicate**. Becomes:

  ```dart
  final caseRef = isEditing
      ? _firestore.collection('users').doc(user.uid).collection('cases').doc(_editingCaseId)
      : _firestore.collection('users').doc(user.uid).collection('cases').doc();
  batch.set(caseRef, mainCaseData, isEditing ? SetOptions(merge: true) : null);
  ```

- **Preserve `createdAt` on edit.** Line 105 unconditionally does
  `_caseData.createdAt = DateTime.now();`, and `mainCaseData` carries it. Under edit + merge
  this silently resets the case's creation date. Guard it to the create path only.

- **Delete the dead user-doc children write** (`:140-148`):

  ```dart
  DocumentReference userRef = _firestore.collection('users').doc(user.uid);
  batch.set(userRef, {'children': FieldValue.arrayUnion(childrenList)}, SetOptions(merge: true));
  ```

  It writes children to `users/{uid}`, not the case doc, where nothing reads them. Children
  already reach the case doc via `_caseData.toMap()` (`case_model.dart:41`). It is inert today
  but under repeated edits it would accumulate duplicate children on the user document. It is
  inside the method being changed, so it goes now.

- **Navigation on save.** `submitCase` ends with
  `Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: 0)` (`:158`).
  In edit mode this should `Navigator.pop(context)` back to the calendar instead.

### Data shape

`ChildModel` is an **embedded array on the case document** (`case_model.dart:41`,
`ChildModel.toMap` at `:90-96`), not a subcollection. `batch.set(caseRef, mainCaseData, merge)`
rewrites the whole `children` array from `_caseData`, which is correct here because edit mode
loads the existing children first. Do **not** switch to `arrayUnion` — it would break child
deletion in Step 1.

---

## Task 3 — Tappable Flagged → filtered view

### Problem

`lib/views/widgets/flagged_events_overview.dart` is a plain `StatelessWidget` rooted at a bare
`Container` (`:21`) taking five `int` counts (`:4-17`). It has no `onTap`, `GestureDetector`, or
`InkWell` — the only overview card lacking one. Users can see the count but not the entries.

### Design — mostly UI; the data already exists

`flaggedEvents` is already a **denormalized index**: each doc is a full copy of the origin record
spread into the doc, plus pointer fields. `InsightProvider` already live-streams the collection
(`insight_provider.dart:214-217`) and computes the counts (`_calculateFlaggedInsightsSync`,
`:257-269`).

Path: `users/{uid}/cases/{caseId}/flaggedEvents/{autoId}`, written on create by
`new_entry_provider.dart:70-71` (custody) and `:201` (payment),
`non_compliance_provider.dart:46-56`, `dispute_provider.dart:72-84`.

Changes:

1. **`FlaggedEventsOverview`** — add `final VoidCallback? onTap;` and wrap in
   `Material` + `InkWell`, matching the ripple pattern in `insights_screen.dart:222-226`.
2. **`insights_screen.dart:183-189`** — pass `onTap:`, pushing
   `FlaggedEventsScreen.routeName` with `arguments: insightProvider.selectedCase`,
   matching every other card (`:109-114`, `:142-152`, `:156-164`, `:167-178`).
   Null-guard on `selectedCase` as `PaymentOverview` and `NonComplianceOverview` do.
3. **`InsightProvider`** — retain the raw flagged docs alongside the counts it already derives.
   Add `List<Map<String, dynamic>> flaggedEvents`, populated in the same listener at `:214-217`.
   Reset it at `:322` alongside the counts.
4. **New `lib/views/insights/flagged_events_screen.dart`**, registered in
   `lib/core/utils/routers.dart`.

### Screen

Follows the `custody_compliance_screen.dart` template exactly:

- `static const routeName = '/flagged-events'`, `StatefulWidget`.
- `Scaffold` bg `Color(0xFFF5F5F5)`, `appBar: _buildAppBar("Insights")`.
- `Consumer<InsightProvider>` → `RefreshIndicator` → `SingleChildScrollView`
  (`padding: EdgeInsets.all(20)`,
  `physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())`).
- Grouped by type with a section header per group, in fixed order:
  **Custody · Payments · Disputes · Non-Compliance**. Empty groups are omitted.
  `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` per group.
- Empty state when there are no flagged entries at all.

Grouping key is `originCollection`. Reuse the existing bucketing semantics from
`_calculateFlaggedInsightsSync` (`:257-269`), including its catch-all: anything not
`paymentRecords` / `disputeRecords` / `nonComplianceRecords` falls into custody
(`else tempC++`, `:264`). Keep the count and the list consistent by construction — the list
must not disagree with the number on the card.

### The sharp edge — `originId`, not the doc id

A `flaggedEvents` doc's own id is an **auto-id**, not the origin record's. The origin link is
carried only by the `originId` field; there is no doc-id convention.

Detail screens are navigated with the raw record map (see
`custody_compliance_screen.dart:142-152`, which passes the Firestore doc data). So when routing
from a flagged row, **substitute `originId` as the record's `id`** before passing it, or the
detail screen resolves the wrong document.

Route per `originCollection`:

| `originCollection` | Detail screen |
|---|---|
| `custodyRecords` | `CustodyDetailsScreen` |
| `paymentRecords` | `PaymentDetailScreen` |
| `disputeRecords` | `DisputeLogDetailsScreen` |
| `nonComplianceRecords` | `NonComplianceDetailScreen` |

Also note `dispute_provider.dart:72-84` writes its flagged doc **without a `caseId` field**,
unlike the other three. Don't rely on `caseId` being present on a flagged doc; scope by the
subcollection path instead.

---

## Task 4 — Label renames

Four user-visible strings. Identifiers, filenames, class names, and routes are **not** renamed —
churn with no user-visible effect.

| File:line | From | To |
|---|---|---|
| `lib/views/home/calender_screen.dart:69` | `"Scheduled Dates"` (button) | `"Scheduled"` |
| `lib/views/settings/settings_screen.dart:169` | `"Scheduled Dates"` (toggle tile) | `"Scheduled"` |
| `lib/views/home/calender_screen.dart:81` | `"Calendar Legend"` (button) | `"Legends"` |
| `lib/views/home/calender_screen.dart:501` | `"Calendar Legend"` (popup title) | `"Legends"` |

Notes:

- The client wrote "Calender Legend"; the code spells it **"Calendar Legend"** (correct). There
  is no "Calender Legend" string. The *filename* `calender_screen.dart` is misspelled, as are
  `calender_provider.dart` and `calender_event_model.dart` — identifier-level only, left alone.
- `ScheduledDatesScreen`, `scheduled_dates_provider.dart`, and the route registered at
  `routers.dart:45` keep their names.
- `calender_screen.dart:71` and `case_selection_service.dart:6` mention "Scheduled Dates" in
  comments only — update the `calender_screen.dart:71` comment for accuracy; leave the service
  doc comment.
- `functions/index.js` contains **zero** occurrences of either label. No backend change.
  (Unrelated: its `SCHEDULED_RULE_OFFSET_DAYS` keys like `"On the Scheduled day"` are
  notification-offset labels matched against Firestore values, **not** these UI strings. Do not
  touch them — changing them silently breaks notification matching.)

---

## Testing

`flutter test` currently fails: `test/widget_test.dart` is the untouched counter-app template
pumping a `MyApp` that requires Firebase init. There is no real test suite, no mocks, no
`integration_test/`. This batch does not introduce one.

Verification is manual, per task:

1. **Compression** — camera photo and a large (>5 MB) gallery photo both attach without
   rejection; a 12 MB PDF is rejected; a 6 MB PDF attaches; attachments preview correctly after
   upload. Confirm no crop UI appears.
2. **Add Child** — dropdown hides "Add Child" with no case selected; with a case selected it
   opens Step 1 prefilled; saving adds the child to the **existing** case and does **not** create
   a second case (verify case count in Settings); `createdAt` is unchanged in Firestore; existing
   scheduled rules survive a wizard re-run.
3. **Flagged** — card ripples and navigates; grouped counts equal the numbers on the card; each
   row opens the correct detail screen for the correct record.
4. **Renames** — four strings, visually confirmed.

## Out of scope

- Streaming attachment preview to disk (would unblock >20 MB documents).
- Renaming the misspelled `calender_*` files/identifiers.
- Fixing `RuleConfigurationProvider._syncChildrenToDb`'s partial child write, or removing the
  dead `_buildAddNewChildButton` / `_showAddChildPopup` in `rule_configuration_screen.dart`.
  They stay dead; Task 2 does not route through them.
- A test suite.
