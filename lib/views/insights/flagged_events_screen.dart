import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/non_compliance_model.dart';
import '../../models/payment_model.dart';
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

  // CustodyDetailsScreen and DisputeDetailsScreen read their `arguments` as a
  // raw Map<String, dynamic>, but PaymentDetailsScreen and
  // NonComplianceDetailsScreen expect a typed model (they access fields via
  // dot notation, e.g. `record.transactionType`). Passing a bare Map to those
  // two would throw at runtime, so build the model those screens expect,
  // using the id we already substituted (originId) as the model's id.
  static void _navigateToDetail(
      BuildContext context, String bucket, Map<String, dynamic> event) {
    final String id = (event['id'] as String?) ?? '';
    switch (bucket) {
      case 'paymentRecords':
        Navigator.pushNamed(
          context,
          PaymentDetailsScreen.routeName,
          arguments: PaymentRecordModel.fromMap(event, id),
        );
        break;
      case 'disputeRecords':
        Navigator.pushNamed(
          context,
          DisputeDetailsScreen.routeName,
          arguments: event,
        );
        break;
      case 'nonComplianceRecords':
        Navigator.pushNamed(
          context,
          NonComplianceDetailsScreen.routeName,
          arguments: NonComplianceRecordModel.fromMap(event, id),
        );
        break;
      default:
        Navigator.pushNamed(
          context,
          CustodyDetailsScreen.routeName,
          arguments: event,
        );
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
          // No RefreshIndicator: InsightProvider live-streams flaggedEvents, so
          // there is nothing to refetch — a pull-to-refresh could only animate
          // and lie.
          return SingleChildScrollView(
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
                color: group.color.withValues(alpha: 0.1),
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
      onTap: () => _navigateToDetail(context, group.key, event),
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
