import 'package:flutter/material.dart';
import '../../provider/insight_provider.dart';

class PaymentOverview extends StatelessWidget {
  final InsightProvider provider;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showShadow;

  const PaymentOverview({
    super.key,
    required this.provider,
    this.title = "Payment Tracking",
    this.subtitle,
    this.onTap,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: showShadow
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
            : null,
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
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle!,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ]
                        ],
                      ),
                    ),
                    const Icon(Icons.payment, color: Colors.green, size: 24),
                  ],
                ),
                const SizedBox(height: 20),

                // First Row: Paid & Received
                Row(
                  children: [
                    Expanded(
                      child: _buildMoneyStat(
                          "\$${provider.totalPaid.toInt()}",
                          "Payments Paid",
                          const Color(0xFF6200EE)),
                    ),
                    Expanded(
                      child: _buildMoneyStat(
                          "\$${provider.totalReceived.toInt()}",
                          "Payments Received",
                          const Color(0xFF00C853)),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // Second Row: Compulsory & Additional
                Row(
                  children: [
                    Expanded(
                      child: _buildMoneyStat(
                          "\$${provider.totalCompulsory.toInt()}",
                          "Compulsory",
                          Colors.black),
                    ),
                    Expanded(
                      child: _buildMoneyStat(
                          "\$${provider.totalAdditional.toInt()}",
                          "Additional",
                          Colors.black),
                    ),
                  ],
                ),

                const Divider(height: 40),

                // Footer Total Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Payment",
                        style: TextStyle(
                            color: Colors.black54, fontWeight: FontWeight.w500)),
                    Text(
                      "\$${provider.totalPayments.toInt()}",
                      style: const TextStyle(
                          color: Color(0xFF00C853),
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoneyStat(String amount, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(amount,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 22, color: color)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          softWrap: true,
        ),
      ],
    );
  }
}