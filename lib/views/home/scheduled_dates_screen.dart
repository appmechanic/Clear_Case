import 'package:flutter/material.dart';
import 'rule_configuration_screen.dart';

class ScheduledDatesScreen extends StatelessWidget {
  static const routeName = '/scheduled-dates';
  const ScheduledDatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Scheduled dates", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Case Selector Header
            const Text("Select Case", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 5),
            Row(
              children: const [
                Text("2541-8455 (Jack & Ella)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(width: 5),
                Icon(Icons.keyboard_arrow_down),
              ],
            ),
            const SizedBox(height: 25),

            // 1. Scheduled Custody Card
            _buildRuleCard(
              context,
              title: "Scheduled Custody",
              desc: "Set up recurring custody schedules, handover times, and parenting arrangements...",
              tags: ["Court-ordered", "Time-sensitive", "Compliance Tracking"],
              color: Colors.green,
            ),

            // 2. Scheduled Payments Card
            _buildRuleCard(
              context,
              title: "Scheduled Payments",
              desc: "Configure recurring child support payments, medical expenses...",
              tags: ["Financial", "Recurring", "Payment tracking"],
              color: Colors.orange,
            ),

            // 3. Custom Order (Add New) Card
            _buildAddRuleCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(BuildContext context, {required String title, required String desc, required List<String> tags, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 10),
                    onPressed: () => Navigator.pushNamed(context, RuleConfigurationScreen.routeName),
                  ),
                  const Icon(Icons.delete, color: Colors.red, size: 20),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(t, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.bold)),
            )).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildAddRuleCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Custom Order", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text("Create custom rules for communication schedules, special events...", 
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ["Flexible", "Customizable", "Multi-purpose"].map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(t, style: TextStyle(fontSize: 10, color: Colors.green.withOpacity(0.8), fontWeight: FontWeight.bold)),
                  )).toList(),
                )
              ],
            ),
          ),
          FloatingActionButton.small(
            heroTag: "add_rule_btn",
            backgroundColor: const Color(0xFF00C853), // Green color from screenshot
            elevation: 0,
            onPressed: () => Navigator.pushNamed(context, RuleConfigurationScreen.routeName),
            child: const Icon(Icons.add, color: Colors.white),
          )
        ],
      ),
    );
  }
}