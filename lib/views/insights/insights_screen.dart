import 'package:clearcase/views/insights/payment_analytics_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/timeframe.dart';
import '../../provider/insight_provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import '../widgets/dispute_overview.dart';
import '../widgets/export_button.dart';
import '../widgets/export_filter.dart';
import '../widgets/flagged_events_overview.dart';
import 'flagged_events_screen.dart';
import '../widgets/non_compliance_overview.dart';
import '../widgets/payment_overview_card.dart';
import '../widgets/pdf_generator.dart';
import 'non_compliance_history_screen.dart';
import 'custody_compliance_screen.dart';
import 'dispute_log_screen.dart';
import '../home/new_entry_screen.dart';
import '../widgets/quick_add_button.dart';

class InsightsScreen extends StatelessWidget {
  static const routeName = '/insights';
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // Quick Add: pick any entry type from here instead of the Calendar.
      floatingActionButton: const QuickAddButton(
        routeName: NewEntryScreen.routeName,
      ),
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Insights",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 24)),
          centerTitle: false,
          automaticallyImplyLeading: false,
          // Reporting period for every card below, and the default for the
          // Export sheet. Sits directly above the Export button.
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Consumer<InsightProvider>(
                builder: (context, provider, _) => _buildTimeframeDropdown(provider),
              ),
            ),
          ]),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<InsightProvider>().listenToUserCases();
          await Future.delayed(const Duration(milliseconds: 500));
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96), // clear of Quick Add
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
                                  initialTimePeriod: insightProvider.timeframe,
                                  onApply: (options, onProgress) async {
                                    await PDFGenerator.generateReport(
                                      caseName: insightProvider.selectedCase?.caseNumber ?? "Case Report",
                                      caseId: insightProvider.selectedCase?.id ?? '',
                                      options: options,
                                      allEvents: insightProvider.allEvents,
                                      caseModel: insightProvider.selectedCase,
                                      onProgress: onProgress,
                                    );
                                  }
                              ),
                            );
                          }
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),


                  // What actually happened in the period: nights covered by
                  // custody entries and how many entries were recorded.
                  _buildCard(
                    title: "Custody Compliance",
                    subtitle: Timeframe.describe(insightProvider.timeframe),
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
                            _buildStatItem("${insightProvider.totalCustodyNights}", "Total\nNights"),
                            _buildStatItem("${insightProvider.totalCustodyEntries}", "Total\nEntries"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),


                  PaymentOverview(
                    provider: insightProvider,
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
                  NonComplianceOverview(
                    provider: insightProvider,
                    onTap: () {
                      if (insightProvider.selectedCase != null) {
                        Navigator.pushNamed(
                          context,
                          NonComplianceHistoryScreen.routeName,
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
                    nonComplianceCount: insightProvider.flaggedNonComplianceCount,
                    totalCount: insightProvider.totalFlaggedCount,
                    onTap: () {
                      if (insightProvider.selectedCase != null) {
                        Navigator.pushNamed(
                          context,
                          FlaggedEventsScreen.routeName,
                        );
                      }
                    },
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


  Widget _buildTimeframeDropdown(InsightProvider provider) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        value: provider.timeframe,
        items: Timeframe.options.map((option) => DropdownMenuItem<String>(
          value: option,
          child: Text(Timeframe.label(option), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        )).toList(),
        selectedItemBuilder: (context) => Timeframe.options.map((option) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(Timeframe.label(option),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ],
        )).toList(),
        onChanged: (value) {
          if (value != null) provider.setTimeframe(value);
        },
        buttonStyleData: ButtonStyleData(
          height: 36,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
        ),
        dropdownStyleData: DropdownStyleData(
          width: 240,
          offset: const Offset(-60, -4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white),
        ),
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
        dropdownStyleData: DropdownStyleData(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
        color: Colors.white

        )),
      ),
    );
  }
}