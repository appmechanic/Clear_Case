import 'package:clearcase/views/insights/payment_detail_screen.dart';
import 'package:flutter/material.dart';

class PaymentAnalyticsScreen extends StatelessWidget {
  static const routeName = '/payment-analytics';
  const PaymentAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar("Insights"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            _buildSearchBar(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Payment Analytics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(Icons.payment, color: Colors.green),
              ],
            ),
            const SizedBox(height: 15),
            const Text("December 2025", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 10),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, PaymentDetailsScreen.routeName);
            }, child: _buildPaymentItem("Dec 25", "Swimming Lessons", "Paid", "\$250", "Compulsory")),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, PaymentDetailsScreen.routeName);
            }, child: _buildPaymentItem("Dec 15", "School Program", "Paid", "\$250", "Additional", color: Colors.green)),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, PaymentDetailsScreen.routeName);
            }, child: _buildPaymentItem("Dec 15", "School Program", "Paid", "\$250", "Additional", color: Colors.green)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text("Payment Tracking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Icon(Icons.payment, color: Colors.green)]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMoneyStat("\$1239", "Payments Paid", const Color(0xFF6200EE)),
              _buildMoneyStat("\$1253", "Payments Received", const Color(0xFF00C853)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMoneyStat("\$1253", "Compulsory", Colors.black),
              _buildMoneyStat("\$1253", "Additional", Colors.black),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [Text("Total Payment", style: TextStyle(color: Colors.grey)), Text("\$5182", style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 20))],
          )
        ],
      ),
    );
  }

  Widget _buildPaymentItem(String date, String title, String status, String amount, String type, {Color color = Colors.orange}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Text("Emma", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(status, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          )
        ],
      ),
    );
  }

  // (Helper methods for AppBar, SearchBar, MoneyStat same as before)
  Widget _buildMoneyStat(String amount, String label, Color color) {
    return Column(children: [Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }
  
  PreferredSizeWidget _buildAppBar(String title) { return AppBar(title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)); }
  Widget _buildSearchBar() { return TextField(decoration: InputDecoration(hintText: "Search", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.grey[200], border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0))); }
}