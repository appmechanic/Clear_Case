import 'package:flutter/material.dart';

class BreachHistoryScreen extends StatelessWidget {
  static const routeName = '/breach-history';
  const BreachHistoryScreen({super.key});

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
            _buildBreachItem("Dec 25", "Late for pickup/handover", "Failed to arrive for scheduled pickup...", "Serious", Colors.red),
            _buildBreachItem("Dec 25", "Late for pickup/handover", "Did not respond to multiple attempts...", "Moderate", Colors.orange),
            _buildBreachItem("Dec 25", "Location Violation", "Took child to unauthorized location...", "Minor", Colors.green),
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text("Non Compliance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Icon(Icons.shield, color: Colors.red)]),
          const SizedBox(height: 10),
          const Text("1562", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32)),
          const Text("Total", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat("16", "Serious"),
              _buildStat("2", "Moderate"),
              _buildStat("2", "Minor"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreachItem(String date, String title, String desc, String severity, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(severity, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(radius: 10, backgroundColor: Colors.purple.shade50, child: const Icon(Icons.person, size: 12, color: Colors.purple)),
              const SizedBox(width: 8),
              const Text("Michael Smile", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
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