import 'package:flutter/material.dart';

class PaymentDetailsScreen extends StatelessWidget {
  static const routeName = '/payment-details';
  const PaymentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            // Top Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Dec 25", style: TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text("Swimming Lessons", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Row(children: [_buildTag("Emma", Colors.blue), const SizedBox(width: 8), _buildTag("Compulsory", Colors.orange)]),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Payment Recieved", style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
                      Text("\$250", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 15),

            // Main Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text("Child Support", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("Compulsory", style: TextStyle(color: Colors.grey))]),
                  const SizedBox(height: 8),
                  const Text("12 Jan 2015   12:56 PM", style: TextStyle(color: Colors.black87, fontSize: 13)),
                  const SizedBox(height: 20),
                  
                  _buildRow("Payment Method", "Bank Transfer"),
                  const SizedBox(height: 10),
                  _buildRow("Payment Location", "New Jersey, USA"),
                  
                  const SizedBox(height: 15),
                  const Text("The payment was directly transferred to bank account, 50 \$ of compulsory payment is still remaining.", style: TextStyle(color: Colors.grey, height: 1.4, fontSize: 13)),
                  
                  const SizedBox(height: 20),
                  // Children List
                  _buildChildTile("Alex Smile", "12 Jan 2009"),
                  const SizedBox(height: 10),
                  _buildChildTile("Samuel Smile", "12 Jan 2009"),
                  
                  const SizedBox(height: 20),
                  Row(children: [_buildThumbnail(), const SizedBox(width: 10), _buildThumbnail()]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.black54)), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]);
  }

  Widget _buildChildTile(String name, String dob) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade50), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.purple.shade50, child: const Icon(Icons.person, color: Colors.purple)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold)), Text(dob, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
          const Spacer(),
          const Icon(Icons.radio_button_checked, color: Color(0xFF4A148C)),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 12)));
  }

  Widget _buildThumbnail() {
    return Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)));
  }
}