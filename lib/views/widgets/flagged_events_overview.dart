import 'package:flutter/material.dart';

class FlaggedEventsOverview extends StatelessWidget {
  final int custodyCount;
  final int paymentsCount;
  final int disputesCount;
  final int nonComplianceCount;
  final int totalCount;

  const FlaggedEventsOverview({
    super.key,
    required this.custodyCount,
    required this.paymentsCount,
    required this.disputesCount,
    required this.nonComplianceCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Flagged Events",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Icon(Icons.flag, color: Colors.orange.shade400, size: 24),
            ],
          ),
          const Text(
            "Requires attention",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 25),

          // 2x2 Grid of Stats
          Row(
            children: [
              Expanded(child: _buildStatItem("$custodyCount", "Custody", const Color(0xFF9C27B0))),
              Expanded(child: _buildStatItem("$paymentsCount", "Payments", const Color(0xFF00BFA5))),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(child: _buildStatItem("$disputesCount", "Disputes", Colors.black87)),
              Expanded(child: _buildStatItem("$nonComplianceCount", "Non Compliance", Colors.black87)),
            ],
          ),

          const SizedBox(height: 15),
          // Footer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Flagged",
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              Text(
                "$totalCount",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}