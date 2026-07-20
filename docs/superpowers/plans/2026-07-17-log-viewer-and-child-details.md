# Dispute Log Viewer & Child Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give dispute logs a real full-screen, swipeable reading view with edit/delete, and add school/address to each child so the generated PDF cover page carries per-child details.

**Architecture:** Feature 1 promotes an existing inline master/detail swap into a proper pushed route backed by a `PageView`, which lets a pile of faked back-navigation machinery be deleted from a 549-line file. Feature 2 extends `ChildModel` (an embedded array on the case doc, so no migration) and restructures the PDF cover's joined rows into per-child blocks.

**Tech Stack:** Flutter 3.35.5 (SDK floor `^3.9.2`), Provider, Cloud Firestore (named database `clearcase`), Firebase Storage, `pdf` package.

**Source spec:** `docs/superpowers/specs/2026-07-17-log-viewer-and-child-details-design.md`

## Global Constraints

- **DO NOT COMMIT and DO NOT STASH.** All work stays uncommitted on `main` by explicit user instruction. Never run `git add`, `git commit`, `git stash`, or `git checkout`. The working tree already contains a completed, reviewed 5-task batch plus this work. A stash would destroy it.
- **Read the CURRENT working-tree state of every file**, not `git show HEAD:<file>`. `case_setup_screen.dart` and `case_setup_provider.dart` were changed by the uncommitted batch; HEAD is stale.
- **No test suite exists.** `flutter test` fails on the stock counter template in `test/widget_test.dart`. Do not add tests; do not fix that file. The gate for every task is `flutter analyze`.
- **`flutter analyze` baseline: 136 issues, 0 errors.** Every task must end at 0 errors and add no new warnings.
- **Firestore access is ALWAYS via the named database:** `FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase')`. Never plain `FirebaseFirestore.instance` — it silently reads an empty default database.
- **New code uses `.withValues(alpha: x)`**, never the deprecated `.withOpacity(x)`.
- `legalRep` and `caseNumber` stay **case-level**. Do not add them to `ChildModel`.
- A child's `id` must never change on edit. It is referenced by `pdf_generator.dart:168` (`options.childIds.contains(c.id)`), `pdf_generator.dart:44-46` (`event.childIds`), and rule docs' `appliedChildren`.

## File Structure

| File | Change | Task |
|---|---|---|
| `lib/views/widgets/dispute_log_dialog.dart` | **Create** — extracted add/edit log dialog | 1 |
| `lib/views/insights/dispute_log_details_screen.dart` | Modify — use extracted dialog; then strip master/detail | 1, 2 |
| `lib/views/insights/dispute_log_viewer_screen.dart` | **Create** — full-screen PageView viewer | 2 |
| `lib/core/utils/routers.dart` | Modify — register viewer route | 2 |
| `lib/models/case_model.dart` | Modify — ChildModel gains school/address | 3 |
| `lib/provider/case_setup_provider.dart` | Modify — addChild signature, new updateChild | 3 |
| `lib/views/home/case_setup_screen.dart` | Modify — Step 1 fields + tap-to-edit | 4 |
| `lib/views/widgets/pdf_generator.dart` | Modify — per-child cover blocks | 5 |

Task 1 must precede Task 2 (Task 2's viewer uses the extracted dialog). Task 3 must precede Tasks 4 and 5 (both consume the new fields). Otherwise independent.

---

### Task 1: Extract the log dialog into a shared widget

Pure refactor — no behaviour change. Task 2's viewer needs this dialog too, and it is ~165 lines; duplicating it would be a defect.

**Files:**
- Create: `lib/views/widgets/dispute_log_dialog.dart`
- Modify: `lib/views/insights/dispute_log_details_screen.dart` (delete `_showLogDialog` at `:301-409` and `_buildExistingFilePreview` at `:411-464`; update 2 call sites at `:153` and `:204`)

**Interfaces:**
- Consumes: `DisputeInsightsProvider.saveLog({required String caseId, required String disputeId, String? logId, required String title, required String desc, required List<File> files, required List<String> remainingUrls})` — existing, at `dispute_insight_provider.dart:398-431`.
- Produces: `Future<bool?> showDisputeLogDialog(BuildContext context, {required String caseId, required String disputeId, Map<String, dynamic>? existingLog})` — resolves `true` if a log was saved, `null`/`false` otherwise.

**Why the signature changes:** the current `_showLogDialog` reaches into the host screen's `setState(() => _isLoading = true)` (`:380`, `:395`) and `_showStatus` (`:391`, `:393`). Neither exists outside that screen, so the extracted dialog must own its busy state. It shows a spinner on its own save button instead of the host's full-screen overlay, and shows its own snackbar.

- [ ] **Step 1: Create the extracted dialog**

Create `lib/views/widgets/dispute_log_dialog.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/dispute_insight_provider.dart';
import 'attachment_picker_widget.dart';
import 'attachment_preview.dart';
import 'file_type_icon.dart';
import 'custom_text_field.dart';

/// Add/edit dialog for a dispute log. Shared by DisputeDetailsScreen (list rows
/// and "Add New Log") and DisputeLogViewerScreen (full-screen reader).
///
/// Owns its own busy state: it is used from two different screens, so it cannot
/// reach into a host's `_isLoading`. Resolves true when a log was saved.
Future<bool?> showDisputeLogDialog(
  BuildContext context, {
  required String caseId,
  required String disputeId,
  Map<String, dynamic>? existingLog,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _DisputeLogDialog(
      caseId: caseId,
      disputeId: disputeId,
      existingLog: existingLog,
    ),
  );
}

class _DisputeLogDialog extends StatefulWidget {
  final String caseId;
  final String disputeId;
  final Map<String, dynamic>? existingLog;

  const _DisputeLogDialog({
    required this.caseId,
    required this.disputeId,
    this.existingLog,
  });

  @override
  State<_DisputeLogDialog> createState() => _DisputeLogDialogState();
}

class _DisputeLogDialogState extends State<_DisputeLogDialog> {
  late final TextEditingController _titleC;
  late final TextEditingController _descC;
  final FocusNode _titleNode = FocusNode();
  final FocusNode _descNode = FocusNode();

  List<File> _newFiles = [];
  late List<String> _currentUrls;
  bool _isSaving = false;

  bool get _isEdit => widget.existingLog != null;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController(text: widget.existingLog?['title']);
    _descC = TextEditingController(text: widget.existingLog?['description']);
    _currentUrls = widget.existingLog != null
        ? List<String>.from(widget.existingLog!['attachments'] ?? [])
        : [];
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _titleNode.dispose();
    _descNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<DisputeInsightsProvider>(context, listen: false);
    try {
      await provider.saveLog(
        caseId: widget.caseId,
        disputeId: widget.disputeId,
        logId: widget.existingLog?['id'],
        title: _titleC.text,
        desc: _descC.text,
        files: _newFiles,
        remainingUrls: _currentUrls,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? "Log updated" : "Log added")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(const SnackBar(content: Text("Error saving log")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(_isEdit ? "Edit Log" : "New Log",
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(labelText: "Log Title", controller: _titleC, node: _titleNode),
            const SizedBox(height: 10),
            CustomTextField(labelText: "Description", maxLines: 3, controller: _descC, node: _descNode),
            const SizedBox(height: 15),
            const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold)),
            if (_currentUrls.isNotEmpty) const SizedBox(height: 5),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _currentUrls
                  .map((url) => _buildExistingFilePreview(url, () {
                        setState(() => _currentUrls.remove(url));
                      }))
                  .toList(),
            ),
            const SizedBox(height: 5),
            AttachmentPickerWidget(onFilesChanged: (f) {
              setState(() => _newFiles = f);
            }),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: _buttonStyle(),
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: _buttonStyle(),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? "Update log" : "Add log",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }

  ButtonStyle _buttonStyle() => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7B2CBF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  Widget _buildExistingFilePreview(String url, VoidCallback onDelete) {
    final ext = extensionFromUrl(url);
    final isImage = isImageExtension(ext);
    final typeInfo = fileTypeFromExtension(ext);

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: GestureDetector(
            onTap: () => AttachmentPreview.openUrl(context, url),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => FileTypeTile(info: typeInfo),
                      ),
                    )
                  : FileTypeTile(info: typeInfo),
            ),
          ),
        ),
        GestureDetector(
          onTap: onDelete,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Delete the originals from the details screen**

In `lib/views/insights/dispute_log_details_screen.dart`, delete the entire `_showLogDialog` method (`:301-409`) and the entire `_buildExistingFilePreview` method (`:411-464`). Nothing else uses them.

- [ ] **Step 3: Point both call sites at the extracted dialog**

Line 153 (the list row's edit button):

```dart
IconButton(icon: const Icon(Icons.edit, color: Colors.black, size: 20), onPressed: () => _showLogDialog(cId, dId, existingLog: log)),
```

becomes:

```dart
IconButton(icon: const Icon(Icons.edit, color: Colors.black, size: 20), onPressed: () => showDisputeLogDialog(context, caseId: cId, disputeId: dId, existingLog: log)),
```

Line 204 ("Add New Log"):

```dart
_btn("Add New Log", const Color(0xFF4A148C), () => _showLogDialog(cId, dId)),
```

becomes:

```dart
_btn("Add New Log", const Color(0xFF4A148C), () => showDisputeLogDialog(context, caseId: cId, disputeId: dId)),
```

- [ ] **Step 4: Fix imports**

Add to `dispute_log_details_screen.dart`:

```dart
import '../widgets/dispute_log_dialog.dart';
```

Then remove any import that is now unused. After deleting the two methods, these are likely orphaned in `dispute_log_details_screen.dart`: `dart:io` (was for `List<File>`), `attachment_picker_widget.dart`, `file_type_icon.dart`, and possibly `attachment_preview.dart` and `custom_text_field.dart`. **Do not guess** — run `flutter analyze` and remove exactly what it reports as unused. `attachment_thumbnail.dart` is still used by `_buildDetailView` and must stay for now.

- [ ] **Step 5: Analyze**

Run: `flutter analyze`
Expected: 0 errors, no new warnings, no `unused_import` in the touched files.

- [ ] **Step 6: Verify no behaviour drift**

Confirm by reading: the dialog still writes via the same `saveLog` call with the same named arguments, still passes `logId: existingLog?['id']` (null for add), and still passes `remainingUrls` so `deleteOrphanedStorageUrls` prunes removed attachments.

**Do NOT commit** (see Global Constraints).

---

### Task 2: Full-screen swipeable log viewer

**Files:**
- Create: `lib/views/insights/dispute_log_viewer_screen.dart`
- Modify: `lib/core/utils/routers.dart`
- Modify: `lib/views/insights/dispute_log_details_screen.dart` — delete `_selectedLogIndex` (`:22`), the ternary swap (`:96-98`), `_buildDetailView` (`:163-195`), `_buildDetailNavButtons` (`:542-549`), the `PopScope` (`:53-55`), and the custom AppBar `leading` (`:60-63`); change the row `onTap` (`:147`)

**Interfaces:**
- Consumes: `showDisputeLogDialog(context, {caseId, disputeId, existingLog})` from Task 1. `DisputeInsightsProvider.getDisputeLogs(String caseId, String disputeId)` → `Stream<List<Map<String, dynamic>>>`, ordered `createdAt descending`, each map carrying an injected `'id'` (`dispute_insight_provider.dart:391-396`). `DisputeInsightsProvider.deleteLogWithStorage(String caseId, String disputeId, Map<String, dynamic> log)` (`:455-462`).
- Produces: `DisputeLogViewerScreen.routeName` → `'/dispute-log-viewer'`, taking a `Map<String, dynamic>` argument with keys `caseId` (String), `disputeId` (String), `initialIndex` (int), `isClosed` (bool), `party` (String).

**Why it streams rather than takes a list:** an edit made inside the viewer must be visible immediately. A static list passed as an argument cannot update, so the viewer subscribes to the same stream the list screen uses.

- [ ] **Step 1: Create the viewer screen**

Create `lib/views/insights/dispute_log_viewer_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../provider/dispute_insight_provider.dart';
import '../widgets/attachment_thumbnail.dart';
import '../widgets/dispute_log_dialog.dart';

/// Full-screen reader for a dispute's logs. Swipe or use Previous/Next to move
/// between entries; the whole entry is readable without expanding anything.
///
/// Subscribes to the logs stream itself rather than taking a static list, so an
/// edit made here reflects immediately without backing out and reopening.
class DisputeLogViewerScreen extends StatefulWidget {
  static const routeName = '/dispute-log-viewer';

  const DisputeLogViewerScreen({super.key});

  @override
  State<DisputeLogViewerScreen> createState() => _DisputeLogViewerScreenState();
}

class _DisputeLogViewerScreenState extends State<DisputeLogViewerScreen> {
  PageController? _controller;
  int _currentPage = 0;
  bool _isInit = true;

  late String _caseId;
  late String _disputeId;
  late bool _isClosed;
  late String _party;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _caseId = args['caseId'] as String;
      _disputeId = args['disputeId'] as String;
      _isClosed = args['isClosed'] as bool? ?? false;
      _party = args['party'] as String? ?? "";
      _currentPage = args['initialIndex'] as int? ?? 0;
      _controller = PageController(initialPage: _currentPage);
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _controller?.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> log, int total) async {
    final String title = log['title'] ?? "Untitled Log";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Delete Log",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        content: Text('Are you sure you want to delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final provider = Provider.of<DisputeInsightsProvider>(context, listen: false);
    // Deleting the only log leaves nothing to read — leave the viewer.
    if (total <= 1) navigator.pop();
    await provider.deleteLogWithStorage(_caseId, _disputeId, log);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DisputeInsightsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.getDisputeLogs(_caseId, _disputeId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text("Error loading logs"));
          }

          final logs = snap.data ?? [];
          if (logs.isEmpty) {
            return const Center(child: Text("No logs to display."));
          }

          // A deletion shrinks the list under us — never index past the end.
          final safePage = _currentPage.clamp(0, logs.length - 1);
          if (safePage != _currentPage) {
            _currentPage = safePage;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _controller?.hasClients == true) {
                _controller!.jumpToPage(safePage);
              }
            });
          }

          final currentLog = logs[safePage];

          return SafeArea(
            child: Column(
              children: [
                _buildAppBar(logs, safePage, currentLog),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: logs.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) => _buildLogPage(logs[index]),
                  ),
                ),
                _buildNavBar(logs.length, safePage),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(List<Map<String, dynamic>> logs, int page, Map<String, dynamic> currentLog) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              "Log ${page + 1} of ${logs.length}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (!_isClosed) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              tooltip: "Edit log",
              onPressed: () => showDisputeLogDialog(
                context,
                caseId: _caseId,
                disputeId: _disputeId,
                existingLog: currentLog,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: "Delete log",
              onPressed: () => _confirmDelete(currentLog, logs.length),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogPage(Map<String, dynamic> log) {
    final List<String> attachments =
        (log['attachments'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(log['title'] ?? "",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 5),
            Text(
              log['createdAt'] != null
                  ? DateFormat('dd MMM yyyy hh:mm a')
                      .format((log['createdAt'] as Timestamp).toDate())
                  : "",
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text("Related Party",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text(_party, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 20),
            Text(log['description'] ?? "", style: const TextStyle(fontSize: 16, height: 1.5)),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text("Attachments",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  itemBuilder: (context, index) => AttachmentThumbnail(url: attachments[index]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(int total, int page) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: _navBtn("Previous", page > 0 ? () => _goToPage(page - 1) : null)),
          const SizedBox(width: 12),
          Expanded(child: _navBtn("Next", page < total - 1 ? () => _goToPage(page + 1) : null)),
        ],
      ),
    );
  }

  Widget _navBtn(String label, VoidCallback? onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A148C),
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 0,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
```

- [ ] **Step 2: Register the route**

In `lib/core/utils/routers.dart`, add the import:

```dart
import 'package:clearcase/views/insights/dispute_log_viewer_screen.dart';
```

and register alongside the other insights routes:

```dart
    DisputeLogViewerScreen.routeName: (context) => const DisputeLogViewerScreen(),
```

- [ ] **Step 3: Push the viewer from the log row**

In `dispute_log_details_screen.dart`, the row `onTap` at line 147:

```dart
onTap: () => setState(() => _selectedLogIndex = entry.key),
```

becomes:

```dart
onTap: () => Navigator.pushNamed(
  context,
  DisputeLogViewerScreen.routeName,
  arguments: {
    'caseId': cId,
    'disputeId': dId,
    'initialIndex': entry.key,
    'isClosed': isClosed,
    'party': party,
  },
),
```

Add the import:

```dart
import 'dispute_log_viewer_screen.dart';
```

- [ ] **Step 4: Delete the inline master/detail machinery**

Still in `dispute_log_details_screen.dart`, remove all of the following:

1. The field at line 22: `int? _selectedLogIndex;`
2. The `PopScope` wrapper (`:53-55`). The `Scaffold` becomes the direct child of the `Stack`'s first slot — keep the `Stack` and the `_isLoading` overlay at `:111`, which is still used by close/reopen.
3. The custom AppBar `leading` (`:60-63`). Deleting it restores the default back button, which now works correctly because the detail view is a real route.
4. The ternary at `:96-98`:
   ```dart
   _selectedLogIndex == null
       ? _buildListView(logs, isClosed, cId, dId)
       : _buildDetailView(logs[_selectedLogIndex!], isClosed),
   ```
   becomes:
   ```dart
   _buildListView(logs, isClosed, cId, dId),
   ```
5. The whole `_buildDetailView` method (`:163-195`).
6. In `_buildBottomActionArea` (`:197-216`), the `_selectedLogIndex != null ? _buildDetailNavButtons(logs.length) : ...` ternary collapses to just the `Column`:
   ```dart
   Widget _buildBottomActionArea(bool isClosed, DisputeInsightsProvider prov, String cId, String dId, List logs) {
     return Container(
       padding: const EdgeInsets.all(20),
       child: Column(children: [
         if (!isClosed) ...[
           _btn("Add New Log", const Color(0xFF4A148C), () => showDisputeLogDialog(context, caseId: cId, disputeId: dId)),
           const SizedBox(height: 20),
           _btn("Close Dispute", Colors.redAccent, () => _confirmClose(cId, dId, prov)),
         ] else
           _btn("Reopen Dispute", Colors.green, () async {
             setState(() => _isLoading = true);
             await prov.updateDisputeStatus(cId, dId, "Open");
             setState(() => _isLoading = false);
             _showStatus("Dispute Reopened");
           }),
       ]),
     );
   }
   ```
7. The `_buildDetailNavButtons` method (around `:542-549`) — now unreferenced.

`_confirmDelete` and the row edit/delete buttons **stay**. Removing them would be a regression.

- [ ] **Step 5: Clean up imports**

`attachment_thumbnail.dart` was used only by the deleted `_buildDetailView` and is likely now unused in `dispute_log_details_screen.dart`. Run `flutter analyze` and remove exactly what it reports.

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: 0 errors, no new warnings, no `unused_import` or `unused_element` in the touched files.

- [ ] **Step 7: Confirm the file shrank**

Run: `wc -l lib/views/insights/dispute_log_details_screen.dart`
Expected: meaningfully fewer than the original 549 lines (roughly 250-300 after Tasks 1 and 2 combined).

**Do NOT commit** (see Global Constraints).

---

### Task 3: `ChildModel` gains school and address

**Files:**
- Modify: `lib/models/case_model.dart` (`ChildModel`, around `:83-105`)
- Modify: `lib/provider/case_setup_provider.dart` (`addChild`; add `updateChild`)

**Interfaces:**
- Produces:
  - `ChildModel({required String id, required String name, required DateTime dob, String? school, String? address})` with `school`/`address` as mutable nullable fields.
  - `CaseSetupProvider.addChild(String name, DateTime dob, {String? school, String? address})` — note the added optional named params; the existing 2-positional-arg call site keeps working unchanged.
  - `CaseSetupProvider.updateChild(String id, {required String name, required DateTime dob, String? school, String? address})` — mutates in place, preserving `id`.

**Why nullable:** every existing child document in Firestore has neither field. Keep null distinct from empty string so the PDF can render "—" for genuinely absent data.

- [ ] **Step 1: Extend `ChildModel`**

In `lib/models/case_model.dart`, the `ChildModel` class currently reads:

```dart
class ChildModel {
  String id;
  String name;
  DateTime dob;

  ChildModel({required this.id, required this.name, required this.dob});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'dob': Timestamp.fromDate(dob)};
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    return ChildModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      dob: (map['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
```

Replace with:

```dart
class ChildModel {
  String id;
  String name;
  DateTime dob;
  // Nullable: children created before these fields existed have neither. Null
  // means "never entered" and renders as "—" on the report; don't coerce to ''.
  String? school;
  String? address;

  ChildModel({
    required this.id,
    required this.name,
    required this.dob,
    this.school,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dob': Timestamp.fromDate(dob),
      'school': school,
      'address': address,
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    return ChildModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      dob: (map['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
      school: map['school'] as String?,
      address: map['address'] as String?,
    );
  }
}
```

- [ ] **Step 2: Accept school/address when adding a child**

In `lib/provider/case_setup_provider.dart`, `addChild` currently reads (around `:109-116`):

```dart
  void addChild(String name, DateTime dob) {
    _caseData.children.add(ChildModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      dob: dob,
    ));
    notifyListeners();
  }
```

Replace with:

```dart
  void addChild(String name, DateTime dob, {String? school, String? address}) {
    _caseData.children.add(ChildModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      dob: dob,
      school: school,
      address: address,
    ));
    notifyListeners();
  }
```

Optional named params keep the existing `addChild(name, dob)` call site compiling unchanged.

- [ ] **Step 3: Add `updateChild`**

Add directly below `addChild`:

```dart
  /// Edits a child in place. The id is deliberately preserved: it is referenced
  /// by the PDF export filter (options.childIds), by event.childIds, and by the
  /// scheduledRules docs' appliedChildren. Delete-and-re-add would mint a new id
  /// (addChild uses millisecondsSinceEpoch) and silently break all three.
  void updateChild(
    String id, {
    required String name,
    required DateTime dob,
    String? school,
    String? address,
  }) {
    final index = _caseData.children.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final child = _caseData.children[index];
    child.name = name;
    child.dob = dob;
    child.school = school;
    child.address = address;
    notifyListeners();
  }
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze`
Expected: 0 errors. `ChildModel`'s other construction sites pass only `id`/`name`/`dob` and still compile because `school`/`address` are optional. Verify by grepping:

Run: `grep -rn "ChildModel(" lib/ | grep -v "fromMap"`
Expected: every hit either compiles unchanged or is in `case_setup_provider.dart`. Known sites include `calender_provider.dart:582` (`orElse: () => ChildModel(id:'', name:'Unknown', dob: DateTime.now())`), `payment_detail_screen.dart`, and `custody_detail_screen.dart` — all fine.

- [ ] **Step 5: Confirm the known-untouched path**

`RuleConfigurationProvider.addChild` (`rule_configuration_provider.dart:161-180`) builds a raw `{'id','name','dob'}` map, not a `ChildModel`, and writes only to `scheduledRules/{category}.appliedChildren`. It will not carry school/address. **This is expected and out of scope** — it is dead code (its only call site is commented out at `rule_configuration_screen.dart:187`). Do not modify or revive it.

**Do NOT commit** (see Global Constraints).

---

### Task 4: Step 1 — school/address fields and tap-to-edit

**Files:**
- Modify: `lib/views/home/case_setup_screen.dart` — `_Step1FormState` (around `:307-380`)

**Interfaces:**
- Consumes, from Task 3: `CaseSetupProvider.addChild(String name, DateTime dob, {String? school, String? address})`, `CaseSetupProvider.updateChild(String id, {required String name, required DateTime dob, String? school, String? address})`, and `ChildModel`'s `school`/`address` fields.

**Read the CURRENT working-tree version of this file** — the uncommitted batch changed it (it now takes `existingCase` and has edit-mode handling).

- [ ] **Step 1: Add controllers for the new fields**

In `_Step1FormState`, the controllers currently read (around `:308-315`):

```dart
  late TextEditingController _caseNumCtrl;
  late TextEditingController _legalRepCtrl;
  final TextEditingController _nameCtrl = TextEditingController();
  FocusNode caseNumNode = FocusNode();
  FocusNode legalRepNode = FocusNode();
  FocusNode nameNode = FocusNode();

  DateTime? _selectedDate;
```

Add school/address controllers and nodes:

```dart
  late TextEditingController _caseNumCtrl;
  late TextEditingController _legalRepCtrl;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  FocusNode caseNumNode = FocusNode();
  FocusNode legalRepNode = FocusNode();
  FocusNode nameNode = FocusNode();
  FocusNode schoolNode = FocusNode();
  FocusNode addressNode = FocusNode();

  DateTime? _selectedDate;
```

And dispose them — `dispose` currently reads:

```dart
  @override
  void dispose() {
    _caseNumCtrl.dispose(); _legalRepCtrl.dispose(); _nameCtrl.dispose(); super.dispose();
  }
```

becomes:

```dart
  @override
  void dispose() {
    _caseNumCtrl.dispose();
    _legalRepCtrl.dispose();
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _addressCtrl.dispose();
    schoolNode.dispose();
    addressNode.dispose();
    super.dispose();
  }
```

- [ ] **Step 2: Pass school/address when adding**

`_addChild` currently reads (around `:326-335`):

```dart
  void _addChild() {
    if (_nameCtrl.text.trim().isEmpty || _selectedDate == null) {
      showSnackBar(context, "Enter Child Name and DOB");
      return;
    }
    widget.provider.addChild(_nameCtrl.text, _selectedDate!);
    _nameCtrl.clear();
    setState(() => _selectedDate = null);
    FocusScope.of(context).unfocus();
  }
```

becomes — school/address stay optional, so validation is unchanged; blank input is stored as null, not empty string:

```dart
  void _addChild() {
    if (_nameCtrl.text.trim().isEmpty || _selectedDate == null) {
      showSnackBar(context, "Enter Child Name and DOB");
      return;
    }
    widget.provider.addChild(
      _nameCtrl.text,
      _selectedDate!,
      school: _emptyToNull(_schoolCtrl.text),
      address: _emptyToNull(_addressCtrl.text),
    );
    _nameCtrl.clear();
    _schoolCtrl.clear();
    _addressCtrl.clear();
    setState(() => _selectedDate = null);
    FocusScope.of(context).unfocus();
  }

  // Blank input means "not provided" — keep it null so the report shows "—"
  // rather than an empty row.
  static String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();
```

- [ ] **Step 3: Add the two fields to the add form**

The add form currently ends with the name field, DOB picker, and Add button (around `:362-376`). Insert School and Address between the DOB picker and the "Add New Child" button. Locate:

```dart
        const SizedBox(height: 16),
        CustomSecondaryButton(text: 'Add New Child', onPressed: _addChild ),
```

and replace with:

```dart
        const SizedBox(height: 15),
        CustomTextField(labelText: "School", hintText: "eg. Springfield Primary", controller: _schoolCtrl, node: schoolNode, nextNode: addressNode),
        const SizedBox(height: 15),
        CustomTextField(labelText: "Address", hintText: "eg. 12 Oak Street", controller: _addressCtrl, node: addressNode),
        const SizedBox(height: 16),
        CustomSecondaryButton(text: 'Add New Child', onPressed: _addChild ),
```

Also chain the name field's focus into school. The name field currently reads:

```dart
        CustomTextField(labelText: "Child Name", hintText: "Enter name", controller: _nameCtrl, node: nameNode),
```

becomes:

```dart
        CustomTextField(labelText: "Child Name", hintText: "Enter name", controller: _nameCtrl, node: nameNode, nextNode: schoolNode),
```

- [ ] **Step 4: Show school/address in the child tiles, and make them tappable**

The child list tile currently reads (around `:350-360`):

```dart
        ...widget.provider.caseData.children.map((c) => 
        Card(elevation: 0, 
        color: Colors.white, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.grey.shade200)), 
        child: ListTile(visualDensity: VisualDensity.compact,contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), leading: CircleAvatar(backgroundColor: Colors.purple.shade50, 
        child: const Icon(Icons.person, color: Colors.purple)), 
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
        subtitle: Text(DateFormat('d MMM yyyy').format(c.dob)),
         trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), 
         onPressed: () => widget.provider.removeChild(c.id)),),)),
```

Replace with:

```dart
        ...widget.provider.caseData.children.map((c) => Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                onTap: () => _showEditChildDialog(c),
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade50,
                  child: const Icon(Icons.person, color: Colors.purple),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_childSubtitle(c)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => widget.provider.removeChild(c.id),
                ),
              ),
            )),
```

Add the subtitle helper to `_Step1FormState`:

```dart
  // DOB, plus school and address when present. A child with neither reads
  // exactly as it did before these fields existed.
  String _childSubtitle(ChildModel c) {
    final parts = <String>[DateFormat('d MMM yyyy').format(c.dob)];
    if (c.school != null && c.school!.trim().isNotEmpty) parts.add(c.school!.trim());
    if (c.address != null && c.address!.trim().isNotEmpty) parts.add(c.address!.trim());
    return parts.join(' · ');
  }
```

- [ ] **Step 5: Add the edit dialog**

Add to `_Step1FormState`:

```dart
  // Editing must preserve the child's id — see CaseSetupProvider.updateChild.
  void _showEditChildDialog(ChildModel child) {
    final nameC = TextEditingController(text: child.name);
    final schoolC = TextEditingController(text: child.school ?? '');
    final addressC = TextEditingController(text: child.address ?? '');
    DateTime dob = child.dob;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Edit Child", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(labelText: "Child Name", controller: nameC, node: FocusNode()),
                const SizedBox(height: 12),
                Text("Date of Birth",
                    style: TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(height: 5),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: dob,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setDialogState(() => dob = d);
                  },
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.textFieldBackgroundColor),
                    child: Row(children: [
                      Text(DateFormat('d MMM yyyy').format(dob)),
                      const Spacer(),
                      const Icon(Icons.calendar_today, color: AppColors.greyColor),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                CustomTextField(labelText: "School", controller: schoolC, node: FocusNode()),
                const SizedBox(height: 12),
                CustomTextField(labelText: "Address", controller: addressC, node: FocusNode()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                if (nameC.text.trim().isEmpty) {
                  showSnackBar(context, "Enter Child Name");
                  return;
                }
                widget.provider.updateChild(
                  child.id,
                  name: nameC.text.trim(),
                  dob: dob,
                  school: _emptyToNull(schoolC.text),
                  address: _emptyToNull(addressC.text),
                );
                Navigator.pop(ctx);
              },
              child: const Text("Save", style: TextStyle(color: Color(0xFF4A148C))),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 6: Check imports**

`ChildModel` is used by the new `_childSubtitle` and `_showEditChildDialog` signatures. `case_setup_screen.dart` already imports `package:clearcase/models/case_model.dart` (added by the uncommitted batch for `existingCase`). Confirm with `flutter analyze`; add it only if reported missing.

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: 0 errors, no new warnings.

**Do NOT commit** (see Global Constraints).

---

### Task 5: PDF cover — one block per child

**Files:**
- Modify: `lib/views/widgets/pdf_generator.dart` — `_buildCoverPage` (`:157-251`)

**Interfaces:**
- Consumes, from Task 3: `ChildModel.school` and `ChildModel.address` (both `String?`).

- [ ] **Step 1: Replace the joined-value computation**

In `_buildCoverPage`, lines 171-176 currently read:

```dart
    final String childNames =
        children.isEmpty ? "—" : children.map((c) => c.name).join(", ");
    final String dobs = children.isEmpty
        ? "—"
        : children.map((c) => DateFormat('dd/MM/yyyy').format(c.dob)).join("\n");
```

Delete both. Per-child blocks render each child's values directly, so the joined strings are no longer needed. **Keep** the `children` filter above them (`:167-169`) exactly as-is — it honours the export's child selection and must not regress:

```dart
    final children = (caseModel?.children ?? [])
        .where((c) => options.childIds.isEmpty || options.childIds.contains(c.id))
        .toList();
```

- [ ] **Step 2: Restructure the CASE INFORMATION block**

The block at `:208-216` currently reads:

```dart
              pw.Text("CASE INFORMATION",
                  style: pw.TextStyle(font: bold, fontSize: 13, color: primaryColor)),
              pw.SizedBox(height: 14),
              _coverInfoRow(children.length > 1 ? "Child Names" : "Child Name", childNames, bold),
              _coverInfoRow("Case Number", caseName, bold),
              _coverInfoRow("Date of Birth", dobs, bold),
              _coverInfoRow("Legal Representative", legalRep, bold),
              _coverInfoRow("Parent / Guardian", guardian, bold),
```

Replace with case-level rows only:

```dart
              pw.Text("CASE INFORMATION",
                  style: pw.TextStyle(font: bold, fontSize: 13, color: primaryColor)),
              pw.SizedBox(height: 14),
              _coverInfoRow("Case Number", caseName, bold),
              _coverInfoRow("Legal Representative", legalRep, bold),
              _coverInfoRow("Parent / Guardian", guardian, bold),
```

- [ ] **Step 3: Add the CHILDREN block**

Immediately after the CASE INFORMATION `pw.Container` closes (after `:218`, before the `pw.SizedBox(height: 20)` at `:219`), insert a second container styled identically:

```dart
        pw.SizedBox(height: 20),

        // Per-child details. One block each so school/address are never
        // ambiguous across siblings.
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF7F2FB),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: primaryColor, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("CHILDREN",
                  style: pw.TextStyle(font: bold, fontSize: 13, color: primaryColor)),
              pw.SizedBox(height: 14),
              if (children.isEmpty)
                pw.Text("—", style: const pw.TextStyle(fontSize: 11))
              else
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0) pw.SizedBox(height: 14),
                  pw.Text(children[i].name,
                      style: pw.TextStyle(font: bold, fontSize: 12)),
                  pw.SizedBox(height: 4),
                  _coverInfoRow("Date of Birth",
                      DateFormat('dd/MM/yyyy').format(children[i].dob), bold),
                  _coverInfoRow("School", _orDash(children[i].school), bold),
                  _coverInfoRow("Address", _orDash(children[i].address), bold),
                ],
            ],
          ),
        ),
```

- [ ] **Step 4: Add the dash helper**

Add next to `_coverInfoRow` (after `:270`):

```dart
  // Absent or blank detail renders as an em dash, matching how the cover already
  // represents missing data.
  static String _orDash(String? value) =>
      (value ?? "").trim().isEmpty ? "—" : value!.trim();
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze`
Expected: 0 errors, and **no `unused_local_variable`** — if `childNames`/`dobs` were missed in Step 1, analyze reports them here.

- [ ] **Step 6: Verify the filter still applies**

Confirm by reading: the `children` list is still derived through the `options.childIds` filter, and the CHILDREN block iterates that same filtered list — not `caseModel!.children`. A report filtered to one child must show exactly one block.

**Do NOT commit** (see Global Constraints).

---

## Manual Verification (controller runs this — subagents have no device)

Run: `flutter run`

**Log viewer**
1. Insights → Disputes → tap a dispute → tap a log. It opens **full-screen** on the log you tapped ("Log 3 of 7").
2. Swipe left/right moves between logs; Previous/Next agree with swipe; Previous is disabled on the first, Next on the last.
3. A long description is fully readable and scrolls.
4. Edit from the viewer → save → **the view updates without backing out** (this is what streaming buys).
5. Delete a middle log → viewer stays in range and the count updates. Delete the only log → viewer pops back.
6. **System back button returns to the list** (previously faked via PopScope).
7. Open a resolved/closed dispute → no edit/delete icons in the viewer.
8. Regression: the list rows' own edit/delete still work; "Add New Log" still works.

**Child details**
9. Add a child with school + address → both show in the tile subtitle.
10. Tap a child → edit the school → save → subtitle updates.
11. Save the case, reopen in edit mode → school/address persisted.
12. **Critical:** in the Firebase console, confirm the edited child's `id` is **unchanged**, and any `scheduledRules/*/appliedChildren` entry still matches it. A changed id means rule targeting and export filters silently broke.
13. A child added before this change (no school/address) still renders, subtitle shows DOB only.

**PDF**
14. Generate a report for a case with 2+ children → each child gets its own block with Date of Birth / School / Address.
15. A child with no school/address shows "—" for those rows.
16. Export filtered to one child → only that child's block appears.

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| Feature 1 — viewer route, PageView swipe, edit/delete, streams own data, index clamping | 2 |
| Feature 1 — extract `_showLogDialog`, delete master/detail machinery | 1, 2 |
| Feature 2 — ChildModel school/address, nullable, no migration | 3 |
| Feature 2 — Step 1 add-form fields, tile display, tap-to-edit preserving id | 4 |
| Feature 2 — `RuleConfigurationProvider.addChild` deliberately untouched | 3 (Step 5) |
| Feature 2b — per-child cover blocks, filter preserved, "—" for empty | 5 |
| Testing — manual only, no test suite | Manual Verification section |

No spec requirement is unassigned.

**Type consistency:** `showDisputeLogDialog(BuildContext, {required String caseId, required String disputeId, Map<String, dynamic>? existingLog}) → Future<bool?>` is defined in Task 1 and consumed identically in Tasks 1 (Step 3) and 2 (Steps 1, 4). `addChild(String, DateTime, {String? school, String? address})` and `updateChild(String, {required String name, required DateTime dob, String? school, String? address})` are defined in Task 3 and called with matching signatures in Task 4. `ChildModel.school`/`.address` are `String?` in Task 3 and consumed as `String?` in Tasks 4 (`_childSubtitle`, `_emptyToNull`) and 5 (`_orDash`). The viewer's route argument map keys (`caseId`, `disputeId`, `initialIndex`, `isClosed`, `party`) are written in Task 2 Step 3 and read in Task 2 Step 1.

**Known soft spot:** Task 2 Step 4 deletes code by line number from a file that Task 1 already shortened. Line numbers will have shifted — the implementer must locate the constructs by name (`_selectedLogIndex`, `_buildDetailView`, `_buildDetailNavButtons`, `PopScope`), not by the line numbers quoted here.
