import 'package:clearcase/views/insights/payment_analytics_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/insight_provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import '../widgets/dispute_overview.dart';
import '../widgets/export_button.dart';
import '../widgets/export_filter.dart';
import '../widgets/flagged_events_overview.dart';
import '../widgets/non_complicance_overview.dart';
import '../widgets/payment_overview_card.dart';
import '../widgets/pdf_generator.dart';
import 'breach_history_screen.dart';
import 'custody_compliance_screen.dart';
import 'dispute_log_screen.dart';

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
          title: const Text("Insights",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 24)),
          centerTitle: false,
          automaticallyImplyLeading: false),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<InsightProvider>().refreshAllData();
        },
        child: Consumer<InsightProvider>(
          builder: (context, insightProvider, child) {
            if (insightProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (insightProvider.allCases.isEmpty) {
              return const Center(child: Text("No cases found."));
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Wrap dropdown in Expanded so it takes remaining space
                      Expanded(
                        child: _buildDropdownSection(insightProvider),
                      ),
                      const SizedBox(width: 10),

                      ExportButton(
                          onTap: () async {
                             await insightProvider.fetchAllEventsForReport();

                             final childrenList = insightProvider.children;

                            if (childrenList.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("No children found for this case.")),
                              );
                              return;
                            }

                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => ExportFilterSheet(
                                   children: childrenList,
                                  onApply: (options) {
                                    PDFGenerator.generateReport(
                                      caseName: insightProvider.selectedCase?.caseNumber ?? "Case Report",
                                      options: options,
                                      allEvents: insightProvider.allEvents,
                                    );
                                  }
                              ),
                            );
                          }
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),


                         _buildCard(
                          title: "Custody Compliance",
                          subtitle: "Current Period",
                          icon: Icons.person,
                          iconColor: Colors.purple,
                          onTap: () {
                            Navigator.pushNamed(
                            context,
                            CustodyComplianceScreen.routeName,
                            arguments: insightProvider.selectedCase,
                          ); },
                          child: Column(
                            children: [
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                   _buildStatItem("${insightProvider.fulfilledDays}", "Custody Days\n(fulfilled)"),
                                  _buildStatItem("${insightProvider.justifiedDays}", "With\nJustification"),
                                  _buildStatItem("${insightProvider.missedDays}", "Missed Days\n(No Just.)", color: Colors.red),
                                ],
                              ),
                              const SizedBox(height: 15),
                              const Divider(),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Overall Compliance", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                                  Text("${insightProvider.complianceRate.toStringAsFixed(1)}%",
                                      style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Divider(),
                        const SizedBox(height: 10),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Overall Compliance", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                            Text("0%", style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                     PaymentOverview(
                    provider: insightProvider,
                    subtitle: "Case Overview",
                    onTap: () {
                      if (insightProvider.selectedCase != null) {
                        Navigator.pushNamed(
                          context,
                          PaymentAnalyticsScreen.routeName,
                          arguments: insightProvider.selectedCase,
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 20),
                  DisputeOverview(
                    provider: insightProvider,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        DisputesLogScreen.routeName,
                        arguments: insightProvider.selectedCase,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  BreachOverview(
                    provider: insightProvider,
                    onTap: () {
                      if (insightProvider.selectedCase != null) {
                        Navigator.pushNamed(
                          context,
                          BreachHistoryScreen.routeName,
                          arguments: insightProvider.selectedCase,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. Flagged Events Card
                  // Inside your Screen build method or ListView
                  FlaggedEventsOverview(
                    custodyCount: insightProvider.flaggedCustodyCount,
                    paymentsCount: insightProvider.flaggedPaymentsCount,
                    disputesCount: insightProvider.flaggedDisputesCount,
                    breachCount: insightProvider.flaggedBreachCount,
                    totalCount: insightProvider.totalFlaggedCount,
                  ),

                 ],
              ),
            );
          },
        ),
      ),

    );
  }

  // --- Updated Card Helper with Navigation Support ---
  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    VoidCallback? onTap, // Added onTap callback
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material( // Wrap with Material for InkWell ripple
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
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(subtitle,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ]),
                    Icon(icon, color: iconColor, size: 24),
                  ],
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Rest of the helper methods remain the same but use Expanded for better grid alignment
  Widget _buildStatItem(String count, String label, {Color color = Colors.black}) {
    return Expanded(
      child: Column(
        children: [
          Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.2)),
        ],
      ),
    );
  }


  Widget _buildDropdownSection(InsightProvider provider) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<dynamic>(
        isExpanded: true,
        value: provider.selectedCase,
        items: provider.allCases.map((caseItem) => DropdownMenuItem<dynamic>(
          value: caseItem,
          child: Text(provider.getCaseDisplayName(caseItem), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList(),
        onChanged: (value) => provider.setSelectedCase(value),
        buttonStyleData: const ButtonStyleData(height: 60, padding: EdgeInsets.zero),
        dropdownStyleData: DropdownStyleData(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }
}