import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/utils/child_names.dart';
import '../../models/non_compliance_model.dart';
import '../../provider/insight_provider.dart';
import '../widgets/attachment_thumbnail.dart';
import '../widgets/child_tag.dart';

class NonComplianceDetailsScreen extends StatelessWidget {
  static const routeName = '/non-compliance-details';
  const NonComplianceDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final record = ModalRoute.of(context)!.settings.arguments as NonComplianceRecordModel?;

    if (record == null) return const Scaffold(body: Center(child: Text("No data found")));
    final selectedCase = Provider.of<InsightProvider>(context, listen: false).selectedCase;

    Color severityColor = record.severity == "Serious" ? Colors.red :
    (record.severity == "Minor" ? Colors.green : Colors.orange);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Non Compliance Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP SUMMARY CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Wrapped in Expanded to prevent the 5.9px overflow
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.date != null ? DateFormat('MMM dd, yyyy').format(record.date!) : "N/A",
                              style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Summary",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.shield, color: Colors.red),
                    ],
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(record.childIds.length > 1 || record.childIds.isEmpty ? "Children" : "Child",
                          style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(width: 12),
                      Flexible(child: ChildTag(childTagLabel(record.childIds, selectedCase))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow("Party Name", record.name),
                  const SizedBox(height: 12),
                  _buildDetailRow("Relation Party", record.party),
                  const SizedBox(height: 12),
                  _buildDetailRow("Reason", record.type),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // --- DESCRIPTION & EVIDENCE CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Incident Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      _buildTag(record.severity, severityColor),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    record.description.isEmpty ? "No description provided." : record.description,
                    style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14),
                  ),

                  if (record.proof.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildEvidenceCard(record.proof),
                  ],

                  if (record.attachments != null && record.attachments!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 112,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: record.attachments!.length,
                        itemBuilder: (context, index) => AttachmentThumbnail(url: record.attachments![index]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE HELPERS ---

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildEvidenceCard(String evidenceText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text("Evidence",
              style: TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
            evidenceText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7E57C2), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
