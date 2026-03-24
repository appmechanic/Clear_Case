import 'package:flutter/material.dart';

 import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../provider/insight_provider.dart';

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
    final DateTime? startDate = (record['startDate'] as Timestamp?)?.toDate();
    final DateTime? startTime = (record['startTime'] as Timestamp?)?.toDate();
    final DateTime? endTime = (record['endTime'] as Timestamp?)?.toDate();

    final bool isScheduled = record['isScheduled'] ?? false;
    final bool isFulfilled = record['isFulfilled'] ?? false;
    final List<dynamic> attachmentUrls = record['attachmentUrls'] ?? [];
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        startDate != null ? DateFormat('MMM dd, yyyy').format(startDate) : "N/A",
                        style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isScheduled ? "Scheduled Custody" : "Non-Scheduled",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  _buildTag(
                    isFulfilled ? "Fulfilled" : "Unfulfilled",
                    isFulfilled ? Colors.green : Colors.red,
                  ),
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
                  _buildDetailRow("Start Time", startTime != null ? DateFormat('hh:mm a').format(startTime) : "N/A"),
                  const SizedBox(height: 12),
                  _buildDetailRow("End Time", endTime != null ? DateFormat('hh:mm a').format(endTime) : "N/A"),
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
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: attachmentUrls.length,
                        itemBuilder: (context, index) => _buildAttachmentThumbnail(attachmentUrls[index]),
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),
                  const Text("Associated Children", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),

                  // Mapping Child IDs to UI Tiles
                  ...childIds.map((id) {
                    final child = insightProv.selectedCase?.children.firstWhere(
                          (c) => c.id.toString() == id.toString(),
                    );
                    if (child == null) return const SizedBox.shrink();
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

  Widget _buildAttachmentThumbnail(String url) {
    // Check if the URL contains .pdf (ignoring case)
    final bool isPdf = url.toLowerCase().contains('.pdf') ||
        url.toLowerCase().contains('?alt=media&token=') && url.contains('.pdf');

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isPdf
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
            Text("PDF", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        )
            : Image.network(
          url,
          fit: BoxFit.cover,
          // Error builder prevents the whole screen from crashing if one image fails
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          },
        ),
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