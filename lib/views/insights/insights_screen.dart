import 'package:clearcase/views/insights/breach_history_screen.dart';
import 'package:clearcase/views/insights/custody_compliance_screen.dart';
import 'package:clearcase/views/insights/dispute_log_screen.dart';
import 'package:clearcase/views/insights/payment_analytics_screen.dart';
import 'package:flutter/material.dart';

class InsightsScreen extends StatelessWidget {
  static const routeName = '/insights';
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Insights", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: false,
        automaticallyImplyLeading: false
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Text("2541-8455 (Jack & Ella)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(width: 5),
                Icon(Icons.keyboard_arrow_down),
              ],
            ),
            const SizedBox(height: 20),

            GestureDetector(
             onTap: () => Navigator.pushNamed(context, CustodyComplianceScreen.routeName),
             child: _buildCard(
              title: "Custody Compliance",
              subtitle: "December 2025",
              icon: Icons.person,
              iconColor: Colors.purple,
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem("16", "Custody Days\n(fulfilled)"),
                      _buildStatItem("2", "With\nJustification\n(Missed but Logged)"),
                      _buildStatItem("16", "Missed Days\n(No\nJustification)"),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Overall Compliance", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                      Text("96%", style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  )
                ],
              ),
            ),
          ),

          GestureDetector(
            onTap: () => Navigator.pushNamed(context, PaymentAnalyticsScreen.routeName),
            child: _buildCard(
              title: "Payment Tracking",
              subtitle: "December 2025",
              icon: Icons.payment,
              iconColor: Colors.green,
              child: Column(
                children: [
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
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Total Payment", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                      Text("\$5182", style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  )
                ],
              ),
            ),
          ),

          GestureDetector(
            onTap: () => Navigator.pushNamed(context, DisputesLogScreen.routeName),
            child: _buildCard(
              title: "Disputes Log",
              subtitle: "Last 12 months",
              icon: Icons.error,
              iconColor: Colors.red,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem("16", "Communication"),
                    _buildStatItem("2", "Transfer\nIssues"),
                    _buildStatItem("16", "Payment\nDisputes"),
                  ],
                ),
              ),
            ),
          ),

          GestureDetector(
            onTap: () => Navigator.pushNamed(context, BreachHistoryScreen.routeName),
            child: _buildCard(
              title: "Breach of Orders",
              subtitle: "Court order violations",
              icon: Icons.shield,
              iconColor: Colors.red,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: const [
                      Text("1", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                      SizedBox(height: 4),
                      Text("This Month", style: TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
            _buildCard(
              title: "Flagged Events",
              subtitle: "Requires attention",
              icon: Icons.flag,
              iconColor: Colors.orange,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem("2", "Custody", color: const Color(0xFF6200EE)),
                      _buildStatItem("1", "Payments", color: const Color(0xFF00C853)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem("1", "Disputes"),
                      _buildStatItem("1", "Breach Orders"),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Total Flagged", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                      Text("5", style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Icon(icon, color: iconColor, size: 24),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label, {Color color = Colors.black}) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.2),
        ),
      ],
    );
  }

  Widget _buildMoneyStat(String amount, String label, Color color) {
    return Column(
      children: [
        Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}