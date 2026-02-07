import 'package:clearcase/views/insights/dispute_log_details_screen.dart';
import 'package:flutter/material.dart';

class DisputesLogScreen extends StatelessWidget {
  static const routeName = '/disputes-log';
  const DisputesLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar("Insights"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            _buildSearchBar(),
            const SizedBox(height: 20),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, DisputeDetailsScreen.routeName);
            }, child: 
            _buildDisputeItem("Dec 25", "Communication", "5 logs", "Open", Colors.red)),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, DisputeDetailsScreen.routeName);
            }, child: 
            _buildDisputeItem("Dec 15", "Payments", "5 logs", "In Progress", Colors.orange)),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, DisputeDetailsScreen.routeName);
            }, child: 
            _buildDisputeItem("Dec 15", "Schedule", "5 logs", "In Progress", Colors.orange)),
            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text("November 2025", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            const SizedBox(height: 10),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, DisputeDetailsScreen.routeName);
            }, child:
            _buildDisputeItem("Dec 25", "Communication", "5 logs", "Open", Colors.red)),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, DisputeDetailsScreen.routeName);
            }, child: 
            _buildDisputeItem("Dec 15", "Payments", "5 logs", "In Progress", Colors.orange)),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, DisputeDetailsScreen.routeName);
            }, child: 
            _buildDisputeItem("Dec 15", "Schedule", "5 logs", "Resolved", Colors.green)),
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text("Disputes Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Icon(Icons.error, color: Colors.red)]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat("16", "Communication"),
              _buildStat("2", "Transfer\nIssues"),
              _buildStat("16", "Payment\nDisputes"),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat("2", "Open"),
              _buildStat("16", "Resolved"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeItem(String date, String title, String logs, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(logs, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          )
        ],
      ),
    );
  }
  
  // (Helpers same as previous)
  PreferredSizeWidget _buildAppBar(String title) { return AppBar(title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)); }
  Widget _buildSearchBar() { return TextField(decoration: InputDecoration(hintText: "Search", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.grey[200], border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0))); }
  Widget _buildStat(String val, String label) { return Column(children: [Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey))]); }
}