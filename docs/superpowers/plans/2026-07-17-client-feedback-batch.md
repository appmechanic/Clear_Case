# Client Feedback Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship four client-feedback items: auto-compress image attachments (removing mandatory cropping), make "Add Child to Current Case" a primary action backed by a real case edit mode, make the Insights Flagged card open a filtered list, and rename four UI labels.

**Architecture:** Task 1 is contained entirely in `attachment_picker_widget.dart` — providers upload whatever `File` they're handed, so compressing at the picker covers all five consuming screens. Task 3 is almost pure UI because `flaggedEvents` is already a denormalized subcollection that `InsightProvider` live-streams. Task 5 is the risky one: `CaseSetupProvider.submitCase` currently mints a new case document on every save, so edit mode requires branching it to update-not-create.

**Tech Stack:** Flutter 3.9.2+, Provider, Cloud Firestore (named database `clearcase`), Firebase Storage, `flutter_image_compress` (new), `image_cropper` (removed).

**Source spec:** `docs/superpowers/specs/2026-07-17-client-feedback-batch-design.md`

## Global Constraints

- **Firestore access is ALWAYS via the named database.** Use `FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase')`. Never `FirebaseFirestore.instance` — it does not error, it silently reads an empty default database.
- **No test suite exists.** `flutter test` fails on the stock counter template in `test/widget_test.dart`. Do not add tests; do not try to fix that file. The automated gate for every task is `flutter analyze`. Each task also has manual verification steps.
- **Document size limit: 10 MB** (`10 * 1024 * 1024`). Bounded by `attachment_preview.dart`'s `getData(20 * 1024 * 1024)` ceiling, which throws above its cap.
- **Image size limit: 10 MB** post-compression safety net only.
- Colors come from `AppColors` (`lib/core/theme/app_colors.dart`). `AppColors.primary` is `0xff45086D`.
- Do **not** rename `calender_*` files/identifiers, `ScheduledDatesScreen`, or any route string.
- Do **not** touch `functions/index.js`. Its `SCHEDULED_RULE_OFFSET_DAYS` keys are matched against Firestore values, not UI labels.
- Commit after every task.

## File Structure

| File | Change | Task |
|---|---|---|
| `lib/views/home/calender_screen.dart` | Modify — 2 labels, 1 comment, dropdown | 1, 5 |
| `lib/views/settings/settings_screen.dart` | Modify — 1 label | 1 |
| `pubspec.yaml` | Modify — swap image_cropper → flutter_image_compress | 2 |
| `lib/views/widgets/attachment_picker_widget.dart` | Modify — rewrite `_processAndAddFiles`, `_stampImage`, copy | 2 |
| `lib/views/widgets/attachment_preview.dart` | Modify — stale comment | 2 |
| `lib/views/widgets/flagged_events_overview.dart` | Modify — add `onTap` | 3 |
| `lib/provider/insight_provider.dart` | Modify — retain raw flagged docs | 3 |
| `lib/views/insights/flagged_events_screen.dart` | **Create** — grouped list | 3 |
| `lib/core/utils/routers.dart` | Modify — register flagged route, un-`const` case setup | 3, 5 |
| `lib/views/insights/insights_screen.dart` | Modify — wire card `onTap` | 3 |
| `lib/provider/case_setup_provider.dart` | Modify — edit mode, submitCase branch | 4 |
| `lib/views/home/case_setup_screen.dart` | Modify — accept args, hydrate | 5 |

Tasks are ordered cheapest-first so the risky one lands last. Task 4 (provider) must precede Task 5 (screen) — Task 5 calls the methods Task 4 defines.

---

### Task 1: Label renames

Four user-visible strings. Trivial, no dependencies. Start here to warm up the toolchain.

**Files:**
- Modify: `lib/views/home/calender_screen.dart:69`, `:71-73`, `:81`, `:501`
- Modify: `lib/views/settings/settings_screen.dart:169`

**Interfaces:**
- Consumes: nothing
- Produces: nothing

- [ ] **Step 1: Rename the calendar's "Scheduled Dates" button**

In `lib/views/home/calender_screen.dart`, line 69 currently reads:

```dart
_buildBottomButton("Scheduled Dates", () {
  // Carry over the case currently selected on the
  // calendar so the Scheduled Dates screen opens on
  // the same case (and its children) instead of
  // defaulting to the first case.
```

Change the label and the now-stale comment wording:

```dart
_buildBottomButton("Scheduled", () {
  // Carry over the case currently selected on the
  // calendar so the Scheduled screen opens on
  // the same case (and its children) instead of
  // defaulting to the first case.
```

Leave `ScheduledDatesScreen.routeName` and the `arguments:` line below it untouched.

- [ ] **Step 2: Rename the calendar's "Calendar Legend" button**

Line 81:

```dart
_buildBottomButton("Calendar Legend", () {
  _showLegendsPopup(context);
}),
```

becomes:

```dart
_buildBottomButton("Legends", () {
  _showLegendsPopup(context);
}),
```

- [ ] **Step 3: Rename the legend popup title**

Line 501:

```dart
const Text("Calendar Legend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
```

becomes:

```dart
const Text("Legends", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
```

- [ ] **Step 4: Rename the Settings toggle tile**

In `lib/views/settings/settings_screen.dart`, line 169 has `title: "Scheduled Dates"` (the tile under the `// 1. Scheduled Dates Toggle` comment). Change **only the string literal**:

```dart
title: "Scheduled",
```

- [ ] **Step 5: Verify no user-visible occurrences remain**

Run:

```bash
grep -rn '"Scheduled Dates"\|"Calendar Legend"' lib/
```

Expected: no output. (`ScheduledDatesScreen`, `scheduled_dates_provider.dart`, and the `case_selection_service.dart:6` doc comment are identifiers/comments — they do not match this grep and must stay.)

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: no new issues versus the pre-change baseline.

- [ ] **Step 7: Commit**

```bash
git add lib/views/home/calender_screen.dart lib/views/settings/settings_screen.dart
git commit -m "Rename Scheduled Dates to Scheduled and Calendar Legend to Legends"
```

---

### Task 2: Auto-compress images, drop cropping, documents to 10 MB

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/views/widgets/attachment_picker_widget.dart` (imports, `:68`, `:107-184`, `:220-295`)
- Modify: `lib/views/widgets/attachment_preview.dart:100` (stale comment)

**Interfaces:**
- Consumes: nothing
- Produces: nothing. `AttachmentPickerWidget`'s public API is unchanged — still
  `AttachmentPickerWidget({required Function(List<File>) onFilesChanged})`. No provider or
  consuming screen changes.

**Background the implementer needs:** the crop step is what currently compresses
(`compressQuality: 90`, 1200px cap). Removing it removes size reduction, so compression must
*replace* it. Separately, `_stampImage` encodes to PNG, which is why camera photos blow past
2 MB — a 1200x1200 PNG photo is routinely larger than its JPEG source.

- [ ] **Step 1: Swap the dependency**

In `pubspec.yaml`, **remove** this line:

```yaml
  image_cropper: ^11.0.0
```

and **add** (keep the list's existing alphabetical-ish grouping near `image_picker`):

```yaml
  flutter_image_compress: ^2.3.0
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: "Got dependencies!" — `flutter_image_compress` resolves, `image_cropper` is gone.

- [ ] **Step 3: Update imports**

In `lib/views/widgets/attachment_picker_widget.dart`, delete line 10:

```dart
import 'package:image_cropper/image_cropper.dart';
```

and add:

```dart
import 'package:flutter_image_compress/flutter_image_compress.dart';
```

- [ ] **Step 4: Add the compression helper**

Add these two members to `_AttachmentPickerWidgetState` (place them just above the
`// ---- Stamping (timestamp + location overlay) ----` comment at line 186):

```dart
  // Attachment ceiling. Documents are rejected above this; images are
  // compressed to fit and only rejected if compression somehow can't get
  // under it. Bounded by AttachmentPreview's 20 MB getData cap, which
  // throws for files larger than its limit.
  static const int _maxBytes = 10 * 1024 * 1024;

  // Re-encodes to JPEG, stepping quality down until the result fits under
  // _maxBytes. Replaces the old crop step, which was doing the compression
  // implicitly via compressQuality. Returns null if every attempt failed.
  Future<File?> _compressImage(File source) async {
    const qualities = [85, 75, 60, 50];
    for (final quality in qualities) {
      final target = '${source.path}_c$quality.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        target,
        quality: quality,
        minWidth: 1600,
        minHeight: 1600,
        format: CompressFormat.jpeg,
      );
      if (result == null) continue;
      final out = File(result.path);
      if (await out.length() <= _maxBytes) return out;
    }
    return null;
  }
```

- [ ] **Step 5: Rewrite `_processAndAddFiles`**

Replace the whole method (lines 107-184, from `Future<void> _processAndAddFiles` through the
closing brace before the stamping comment) with:

```dart
  Future<void> _processAndAddFiles(List<File> files, {bool fromCamera = false}) async {
    List<File> processed = [];
    for (var file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png'].contains(ext);

      // Documents can't be compressed by this path — enforce size up front.
      if (!isImage) {
        if (await file.length() > _maxBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("File exceeds 10MB")));
          }
          continue;
        }
        processed.add(file);
        continue;
      }

      File outFile = file;
      // Only stamp photos captured in-app — gallery uploads are external
      // and already carry their own EXIF metadata.
      if (fromCamera) {
        final stamped = await _stampImageWithLoader(outFile);
        if (stamped != null) outFile = stamped;
      }

      // Compress after stamping: the stamp re-encodes via dart:ui, which can
      // only emit PNG, so the compressor is what produces the final JPEG.
      final compressed = await _compressImage(outFile);
      if (compressed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Couldn't process this image — try another photo")));
        }
        continue;
      }
      processed.add(compressed);
    }
    setState(() => _selectedFiles.addAll(processed));
    widget.onFilesChanged(_selectedFiles);
  }
```

Note what is gone: the `ImageCropper().cropImage(...)` call, the `useCircleCrop` variable and
its comment, the `if (cropped == null) continue;` line, and the "try a tighter crop" rejection.

- [ ] **Step 6: Make `_stampImage` write a distinct file and fix its comment**

The stamp still produces PNG bytes (dart:ui can only encode PNG) — `_compressImage` converts
them. Update the comment at lines 220-223 and the output path at line 292.

Replace the comment block:

```dart
  // Decodes the image, draws it onto a Canvas, then renders a subtle dark
  // pill in the bottom-right with timestamp + reverse-geocoded location.
  // Output is written as PNG alongside the source so the cropped circular
  // alpha channel is preserved.
```

with:

```dart
  // Decodes the image, draws it onto a Canvas, then renders a subtle dark
  // pill in the bottom-right with timestamp + reverse-geocoded location.
  // dart:ui can only encode PNG, so this writes a PNG intermediate that
  // _compressImage then re-encodes to JPEG. Never upload this file directly —
  // a 1600px PNG photo routinely exceeds the size ceiling.
```

Line 292 stays as-is:

```dart
    final outFile = File('${source.path}_stamped.png');
```

- [ ] **Step 7: Update the picker's help copy**

Line 68 currently reads:

```dart
const Text("Supports images, PDF, Word, Excel, PowerPoint and .txt\nfile size < 2 Mb", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
```

becomes:

```dart
const Text("Supports images, PDF, Word, Excel, PowerPoint and .txt\nImages are compressed automatically · Documents < 10 MB", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
```

- [ ] **Step 8: Fix the stale comment in `attachment_preview.dart`**

Lines 99-100 read:

```dart
  static Future<Uint8List> _fetchRemoteBytes(String url) async {
    // 20 MB ceiling — well above the 2 MB attachment limit so we never
    // truncate a legitimate file.
```

becomes:

```dart
  static Future<Uint8List> _fetchRemoteBytes(String url) async {
    // 20 MB ceiling — above the 10 MB attachment limit so we never truncate a
    // legitimate file. getData THROWS above its cap, so this must stay strictly
    // larger than _maxBytes in attachment_picker_widget.dart.
```

- [ ] **Step 9: Confirm image_cropper is fully gone**

Run:

```bash
grep -rn "image_cropper\|ImageCropper\|CropAspectRatio\|CropStyle" lib/ pubspec.yaml
```

Expected: no output.

- [ ] **Step 10: Analyze**

Run: `flutter analyze`
Expected: no new issues. If it flags an unused `dart:io` or similar, fix it.

- [ ] **Step 11: Manual verification — run the app**

Run: `flutter run`

Open any record with attachments (e.g. New Non-Compliance → Add Attachment) and confirm:
1. Camera capture → **no crop screen appears**; the stamped photo attaches successfully.
2. Gallery pick of a **large (>5 MB) photo** → attaches successfully (this is the case that
   used to fail).
3. A **>10 MB PDF** → rejected with "File exceeds 10MB".
4. A **~6 MB PDF** → attaches.
5. Save the record, reopen it, and confirm the attachment **previews correctly** (this
   exercises the `attachment_preview` path against the new limit).

- [ ] **Step 12: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/views/widgets/attachment_picker_widget.dart lib/views/widgets/attachment_preview.dart
git commit -m "Auto-compress image attachments and drop mandatory cropping

Replaces image_cropper with flutter_image_compress. The crop step was doing
the compression implicitly; removing it required compression to replace it.
Also fixes the real bloat source: _stampImage encodes via dart:ui, which only
emits PNG, so camera photos exceeded the ceiling after stamping. The compressor
now produces the final JPEG. Documents go from 2MB to 10MB."
```

---

### Task 3: Tappable Flagged card → grouped list screen

**Files:**
- Modify: `lib/views/widgets/flagged_events_overview.dart`
- Modify: `lib/provider/insight_provider.dart` (`:57-61`, `:213-217`, `:257-269`, `:318`)
- Create: `lib/views/insights/flagged_events_screen.dart`
- Modify: `lib/core/utils/routers.dart`
- Modify: `lib/views/insights/insights_screen.dart:183-189`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `FlaggedEventsOverview({..., VoidCallback? onTap})` — new optional named param.
  - `InsightProvider.flaggedEvents` → `List<Map<String, dynamic>>`, each entry being a
    `flaggedEvents` doc's data with its `originId` substituted in as `id`.
  - `FlaggedEventsScreen.routeName` → `'/flagged-events'`.

**Background:** `flaggedEvents` at `users/{uid}/cases/{caseId}/flaggedEvents/{autoId}` already
holds a **full copy** of each flagged record plus `originCollection` / `originId`.
`InsightProvider` already streams it at `:213-217` and derives counts at `:257-269`. This task
retains the docs rather than only counting them.

- [ ] **Step 1: Add `onTap` to the overview card**

In `lib/views/widgets/flagged_events_overview.dart`, add the field and constructor param:

```dart
class FlaggedEventsOverview extends StatelessWidget {
  final int custodyCount;
  final int paymentsCount;
  final int disputesCount;
  final int nonComplianceCount;
  final int totalCount;
  final VoidCallback? onTap;

  const FlaggedEventsOverview({
    super.key,
    required this.custodyCount,
    required this.paymentsCount,
    required this.disputesCount,
    required this.nonComplianceCount,
    required this.totalCount,
    this.onTap,
  });
```

- [ ] **Step 2: Wrap the card in a ripple**

Still in `flagged_events_overview.dart`, the `build` method currently returns the `Container`
directly at line 21. Wrap it, matching the `Material` + `InkWell` pattern the other cards use
(`insights_screen.dart:222-226`). Replace `return Container(` with:

```dart
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
```

and close the two new wrappers at the end of `build` — the existing `);` that closes the
`Container` becomes:

```dart
        ),
      ),
    );
  }
```

Keep the `Container`'s existing `padding`/`decoration`/`child` exactly as they are.

- [ ] **Step 3: Retain the raw flagged docs in `InsightProvider`**

In `lib/provider/insight_provider.dart`, add a field below the flagged counters (after line 61,
`int flaggedNonComplianceCount = 0;`):

```dart
  // Raw flaggedEvents docs backing FlaggedEventsScreen. Each entry is the doc's
  // data with `id` overwritten by `originId` — a flaggedEvents doc's own id is an
  // auto-id, NOT the origin record's, and the detail screens look records up by id.
  List<Map<String, dynamic>> flaggedEvents = [];
```

- [ ] **Step 4: Populate it in the existing calculator**

Replace `_calculateFlaggedInsightsSync` (lines 257-269) with:

```dart
  void _calculateFlaggedInsightsSync(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int tempC = 0; int tempP = 0; int tempD = 0; int tempB = 0;
    final List<Map<String, dynamic>> tempEvents = [];
    for (var doc in docs) {
      final data = doc.data();
      final String origin = data['originCollection'] ?? "";
      if (origin == "paymentRecords") tempP++;
      else if (origin == "disputeRecords") tempD++;
      else if (origin == "nonComplianceRecords") tempB++;
      else tempC++;

      // originId, not doc.id — see the flaggedEvents field comment above.
      tempEvents.add({...data, 'id': data['originId'] ?? doc.id});
    }
    flaggedCustodyCount = tempC; flaggedPaymentsCount = tempP;
    flaggedDisputesCount = tempD; flaggedNonComplianceCount = tempB;
    flaggedEvents = tempEvents;
    notifyListeners();
  }
```

The counting branches are unchanged, including the `else tempC++` catch-all. Building the list
in the same loop keeps the list and the card's counts consistent by construction.

- [ ] **Step 5: Reset it with the other stats**

In `_resetStats()` (line ~318), the flagged line currently reads:

```dart
    flaggedCustodyCount = 0; flaggedPaymentsCount = 0; flaggedDisputesCount = 0; flaggedNonComplianceCount = 0;
```

becomes:

```dart
    flaggedCustodyCount = 0; flaggedPaymentsCount = 0; flaggedDisputesCount = 0; flaggedNonComplianceCount = 0;
    flaggedEvents = [];
```

- [ ] **Step 6: Create the flagged list screen**

Create `lib/views/insights/flagged_events_screen.dart`. This follows the
`custody_compliance_screen.dart` template (F5F5F5 background, `_buildAppBar("Insights")`,
`Consumer`, `RefreshIndicator`, `SingleChildScrollView` with `EdgeInsets.all(20)` and bouncing
physics, `ListView.builder` with `shrinkWrap: true` + `NeverScrollableScrollPhysics`).

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../provider/insight_provider.dart';
import 'custody_detail_screen.dart';
import 'dispute_log_details_screen.dart';
import 'non_compliance_detail_screen.dart';
import 'payment_detail_screen.dart';

class FlaggedEventsScreen extends StatelessWidget {
  static const routeName = '/flagged-events';

  const FlaggedEventsScreen({super.key});

  // Fixed display order. Keys match the `originCollection` field written by the
  // providers that create flagged docs.
  static const List<_FlaggedGroup> _groups = [
    _FlaggedGroup('custodyRecords', 'Custody', Color(0xFF9C27B0)),
    _FlaggedGroup('paymentRecords', 'Payments', Color(0xFF00BFA5)),
    _FlaggedGroup('disputeRecords', 'Disputes', Colors.black87),
    _FlaggedGroup('nonComplianceRecords', 'Non Compliance', Colors.black87),
  ];

  // Mirrors _calculateFlaggedInsightsSync's bucketing, including its catch-all:
  // anything that isn't payment/dispute/nonCompliance counts as custody. Keeping
  // the same rule here is what makes this list agree with the card's counts.
  static String _bucketOf(Map<String, dynamic> e) {
    final origin = e['originCollection'] ?? '';
    if (origin == 'paymentRecords') return 'paymentRecords';
    if (origin == 'disputeRecords') return 'disputeRecords';
    if (origin == 'nonComplianceRecords') return 'nonComplianceRecords';
    return 'custodyRecords';
  }

  static String _routeFor(String bucket) {
    switch (bucket) {
      case 'paymentRecords':
        return PaymentDetailsScreen.routeName;
      case 'disputeRecords':
        return DisputeDetailsScreen.routeName;
      case 'nonComplianceRecords':
        return NonComplianceDetailsScreen.routeName;
      default:
        return CustodyDetailsScreen.routeName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Insights",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F5F5),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<InsightProvider>(
        builder: (context, provider, child) {
          final events = provider.flaggedEvents;
          return RefreshIndicator(
            onRefresh: () async {},
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: events.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Flagged Events",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20)),
                        const SizedBox(height: 4),
                        Text("${events.length} entries requiring attention",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 20),
                        for (final group in _groups)
                          ..._buildGroup(
                            context,
                            group,
                            events
                                .where((e) => _bucketOf(e) == group.key)
                                .toList(),
                          ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.flag_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text("No flagged entries",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text("Flag an entry to see it here.",
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  List<Widget> _buildGroup(
      BuildContext context, _FlaggedGroup group, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(group.label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: group.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text("${items.length}",
                  style: TextStyle(
                      color: group.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, i) => _buildItem(context, group, items[i]),
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _buildItem(
      BuildContext context, _FlaggedGroup group, Map<String, dynamic> event) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        _routeFor(group.key),
        arguments: event,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.flag, color: Colors.orange.shade400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleOf(event, group),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(_dateOf(event),
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Flagged docs are copies of four different record shapes, so there's no single
  // title field. Fall back through the plausible ones, then to the group label.
  String _titleOf(Map<String, dynamic> event, _FlaggedGroup group) {
    for (final key in ['title', 'category', 'type', 'reason', 'description']) {
      final v = event[key];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return group.label;
  }

  String _dateOf(Map<String, dynamic> event) {
    for (final key in ['date', 'createdAt', 'dateTime']) {
      final v = event[key];
      if (v is Timestamp) return DateFormat('d MMM yyyy').format(v.toDate());
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return '';
  }
}

class _FlaggedGroup {
  final String key;
  final String label;
  final Color color;
  const _FlaggedGroup(this.key, this.label, this.color);
}
```

Add the Firestore import for `Timestamp` at the top of the file:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

- [ ] **Step 7: Verify the detail-screen class names compile**

The route constants used above are `PaymentDetailsScreen`, `DisputeDetailsScreen`,
`NonComplianceDetailsScreen`, `CustodyDetailsScreen` — note the plural **`Details`** in the
class names even though the files are singular (`payment_detail_screen.dart`,
`non_compliance_detail_screen.dart`, `custody_detail_screen.dart`). If an import fails, run:

```bash
grep -rn "class .*DetailsScreen" lib/views/insights/
```

and correct the import paths to match.

- [ ] **Step 8: Register the route**

In `lib/core/utils/routers.dart`, add the import:

```dart
import 'package:clearcase/views/insights/flagged_events_screen.dart';
```

and add the route alongside the other insights detail routes (after
`DisputeDetailsScreen.routeName: ...`, around line 63):

```dart
    FlaggedEventsScreen.routeName: (context) => const FlaggedEventsScreen(),
```

- [ ] **Step 9: Wire the card's onTap**

In `lib/views/insights/insights_screen.dart`, lines 183-189 currently read:

```dart
                  FlaggedEventsOverview(
                    custodyCount: insightProvider.flaggedCustodyCount,
                    paymentsCount: insightProvider.flaggedPaymentsCount,
                    disputesCount: insightProvider.flaggedDisputesCount,
                    nonComplianceCount: insightProvider.flaggedNonComplianceCount,
                    totalCount: insightProvider.totalFlaggedCount,
                  ),
```

becomes (null-guarded on `selectedCase`, matching `PaymentOverview` at `:142-152`):

```dart
                  FlaggedEventsOverview(
                    custodyCount: insightProvider.flaggedCustodyCount,
                    paymentsCount: insightProvider.flaggedPaymentsCount,
                    disputesCount: insightProvider.flaggedDisputesCount,
                    nonComplianceCount: insightProvider.flaggedNonComplianceCount,
                    totalCount: insightProvider.totalFlaggedCount,
                    onTap: () {
                      if (insightProvider.selectedCase != null) {
                        Navigator.pushNamed(
                          context,
                          FlaggedEventsScreen.routeName,
                          arguments: insightProvider.selectedCase,
                        );
                      }
                    },
                  ),
```

Add the import at the top of `insights_screen.dart`:

```dart
import 'package:clearcase/views/insights/flagged_events_screen.dart';
```

- [ ] **Step 10: Analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 11: Manual verification**

Run: `flutter run`

1. Create or find a case with at least one flagged entry of **each** type (flag an entry via
   the "Flag this entry" switch on New Custody / New Payment / New Dispute /
   New Non-Compliance).
2. Insights tab → the Flagged Events card **ripples on tap** and opens the list.
3. The per-group counts on the list **equal** the numbers on the card. This is the key check —
   a mismatch means the bucketing diverged.
4. Tap a row in **each** group → the correct detail screen opens showing the **correct
   record** (not a different one). A wrong record here means the `originId` substitution in
   Step 4 isn't working.
5. With a case that has no flagged entries → the empty state renders.

- [ ] **Step 12: Commit**

```bash
git add lib/views/widgets/flagged_events_overview.dart lib/provider/insight_provider.dart lib/views/insights/flagged_events_screen.dart lib/views/insights/insights_screen.dart lib/core/utils/routers.dart
git commit -m "Make Insights Flagged card open a grouped list of flagged entries

flaggedEvents is already a denormalized copy of each flagged record, so this
retains the streamed docs alongside the counts rather than refetching. Rows key
off originId, not the flaggedEvents doc's own auto-id, so detail screens resolve
the origin record."
```

---

### Task 4: Case edit mode — provider

This is the load-bearing task. `submitCase` currently calls `.doc()` with no argument, which
mints a **new** case document on every save. Without the branch below, Task 5's UI would
silently duplicate the user's case instead of editing it.

**Files:**
- Modify: `lib/provider/case_setup_provider.dart` (`:19-23`, `:96-165`)

**Interfaces:**
- Consumes: nothing.
- Produces, all on `CaseSetupProvider`:
  - `bool get isEditing`
  - `void loadExistingCase(CaseModel c)`
  - `Future<void> loadExistingRules(String caseId)`
  - `Map<String, dynamic>? existingRuleFor(String category)`
  - `Future<void> submitCase(BuildContext context)` — signature unchanged, behaviour branches.

- [ ] **Step 1: Make `_caseData` mutable and add edit state**

In `lib/provider/case_setup_provider.dart`, lines 19-23 currently read:

```dart
  // Case Data
  final CaseModel _caseData = CaseModel(
    userId: '', 
    createdAt: DateTime.now(),
    children: [] 
  );
  CaseModel get caseData => _caseData;
```

Replace with (drop `final` so `loadExistingCase` can swap it wholesale):

```dart
  // Case Data. Not final — loadExistingCase() replaces it when the screen is
  // opened for an existing case.
  CaseModel _caseData = CaseModel(
    userId: '',
    createdAt: DateTime.now(),
    children: []
  );
  CaseModel get caseData => _caseData;

  // Non-null when editing an existing case. Drives submitCase's update-vs-create
  // branch — without it, saving an edit creates a duplicate case.
  String? _editingCaseId;
  bool get isEditing => _editingCaseId != null;

  // Existing scheduledRules docs, keyed by lower-cased category, so a wizard
  // re-run edits the current rule instead of overwriting it from blank.
  Map<String, Map<String, dynamic>> _existingRules = {};
  Map<String, dynamic>? existingRuleFor(String category) =>
      _existingRules[category.toLowerCase()];
```

- [ ] **Step 2: Add the hydrate methods**

Add these below `removeChild` (after line 67):

```dart
  // --- EDIT MODE ---

  void loadExistingCase(CaseModel c) {
    _caseData = c;
    _editingCaseId = c.id;
    notifyListeners();
  }

  Future<void> loadExistingRules(String caseId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(caseId)
          .collection('scheduledRules')
          .get();
      _existingRules = {
        for (final doc in snap.docs) doc.id: doc.data(),
      };
      notifyListeners();
    } catch (e) {
      debugPrint('loadExistingRules failed: $e');
    }
  }
```

- [ ] **Step 3: Branch `submitCase` to update instead of create**

In `submitCase`, lines 104-122 currently read:

```dart
      _caseData.userId = user.uid;
      _caseData.createdAt = DateTime.now();

      // 1. Prepare Main Case Data
      Map<String, dynamic> mainCaseData = _caseData.toMap();
      mainCaseData.remove('custodyRule');
      mainCaseData.remove('paymentRule');
      mainCaseData.remove('customRule');

      WriteBatch batch = _firestore.batch();

      // 2. Create Case Document Reference
      DocumentReference caseRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc();

      batch.set(caseRef, mainCaseData);
      _caseData.id = caseRef.id;
```

Replace with:

```dart
      _caseData.userId = user.uid;
      // Only stamp createdAt when creating. On an edit this would silently reset
      // the case's real creation date, since mainCaseData carries it into the
      // merge below.
      if (!isEditing) {
        _caseData.createdAt = DateTime.now();
      }

      // 1. Prepare Main Case Data
      Map<String, dynamic> mainCaseData = _caseData.toMap();
      mainCaseData.remove('custodyRule');
      mainCaseData.remove('paymentRule');
      mainCaseData.remove('customRule');

      WriteBatch batch = _firestore.batch();

      // 2. Case Document Reference — .doc() with no argument mints a NEW doc,
      // so editing must pass the existing id or every save duplicates the case.
      final casesCol = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cases');
      DocumentReference caseRef =
          isEditing ? casesCol.doc(_editingCaseId) : casesCol.doc();

      if (isEditing) {
        batch.set(caseRef, mainCaseData, SetOptions(merge: true));
      } else {
        batch.set(caseRef, mainCaseData);
      }
      _caseData.id = caseRef.id;
```

- [ ] **Step 4: Delete the dead user-doc children write**

Still in `submitCase`, lines 140-148 currently read:

```dart
      // 4. Save Children
      List<Map<String, dynamic>> childrenList = _caseData.children.map((c) => c.toMap()).toList();
      DocumentReference userRef = _firestore.collection('users').doc(user.uid);

      batch.set(
          userRef,
          {'children': FieldValue.arrayUnion(childrenList)},
          SetOptions(merge: true)
      );
```

**Delete that entire block.** It writes children to `users/{uid}`, not the case document, where
nothing reads them. Children already reach the case doc via `_caseData.toMap()`
(`case_model.dart:41`). It is inert today, but under repeated edits it would accumulate
duplicate children on the user document.

- [ ] **Step 5: Pop instead of resetting the nav stack when editing**

Still in `submitCase`, the success navigation (around line 158) reads:

```dart
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: 0);
      }
```

becomes:

```dart
      if (context.mounted) {
        if (isEditing) {
          Navigator.pop(context);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: 0);
        }
      }
```

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: no new issues. `debugPrint` needs `package:flutter/material.dart`, already imported
at line 6.

- [ ] **Step 7: Commit**

```bash
git add lib/provider/case_setup_provider.dart
git commit -m "Add edit mode to CaseSetupProvider

submitCase called .doc() with no argument, minting a new case on every save;
editing now targets the existing doc with merge. Also guards createdAt from
being reset on edit, and drops a dead write that arrayUnion'd children onto the
user document where nothing reads them."
```

---

### Task 5: Case edit mode — screen and calendar dropdown

**Files:**
- Modify: `lib/views/home/case_setup_screen.dart` (`:14-20`, `:58-73`)
- Modify: `lib/core/utils/routers.dart:39`
- Modify: `lib/views/home/calender_screen.dart:150-175`

**Interfaces:**
- Consumes, from Task 4: `CaseSetupProvider.loadExistingCase(CaseModel)`,
  `.loadExistingRules(String)`, `.isEditing`, `.existingRuleFor(String)`.
- Produces: `CaseSetupScreen({CaseModel? existingCase})`.

- [ ] **Step 1: Accept an optional existing case**

In `lib/views/home/case_setup_screen.dart`, lines 14-20 currently read:

```dart
class CaseSetupScreen extends StatefulWidget {
  static const routeName = '/case-setup';
  const CaseSetupScreen({super.key});

  @override
  State<CaseSetupScreen> createState() => _CaseSetupScreenState();
}
```

becomes:

```dart
class CaseSetupScreen extends StatefulWidget {
  static const routeName = '/case-setup';

  /// Non-null opens the wizard in edit mode for an existing case, prefilled with
  /// its details, children, and scheduled rules. Null creates a new case.
  final CaseModel? existingCase;

  const CaseSetupScreen({super.key, this.existingCase});

  @override
  State<CaseSetupScreen> createState() => _CaseSetupScreenState();
}
```

Add the model import at the top of the file:

```dart
import 'package:clearcase/models/case_model.dart';
```

- [ ] **Step 2: Hydrate the provider on create**

Lines 70-72 currently read:

```dart
    return ChangeNotifierProvider(
      create: (_) => CaseSetupProvider(),
      child: Consumer<CaseSetupProvider>(
```

becomes:

```dart
    return ChangeNotifierProvider(
      create: (_) {
        final provider = CaseSetupProvider();
        final existing = widget.existingCase;
        if (existing != null) {
          provider.loadExistingCase(existing);
          // Fire-and-forget: the wizard opens on Step 1 (case details + children),
          // and rules aren't read until Step 2/3, so there's time to load.
          provider.loadExistingRules(existing.id);
        }
        return provider;
      },
      child: Consumer<CaseSetupProvider>(
```

- [ ] **Step 3: Title the app bar for edit mode**

The screen renders `"Case Setup"` in two AppBar branches (lines 83 and 100). In edit mode this
should read `"Edit Case"`. In **both** places, replace:

```dart
                title: const Text("Case Setup", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
```

with:

```dart
                title: Text(provider.isEditing ? "Edit Case" : "Case Setup", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
```

Note `const` moves from the `Text` to the `TextStyle`.

- [ ] **Step 4: Prefill Step 3 from an existing rule**

`_Step3ConfigureRule` builds the rule form. When editing and the selected category already has
a rule, seed the form from it rather than from blank.

Find where `_Step3ConfigureRule` initialises its form state (it reads
`provider.selectedRuleType`). At the top of its `initState` — or, if it has none, in its
`build` before the fields are constructed — add:

```dart
    // In edit mode, seed the form from the case's existing rule for this category
    // so a wizard re-run edits the current config instead of overwriting it from
    // blank. Null (no rule for this category yet) falls through to the defaults.
    final existingRule = widget.provider.isEditing
        ? widget.provider.existingRuleFor(widget.provider.selectedRuleType ?? '')
        : null;
```

then use `existingRule?['<fieldName>'] ?? <existing default>` for each form field's initial
value. The field names are exactly the keys the rule map is saved with — read them from
`_onSaveRule`'s `ruleData` construction in this same file, and mirror them one-for-one.

If `_Step3ConfigureRule` is a `StatelessWidget`, leave it stateless and compute
`existingRule` at the top of `build`.

- [ ] **Step 5: Pass the route argument through**

In `lib/core/utils/routers.dart`, line 39 currently reads:

```dart
    CaseSetupScreen.routeName: (context) => const CaseSetupScreen(),
```

becomes (the builder can no longer be `const`):

```dart
    CaseSetupScreen.routeName: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return CaseSetupScreen(existingCase: args is CaseModel ? args : null);
    },
```

`CaseModel` is already imported in this file (used by the `RuleConfigurationScreen` builder's
`ChildModel` cast). If analyze reports it missing, add:

```dart
import 'package:clearcase/models/case_model.dart';
```

- [ ] **Step 6: Add the "Add Child" sentinel to the calendar dropdown**

In `lib/views/home/calender_screen.dart`, the `items:` list at lines 150-165 currently reads:

```dart
                          items: [
                            ...provider.allCases.map((caseItem) => DropdownMenuItem<String>(
                              value: caseItem.id, // Value is the ID
                              child: Text(
                                provider.getCaseDisplayName(caseItem),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            )),
                            const DropdownMenuItem<String>(
                              value: "add_new",
                              child: Text(
                                "Add New Case",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                              ),
                            ),
                          ],
```

becomes — "Add Child" primary (bold, brand purple, with an icon), "Add New Case" demoted to
plain grey:

```dart
                          items: [
                            ...provider.allCases.map((caseItem) => DropdownMenuItem<String>(
                              value: caseItem.id, // Value is the ID
                              child: Text(
                                provider.getCaseDisplayName(caseItem),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            )),
                            // Sentinels MUST stay after the real cases: selectedItemBuilder
                            // above only returns allCases.length entries, and the dropdown
                            // indexes into it by the selected item's position. Cases occupy
                            // 0..n-1, so their indices still line up; putting a sentinel
                            // first would shift them and render the wrong label.
                            if (provider.selectedCase != null)
                              const DropdownMenuItem<String>(
                                value: "add_child",
                                child: Row(
                                  children: [
                                    Icon(Icons.person_add, size: 18, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text(
                                      "Add Child",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                            const DropdownMenuItem<String>(
                              value: "add_new",
                              child: Text(
                                "Add New Case",
                                style: TextStyle(fontWeight: FontWeight.normal, fontSize: 15, color: Colors.grey),
                              ),
                            ),
                          ],
```

`AppColors` is imported in this file already; if analyze says otherwise, add:

```dart
import 'package:clearcase/core/theme/app_colors.dart';
```

- [ ] **Step 7: Handle the new sentinel**

Lines 166-174 currently read:

```dart
                          onChanged: (value) {
                            if (value == "add_new") {
                              Navigator.pushNamed(context, CaseSetupScreen.routeName);
                            } else if (value != null) {
                              // Find the actual object by the ID string
                              final selected = provider.allCases.firstWhere((c) => c.id == value);
                              provider.setSelectedCase(selected);
                            }
                          },
```

becomes:

```dart
                          onChanged: (value) {
                            if (value == "add_child") {
                              // Opens the wizard in edit mode on the selected case, so
                              // Step 1 lands on the children list where they were added.
                              Navigator.pushNamed(
                                context,
                                CaseSetupScreen.routeName,
                                arguments: provider.selectedCase,
                              );
                            } else if (value == "add_new") {
                              Navigator.pushNamed(context, CaseSetupScreen.routeName);
                            } else if (value != null) {
                              // Find the actual object by the ID string
                              final selected = provider.allCases.firstWhere((c) => c.id == value);
                              provider.setSelectedCase(selected);
                            }
                          },
```

- [ ] **Step 8: Analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 9: Manual verification — the duplicate-case check is the critical one**

Run: `flutter run`

1. Settings → **note the current number of cases**. This is the baseline for step 4.
2. Calendar → with **no case selected**, open the dropdown → "Add Child" is **absent**;
   "Add New Case" is present.
3. Select a case → dropdown → "Add Child" appears above "Add New Case", bold and purple;
   "Add New Case" is plain grey. Selecting an actual case still switches the calendar to it
   and shows the correct name in the closed dropdown (this checks the `selectedItemBuilder`
   index alignment from Step 6).
4. Tap "Add Child" → the wizard opens titled **"Edit Case"** on Step 1, prefilled with the
   case number, legal rep, and **existing children**. Add a child → "Skip Rules For Now" on
   Step 2 → it saves and pops back.
5. **Settings → the case count is UNCHANGED** and the new child appears under the existing
   case. A count that went up by one means `submitCase`'s edit branch isn't firing — stop and
   fix Task 4 Step 3.
6. In the Firebase console, open the edited case doc → **`createdAt` is unchanged**, and
   `children` contains both old and new children exactly once.
7. Re-enter "Add Child" and this time walk Steps 2→3 for a category that **already has a
   rule** → the rule form is **prefilled with the existing config**, not blank. Save → the
   rule is updated, not wiped.
8. "Add New Case" still creates a brand-new case (regression check on the create path).

- [ ] **Step 10: Commit**

```bash
git add lib/views/home/case_setup_screen.dart lib/views/home/calender_screen.dart lib/core/utils/routers.dart
git commit -m "Add 'Add Child' as the primary calendar dropdown action

Opens the case wizard in edit mode on the selected case, prefilled with its
children and existing scheduled rules. 'Add New Case' is demoted to secondary.
The sentinels stay after the real cases because selectedItemBuilder indexes by
item position."
```

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| Task 1 — compression, crop removal, 10 MB docs, copy, stale preview comment | Task 2 |
| Task 2 — dropdown hierarchy, edit mode, submitCase branch, createdAt guard, dead write, nav | Tasks 4 + 5 |
| Task 3 — onTap, provider retention, new screen, originId, route table | Task 3 |
| Task 4 — four renames | Task 1 |
| Testing (manual, per task) | every task's verification step |

No spec requirement is unassigned.

**Known soft spot:** Task 5 Step 4 (prefilling Step 3's rule form) is the only step that can't
name exact field names, because they're constructed inline in `_onSaveRule`'s `ruleData` and
vary per category. The step tells the implementer to read them from that construction and
mirror them one-for-one. If that proves ambiguous during execution, stop and read
`_Step3ConfigureRule` in full before guessing.

**Type consistency:** `flaggedEvents` is `List<Map<String, dynamic>>` in Task 3 Steps 3, 4, 5
and consumed as such in Step 6. `existingRuleFor(String)` returns `Map<String, dynamic>?` in
Task 4 Step 1 and is consumed that way in Task 5 Step 4. `loadExistingCase(CaseModel)` /
`loadExistingRules(String)` match their Task 5 Step 2 call sites. Detail screen class names are
plural (`PaymentDetailsScreen`) against singular filenames — flagged explicitly in Task 3
Step 7.
