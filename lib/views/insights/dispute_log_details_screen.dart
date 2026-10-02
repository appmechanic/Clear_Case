import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/attachments.dart';
import '../../core/utils/child_names.dart';
import '../../core/utils/helping_functions.dart';
import '../../models/case_model.dart';
import '../../provider/dispute_insight_provider.dart';
import '../../provider/insight_provider.dart';
import '../widgets/attachment_thumbnail.dart';
import '../widgets/child_tag.dart';
import '../widgets/dispute_log_dialog.dart';

/// One dispute on a single vertical page: its summary at the top, then every
/// log in chronological order (oldest first) so the dispute's progression
/// reads top to bottom. Logs are shown in full — nothing to expand, swipe or
/// open separately.
///
/// Arguments: the dispute's data map; it must carry `caseId` and `id` (the
/// Disputes list and the Flagged Events list both pass one).
class DisputeDetailsScreen extends StatefulWidget {
  static const routeName = '/dispute-details';
  const DisputeDetailsScreen({super.key});

  @override
  State<DisputeDetailsScreen> createState() => _DisputeDetailsScreenState();
}

class _DisputeDetailsScreenState extends State<DisputeDetailsScreen> {
  static const Color _accent = Color(0xFF4A148C);
  static const Color _dateColor = Color(0xFF6200EE);

  late Map<String, dynamic> _initialData;
  late String _caseId;
  late String _disputeId;
  bool _isInit = true;
  bool _isLoading = false;
  // Created once: a fresh stream per build would resubscribe (and flash the
  // loader) every time InsightProvider notifies.
  late Stream<DocumentSnapshot> _disputeStream;
  late Stream<List<Map<String, dynamic>>> _logsStream;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _initialData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map,
      );
      _caseId = (_initialData['caseId'] ?? '').toString();
      _disputeId = (_initialData['id'] ?? '').toString();
      final prov = Provider.of<DisputeInsightsProvider>(context, listen: false);
      _disputeStream = prov.getDisputeStream(_caseId, _disputeId);
      _logsStream = prov.getDisputeLogs(_caseId, _disputeId);
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  /// The dispute's case, for naming its children. Looked up by id so a
  /// dispute opened from Flagged Events still resolves against its own case.
  CaseModel? _caseFor(InsightProvider insightProv) {
    for (final c in insightProv.allCases) {
      if (c.id == _caseId) return c;
    }
    return insightProv.selectedCase;
  }

  /// Oldest first. A log that was just written has no server `createdAt` yet,
  /// so it sorts last (it is the newest).
  List<Map<String, dynamic>> _chronological(List<Map<String, dynamic>> logs) {
    final sorted = List<Map<String, dynamic>>.from(logs);
    sorted.sort((a, b) {
      final ta = a['createdAt'], tb = b['createdAt'];
      if (ta is! Timestamp && tb is! Timestamp) return 0;
      if (ta is! Timestamp) return 1;
      if (tb is! Timestamp) return -1;
      return ta.compareTo(tb);
    });
    return sorted;
  }

  Future<void> _setStatus(String status, String message) async {
    final prov = Provider.of<DisputeInsightsProvider>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      await prov.updateDisputeStatus(_caseId, _disputeId, status);
      if (mounted) showSnackBar(context, message);
    } catch (e) {
      if (mounted) showSnackBar(context, "Couldn't update the dispute status");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addLog() {
    showDisputeLogDialog(context, caseId: _caseId, disputeId: _disputeId);
  }

  void _editLog(Map<String, dynamic> log) {
    showDisputeLogDialog(context, caseId: _caseId, disputeId: _disputeId, existingLog: log);
  }

  @override
  Widget build(BuildContext context) {
    final insightProv = Provider.of<InsightProvider>(context);
    final caseModel = _caseFor(insightProv);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text("Dispute Details", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: _disputeStream,
            builder: (context, parentSnap) {
              if (parentSnap.hasError) {
                return const Center(child: Text("Error loading dispute"));
              }
              if (!parentSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final raw = parentSnap.data!.data();
              if (raw is! Map<String, dynamic>) {
                return const Center(child: Text("This dispute no longer exists."));
              }
              final dispute = raw;
              final bool isClosed = dispute['disputeStatus'] == "Resolved";

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _logsStream,
                builder: (context, logSnap) {
                  if (logSnap.connectionState == ConnectionState.waiting && !logSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (logSnap.hasError) {
                    return const Center(child: Text("Error loading logs"));
                  }
                  final logs = _chronological(logSnap.data ?? const []);

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummary(dispute, isClosed, caseModel),
                              const SizedBox(height: 24),
                              _buildTimelineHeader(logs.length),
                              const SizedBox(height: 12),
                              _buildTimeline(logs, isClosed),
                            ],
                          ),
                        ),
                      ),
                      _buildBottomActionArea(isClosed),
                    ],
                  );
                },
              );
            },
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // --- SUMMARY ---

  Widget _buildSummary(Map<String, dynamic> data, bool isClosed, CaseModel? caseModel) {
    final date = data['date'];
    final String dateStr =
        date is Timestamp ? DateFormat('EEEE, dd MMM yyyy').format(date.toDate()) : "No date";
    final String category = (data['category'] ?? "Dispute").toString();
    final String description = (data['description'] ?? "").toString().trim();
    final String party = (data['party'] ?? "").toString().trim();
    final String name = (data['name'] ?? "").toString().trim();
    final List<String> attachments = readAttachmentUrls(data);
    final Color statusColor = isClosed ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(dateStr,
                    style: const TextStyle(color: _dateColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              _pill(isClosed ? "Resolved" : "Open", statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChildTag.forIds(readChildIds(data), caseModel),
            ],
          ),
          if (party.isNotEmpty || name.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.purple.shade50,
                  child: const Icon(Icons.person, size: 14, color: Colors.purple),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (party.isNotEmpty)
                        Text(party, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 28),
          const Text("Description",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 6),
          description.isEmpty
              ? Text("No description was recorded.",
                  style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic))
              : Text(description, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text("Attachments",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 10),
            _attachmentWrap(attachments),
          ],
        ],
      ),
    );
  }

  // --- TIMELINE ---

  Widget _buildTimelineHeader(int count) {
    return Row(
      children: [
        const Text("Log History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 8),
        Text("($count)", style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const Spacer(),
        const Icon(Icons.arrow_downward, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        const Text("Oldest first", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> logs, bool isClosed) {
    if (logs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              isClosed
                  ? "This dispute has no logs."
                  : "No logs yet. Add the first log to start documenting this dispute.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < logs.length; i++)
          _buildTimelineEntry(
            logs[i],
            index: i,
            total: logs.length,
            isClosed: isClosed,
          ),
      ],
    );
  }

  /// One log: a dot on a vertical rail, with the full log card beside it.
  /// The rail is drawn with Positioned children so the entry sizes to its
  /// card (no IntrinsicHeight, which the attachment tiles can't support).
  Widget _buildTimelineEntry(
    Map<String, dynamic> log, {
    required int index,
    required int total,
    required bool isClosed,
  }) {
    const double railX = 7;
    const double dotTop = 20;
    final bool isFirst = index == 0;
    final bool isLast = index == total - 1;

    return Stack(
      children: [
        // Rail: from the previous entry down through this dot to the next.
        if (total > 1)
          Positioned(
            left: railX,
            top: isFirst ? dotTop : 0,
            bottom: isLast ? null : 0,
            height: isLast ? dotTop : null,
            child: Container(width: 2, color: const Color(0xFFD1C4E9)),
          ),
        Positioned(
          left: 0,
          top: dotTop - 7,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 3),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 14),
          child: _buildLogCard(log, index: index, total: total, isClosed: isClosed),
        ),
      ],
    );
  }

  Widget _buildLogCard(
    Map<String, dynamic> log, {
    required int index,
    required int total,
    required bool isClosed,
  }) {
    final String title = (log['title'] ?? '').toString().trim();
    final String description = (log['description'] ?? '').toString().trim();
    final List<String> attachments = readAttachmentUrls(log);
    final createdAt = log['createdAt'];
    final updatedAt = log['updatedAt'];
    final String dateStr = createdAt is Timestamp
        ? DateFormat('dd MMM yyyy · hh:mm a').format(createdAt.toDate())
        : "Just now";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Log ${index + 1} of $total",
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(dateStr,
                        style: const TextStyle(color: _dateColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              // Edit/delete only apply to an open dispute.
              if (!isClosed) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: "Edit log",
                  icon: const Icon(Icons.edit, color: Colors.black, size: 20),
                  onPressed: () => _editLog(log),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: "Delete log",
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(log),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.isEmpty ? "Untitled log" : title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                description.isEmpty
                    ? Text("No details were recorded for this log.",
                        style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 14))
                    : Text(description,
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _attachmentWrap(attachments),
                ],
                if (updatedAt is Timestamp) ...[
                  const SizedBox(height: 8),
                  Text("Edited ${DateFormat('dd MMM yyyy').format(updatedAt.toDate())}",
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SHARED BITS ---

  /// Thumbnails wrap onto new rows — no horizontal scrolling. Tapping one
  /// opens the in-app preview (AttachmentThumbnail handles it).
  Widget _attachmentWrap(List<String> urls) {
    return Wrap(
      runSpacing: 10,
      children: [for (final url in urls) AttachmentThumbnail(url: url)],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildBottomActionArea(bool isClosed) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: isClosed
            ? _btn("Reopen Dispute", Colors.green, () => _setStatus("Open", "Dispute reopened"))
            : Row(
                children: [
                  Expanded(child: _btn("Add New Log", _accent, _addLog)),
                  const SizedBox(width: 12),
                  Expanded(child: _btn("Close Dispute", Colors.redAccent, _confirmClose)),
                ],
              ),
      ),
    );
  }

  Widget _btn(String t, Color c, VoidCallback? tap) => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: c,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          onPressed: tap,
          child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );

  ButtonStyle _dialogButtonStyle(Color color) => ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  static const TextStyle _dialogButtonText =
      TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14);

  Future<bool> _confirm({
    required String title,
    required Widget content,
    required String actionLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              child: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        content: content,
        actionsPadding: const EdgeInsets.only(right: 20, bottom: 20),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                style: _dialogButtonStyle(const Color(0xFF7B2CBF)),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel", style: _dialogButtonText),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: _dialogButtonStyle(const Color(0xFFE55353)),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(actionLabel, style: _dialogButtonText),
              ),
            ],
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmClose() async {
    final ok = await _confirm(
      title: "Close Dispute",
      content: const Text("Mark this dispute as resolved? You can reopen it later.",
          style: TextStyle(fontSize: 15, color: Colors.black87)),
      actionLabel: "Close",
    );
    if (!ok || !mounted) return;
    await _setStatus("Resolved", "Dispute marked as Resolved");
  }

  Future<void> _confirmDelete(Map<String, dynamic> log) async {
    final String title = (log['title'] ?? '').toString().trim().isEmpty
        ? "Untitled log"
        : log['title'].toString();
    final createdAt = log['createdAt'];
    final String formattedDate = createdAt is Timestamp
        ? DateFormat('EEEE, MMMM dd, yyyy').format(createdAt.toDate())
        : "";

    final ok = await _confirm(
      title: "Delete log",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Are you sure you want to delete this entry?",
              style: TextStyle(fontSize: 15, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(formattedDate.isEmpty ? title : "$title, $formattedDate",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
        ],
      ),
      actionLabel: "Delete",
    );
    if (!ok || !mounted) return;

    final prov = Provider.of<DisputeInsightsProvider>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      await prov.deleteLogWithStorage(_caseId, _disputeId, log);
      if (mounted) showSnackBar(context, "Log deleted successfully");
    } catch (e) {
      if (mounted) showSnackBar(context, "Couldn't delete the log");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
