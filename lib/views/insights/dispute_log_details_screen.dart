import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../provider/dispute_insight_provider.dart';
import '../widgets/dispute_log_dialog.dart';
import 'dispute_log_viewer_screen.dart';

class DisputeDetailsScreen extends StatefulWidget {
  static const routeName = '/dispute-details';
  const DisputeDetailsScreen({super.key});

  @override
  State<DisputeDetailsScreen> createState() => _DisputeDetailsScreenState();
}

class _DisputeDetailsScreenState extends State<DisputeDetailsScreen> {
  late Map<String, dynamic> disputeData;
  bool _isInit = true;
  bool _isLoading = false;
  late String party;
  @override
  void didChangeDependencies() {
    if (_isInit) {
      disputeData =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _isInit = false;
    }
    party = disputeData['party'];

    super.didChangeDependencies();
  }

  void _showStatus(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<DisputeInsightsProvider>(context);
    final String cId = disputeData['caseId'];
    final String dId = disputeData['id'];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text(
              "Dispute Details",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: prov.getDisputeStream(cId, dId),
            builder: (context, parentSnap) {
              if (!parentSnap.hasData)
                return const Center(child: CircularProgressIndicator());
              final currentDispute =
                  parentSnap.data!.data() as Map<String, dynamic>;
              final bool isClosed =
                  currentDispute['disputeStatus'] == "Resolved";

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: prov.getDisputeLogs(cId, dId),
                builder: (context, logSnap) {
                  // FIX: Removed Expanded. We use a SizedBox.expand or just Center
                  // because StreamBuilder is the direct child of the Scaffold body.
                  if (logSnap.connectionState == ConnectionState.waiting &&
                      !logSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (logSnap.hasError) {
                    return const Center(child: Text("Error loading logs"));
                  }

                  final logs = logSnap.data ?? [];

                  return Column(
                    children: [
                      Expanded(
                        // This Expanded is OK because it is inside a Column
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildHeader(currentDispute, isClosed),
                              const SizedBox(height: 20),
                              _buildListView(logs, isClosed, cId, dId),
                            ],
                          ),
                        ),
                      ),
                      _buildBottomActionArea(isClosed, prov, cId, dId, logs),
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

  // --- UI COMPONENTS ---

  Widget _buildHeader(Map<String, dynamic> data, bool isClosed) {
    final DateTime date = (data['date'] as Timestamp).toDate();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd').format(date),
              style: const TextStyle(
                color: Color(0xFF6200EE),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data['category'] ?? "Dispute",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isClosed
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isClosed ? "Resolved" : "Open",
            style: TextStyle(
              color: isClosed ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(
    List<Map<String, dynamic>> logs,
    bool isClosed,
    String cId,
    String dId,
  ) {
    if (logs.isEmpty)
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text("No logs added yet."),
        ),
      );
    return Column(
      children: logs.asMap().entries.map((entry) {
        final log = entry.value;
        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
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
            title: Text(
              log['title'] ?? "",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              log['createdAt'] != null
                  ? DateFormat(
                      'dd MMM yyyy',
                    ).format((log['createdAt'] as Timestamp).toDate())
                  : "",
            ),
            trailing: isClosed
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.black,
                          size: 20,
                        ),
                        onPressed: () => showDisputeLogDialog(
                          context,
                          caseId: cId,
                          disputeId: dId,
                          existingLog: log,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _confirmDelete(cId, dId, log),
                      ),
                    ],
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActionArea(
    bool isClosed,
    DisputeInsightsProvider prov,
    String cId,
    String dId,
    List logs,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (!isClosed) ...[
            _btn(
              "Add New Log",
              const Color(0xFF4A148C),
              () => showDisputeLogDialog(context, caseId: cId, disputeId: dId),
            ),
            const SizedBox(height: 20),
            _btn(
              "Close Dispute",
              Colors.redAccent,
              () => _confirmClose(cId, dId, prov),
            ),
          ] else
            _btn("Reopen Dispute", Colors.green, () async {
              setState(() => _isLoading = true);
              await prov.updateDisputeStatus(cId, dId, "Open");
              setState(() => _isLoading = false);
              _showStatus("Dispute Reopened");
            }),
        ],
      ),
    );
  }

  void _confirmClose(String cId, String dId, DisputeInsightsProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Close Dispute",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to Close this dispute?",
          style: TextStyle(fontSize: 15, color: Colors.black87),
        ),
        actionsPadding: const EdgeInsets.only(right: 20, bottom: 20),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // --- Cancel Button ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2CBF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // --- Close Button ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE55353),
                  // Matching your red theme
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  try {
                    await prov.updateDisputeStatus(cId, dId, "Resolved");
                    _showStatus("Dispute marked as Resolved");
                  } catch (e) {
                    _showStatus("Error closing dispute", isError: true);
                  }
                  setState(() => _isLoading = false);
                },
                child: const Text(
                  "Close",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String cId, String dId, Map<String, dynamic> log) {
    final String title = log['title'] ?? "Untitled Log";
    final DateTime date = (log['createdAt'] as Timestamp).toDate();
    final String formattedDate = DateFormat('EEEE, MMMM dd, yyyy').format(date);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Delete log",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you sure you want to delete this entry?",
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              "$title, $formattedDate",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(right: 20, bottom: 20),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // --- Cancel Button ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2CBF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // --- Delete Button ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFE55353,
                  ), // Specific Red from image
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  await Provider.of<DisputeInsightsProvider>(
                    context,
                    listen: false,
                  ).deleteLogWithStorage(cId, dId, log);
                  setState(() => _isLoading = false);
                  _showStatus("Log deleted successfully");
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String t, Color c, VoidCallback? tap) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: c,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      onPressed: tap,
      child: Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
