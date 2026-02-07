import 'package:clearcase/views/insights/custody_detail_screen.dart';
import 'package:flutter/material.dart';

class CustodyComplianceScreen extends StatelessWidget {
  static const routeName = '/custody-compliance';
  const CustodyComplianceScreen({super.key});

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
            const Text("Custody Records", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            const Text("December 2025", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 10),
            GestureDetector(onTap: () {
              Navigator.pushNamed(context, CustodyDetailsScreen.routeName);
            }, child: 
          _buildCustodyItem("Dec 25", "My Home", "Both children Christmas morning celebration...", ["Emma", "All Day"])),
          GestureDetector(onTap: () {
                            Navigator.pushNamed(context, CustodyDetailsScreen.routeName);

            }, child: 
            _buildCustodyItem("Dec 15", "Father's Residence", "Christmas Eve dinner and overnight stay...", ["Liam", "Timed"])),
            GestureDetector(onTap: () {
                            Navigator.pushNamed(context, CustodyDetailsScreen.routeName);

            }, child: _buildCustodyItem("Dec 7", "School Pickup", "Regular weekday pickup after school...", ["Liam", "Timed"])),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Custody Compliance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Icon(Icons.person, color: Colors.purple),
            ],
          ),
          const Text("December 2025", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat("16", "Custody Days\n(fulfilled)"),
              _buildStat("2", "With\nJustification"),
              _buildStat("16", "Missed Days\n(No Justification)"),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Overall Compliance", style: TextStyle(color: Colors.black54)),
              Text("96%", style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCustodyItem(String date, String title, String desc, List<String> tags) {
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
              Text(date, style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
              Row(
                children: tags.map((t) => Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                )).toList(),
              )
            ],
          ),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 5),
          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        Container(margin: const EdgeInsets.only(right: 20), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)), child: Row(children: const [Text("Export", style: TextStyle(color: Colors.blue)), SizedBox(width: 5), Icon(Icons.upload, size: 16, color: Colors.blue)])),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: "Search",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
    );
  }

  Widget _buildStat(String val, String label) {
    return Column(children: [Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey))]);
  }
}