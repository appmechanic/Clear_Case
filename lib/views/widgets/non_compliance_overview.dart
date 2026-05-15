import 'package:flutter/material.dart';

import '../../provider/insight_provider.dart';

class NonComplianceOverview extends StatelessWidget {
  final InsightProvider provider;
  final String subtitle;
  final VoidCallback? onTap;

  const NonComplianceOverview({
    super.key,
    required this.provider,
    this.subtitle = "Court order violations",
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Non Compliance",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const Icon(Icons.shield, color: Color(0xFFEF5350), size: 24),
                  ],
                ),
                const SizedBox(height: 20),
                // Centered Total Count
                Text(
                  "${provider.totalNonComplianceCount}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 36, // Slightly larger for emphasis
                    color: Colors.black,
                  ),
                ),
                const Text(
                  "Total Issues",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
