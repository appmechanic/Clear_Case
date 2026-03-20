import 'package:flutter/material.dart';

import '../../provider/insight_provider.dart';

class DisputeOverview extends StatelessWidget {
  final InsightProvider provider;
  final VoidCallback? onTap;

  const DisputeOverview({super.key, required this.provider, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Disputes Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                       ],
                    ),
                    const Icon(Icons.error, color: Colors.redAccent, size: 28),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem("${provider.communicationCount}", "Communica\ntion"),
                    _buildStatItem("${provider.transferIssuesCount}", "Transfer\nIssues"),
                    _buildStatItem("${provider.paymentDisputesCount}", "Payment\nDisputes"),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}