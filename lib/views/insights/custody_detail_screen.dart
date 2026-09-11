import 'package:flutter/material.dart';

 import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/attachments.dart';
import '../../core/utils/custody_span.dart';
import '../../provider/insight_provider.dart';
import '../widgets/attachment_thumbnail.dart';

class CustodyDetailsScreen extends StatelessWidget {
  static const routeName = '/custody-details';
  const CustodyDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Receiving the Map record from Navigator

    final dynamic args = ModalRoute.of(context)!.settings.arguments;
    final Map<String, dynamic>? record = args is Map<String, dynamic> ? args : null;

    final insightProv = Provider.of<InsightProvider>(context, listen: false);

    if (record == null) {
      return const Scaffold(body: Center(child: Text("No record data found")));
    }

    // Parsing Dates/Times
    final CustodySpan? span = CustodySpan.fromMap(record);
    final DateTime? startTime = (record['startTime'] as Timestamp?)?.toDate();
    final DateTime? endTime = (record['endTime'] as Timestamp?)?.toDate();

    final List<String> attachmentUrls = readAttachmentUrls(record);
    final List<dynamic> childIds = record['childIds'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Custody Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- TOP SUMMARY CARD ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          span?.label ?? "N/A",
                          style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Custody Entry",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  _buildTag(nightsLabel(span?.nights ?? 0), AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // --- MAIN DETAILS CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Custody Log Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  _buildDetailRow("Start", _dateTime(span?.start, startTime)),
                  const SizedBox(height: 12),
                  _buildDetailRow("End", _dateTime(span?.end, endTime)),
                  const SizedBox(height: 12),
                  _buildDetailRow("Nights", "${span?.nights ?? 0}"),
                  const SizedBox(height: 12),
                  _buildDetailRow("Location", record['location'] ?? "Not Specified"),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 15),

                  const Text("Notes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    record['notes'] ?? "No notes provided for this record.",
                    style: const TextStyle(color: Colors.grey, height: 1.4, fontSize: 13),
                  ),

                  if (attachmentUrls.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 112,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: attachmentUrls.length,
                        itemBuilder: (context, index) => AttachmentThumbnail(url: attachmentUrls[index]),
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),
                  const Text("Associated Children", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),

                  // Mapping Child IDs to UI Tiles
                  ...childIds.map((id) {
                    final matches = (insightProv.selectedCase?.children ?? const []).where(
                          (c) => c.id.toString() == id.toString(),
                    );
                    if (matches.isEmpty) return const SizedBox.shrink();
                    final child = matches.first;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildChildTile(child.name, DateFormat('dd MMM yyyy').format(child.dob)),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPERS ---

  // "29 Sep 2026, 09:00 AM" — the day from the entry's span, the time from the
  // handover time field.
  String _dateTime(DateTime? day, DateTime? time) {
    if (day == null) return "N/A";
    final date = DateFormat('dd MMM yyyy').format(day);
    return time == null ? date : "$date, ${DateFormat('hh:mm a').format(time)}";
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        const SizedBox(width: 20),
        Flexible(
          child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildChildTile(String name, String dob) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1F5FE), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFF3E5F5), shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Color(0xFF7B1FA2), size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(dob, style: const TextStyle(fontSize: 11, color: Colors.grey))
            ],
          ),
          const Spacer(),
          const Icon(Icons.check_circle, color: Color(0xFF6200EE), size: 20),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}