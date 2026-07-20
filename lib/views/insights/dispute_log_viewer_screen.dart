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

  void _addLog() {
    showDisputeLogDialog(context, caseId: _caseId, disputeId: _disputeId);
  }

  void _editLog(Map<String, dynamic> log) {
    showDisputeLogDialog(context, caseId: _caseId, disputeId: _disputeId, existingLog: log);
  }

  Future<void> _reopen() async {
    final provider = Provider.of<DisputeInsightsProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    await provider.updateDisputeStatus(_caseId, _disputeId, "Open");
    if (mounted) messenger.showSnackBar(const SnackBar(content: Text("Dispute reopened")));
  }

  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Close Dispute",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        content: const Text("Mark this dispute as resolved? You can reopen it later."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Close", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = Provider.of<DisputeInsightsProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    await provider.updateDisputeStatus(_caseId, _disputeId, "Resolved");
    if (mounted) messenger.showSnackBar(const SnackBar(content: Text("Dispute closed")));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DisputeInsightsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        // Outer stream keeps status (open/resolved) and party live, so closing or
        // reopening the dispute updates the header without leaving the screen.
        child: StreamBuilder<DocumentSnapshot>(
          stream: provider.getDisputeStream(_caseId, _disputeId),
          builder: (context, disputeSnap) {
            bool isClosed = _isClosed;
            String party = _party;
            final disputeData = disputeSnap.data?.data();
            if (disputeData is Map<String, dynamic>) {
              isClosed = disputeData['disputeStatus'] == "Resolved";
              if ((disputeData['party'] ?? '').toString().isNotEmpty) {
                party = disputeData['party'];
              }
            }

            return StreamBuilder<List<Map<String, dynamic>>>(
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
                  return Column(
                    children: [
                      _buildAppBar(logs: logs, page: 0, currentLog: null, isClosed: isClosed),
                      Expanded(child: _buildEmptyState(isClosed)),
                    ],
                  );
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

                return Column(
                  children: [
                    _buildAppBar(logs: logs, page: safePage, currentLog: currentLog, isClosed: isClosed),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: logs.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (context, index) => _buildLogPage(logs[index], party),
                      ),
                    ),
                    _buildNavBar(logs.length, safePage),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isClosed) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text("No logs yet",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              isClosed
                  ? "This dispute has no logs."
                  : "Add the first log to start documenting this dispute.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (!isClosed) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: _addLog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Add New Log",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar({
    required List<Map<String, dynamic>> logs,
    required int page,
    required Map<String, dynamic>? currentLog,
    required bool isClosed,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    logs.isEmpty ? "Dispute" : "Log ${page + 1} of ${logs.length}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isClosed) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text("Resolved",
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ],
            ),
          ),
          // Add and edit/delete only apply to an open dispute.
          if (!isClosed) ...[
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF4A148C)),
              tooltip: "Add log",
              onPressed: _addLog,
            ),
            if (currentLog != null) ...[
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                tooltip: "Edit log",
                onPressed: () => _editLog(currentLog),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: "Delete log",
                onPressed: () => _confirmDelete(currentLog, logs.length),
              ),
            ],
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (v) {
              if (v == 'close') _confirmClose();
              if (v == 'reopen') _reopen();
            },
            itemBuilder: (ctx) => [
              if (!isClosed)
                const PopupMenuItem(value: 'close', child: Text("Close Dispute")),
              if (isClosed)
                const PopupMenuItem(value: 'reopen', child: Text("Reopen Dispute")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogPage(Map<String, dynamic> log, String party) {
    final List<String> attachments =
        (log['attachments'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final String description = (log['description'] ?? '').toString().trim();
    final createdAt = log['createdAt'];
    final String dateStr = createdAt is Timestamp
        ? DateFormat('dd MMM yyyy · hh:mm a').format(createdAt.toDate())
        : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      child: Container(
        width: double.infinity,
        // Fill most of the screen so a log reads like a page, not a small card
        // stranded in empty space.
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.6),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (log['title'] ?? '').toString().trim().isEmpty ? "Untitled log" : log['title'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, height: 1.2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (dateStr.isNotEmpty) _metaChip(Icons.schedule, dateStr),
                if (party.trim().isNotEmpty) _metaChip(Icons.person_outline, party),
              ],
            ),
            const Divider(height: 32),
            const Text("Details",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 10),
            description.isEmpty
                ? Text(
                    "No details were recorded for this log.",
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  )
                : Text(description,
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
            if (attachments.isNotEmpty) ...[
              const Divider(height: 32),
              const Text("Attachments",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => AttachmentThumbnail(url: attachments[index]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEF9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4A148C)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF4A148C), fontWeight: FontWeight.w600)),
        ],
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
