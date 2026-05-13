import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/case_model.dart';
import '../../provider/insight_provider.dart';
import '../widgets/attachment_preview.dart';
import '../widgets/file_type_icon.dart';


class PaymentDetailsScreen extends StatelessWidget {
  static const routeName = '/payment-details';
  const PaymentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final record = ModalRoute.of(context)!.settings.arguments as dynamic;
    final insightProv = Provider.of<InsightProvider>(context, listen: false);

    if (record == null) return const Scaffold(body: Center(child: Text("No data found")));

    final bool isReceived = record.transactionType == "PaymentReceived";
    final Color statusColor = isReceived ? Colors.green : const Color(0xFF6200EE);
    final String statusText = isReceived ? "Payment Received" : "Paid by me";
    final Color categoryColor = (record.paymentCategory == "Compulsory") ? Colors.orange : Colors.green;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Payment Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.date != null ? DateFormat('MMM dd').format(record.date!) : "N/A",
                              style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              record.paymentType ?? "General Payment",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      _buildTag(record.paymentCategory ?? "Additional", categoryColor),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                      Text("\$${record.amount?.toInt() ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 15),

            // --- MAIN INFO CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Transaction Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    record.date != null ? DateFormat('dd MMM yyyy   hh:mm a').format(record.date!) : "",
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  _buildRow("Payment Method", record.paymentMethod ?? "Not Specified"),
                  const SizedBox(height: 10),
                  // Updated to display actual location string
                  _buildRow("Payment Location", record.location ?? "Not Specified"),

                  if (record.notes != null && record.notes!.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Text(record.notes!, style: const TextStyle(color: Colors.grey, height: 1.4, fontSize: 13)),
                  ],

                  if (record.attachmentUrls != null && record.attachmentUrls!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: record.attachmentUrls!.length,
                        itemBuilder: (context, index) => _buildAttachmentThumbnail(context, record.attachmentUrls![index]),
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),
                  const Text("Associated Children", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),

                  ... (record.childIds as List<String>).map((id) {
                    final child = insightProv.selectedCase?.children.firstWhere(
                            (c) => c.id == id,
                        orElse: () => ChildModel(id: '', name: 'Unknown', dob: DateTime.now())
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildChildTile(child!.name, DateFormat('dd MMM yyyy').format(child.dob)),
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

  // --- REUSABLE HELPERS ---

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        // Added Expanded/Flexible for long location strings
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        )
      ],
    );
  }

  // Updated Children UI to match image_fc9489.png
  Widget _buildChildTile(String name, String dob) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1F5FE), width: 2), // Light blue border
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF3E5F5), // Light purple background for icon
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF7B1FA2), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(dob, style: const TextStyle(fontSize: 13, color: Colors.grey))
            ],
          ),
          const Spacer(),
          // Custom purple radio-style icon from image
          const Icon(Icons.radio_button_checked, color: Color(0xFF6200EE), size: 24),
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

  Widget _buildAttachmentThumbnail(BuildContext context, String url) {
    final ext = extensionFromUrl(url);
    final isImage = isImageExtension(ext);
    final typeInfo = fileTypeFromExtension(ext);

    return GestureDetector(
      onTap: () => AttachmentPreview.openUrl(context, url),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isImage
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => FileTypeTile(info: typeInfo),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  },
                )
              : FileTypeTile(info: typeInfo),
        ),
      ),
    );
  }
}