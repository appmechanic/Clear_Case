 import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
 import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../models/filter_model.dart';
import '../../provider/dispute_insight_provider.dart';
import '../../provider/insight_provider.dart';
 import '../../models/case_model.dart';
import '../widgets/custom_search_box.dart';
import '../widgets/filter_ui.dart';
import 'dispute_log_details_screen.dart';

class DisputesLogScreen extends StatefulWidget {
  static const routeName = '/disputes-log';
  const DisputesLogScreen({super.key});

  @override
  State<DisputesLogScreen> createState() => _DisputesLogScreenState();
}

class _DisputesLogScreenState extends State<DisputesLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isInit = true;

  // Change your local state to this:
  FilterOptions _currentFilters = FilterOptions(
    selectedTimePeriod: "All Time",
    selectedCategory: "All",
    selectedChildIds: [], // Empty means "Select All" in your logic
  );

  void _openFilterSheet(dynamic selectedCase) {
    // Get the LATEST filters from the provider before opening
    final provider = Provider.of<DisputeInsightsProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommonFilterSheet(
        type: FilterType.dispute,
        children: selectedCase?.children ?? [],
        // Use the Provider's current state as the starting point
        initialOptions: _currentFilters,
        onApply: (newFilters) {
          setState(() => _currentFilters = newFilters);
          provider.applyAdvancedFilters(newFilters);
        },
      ),
    );
  }
  @override
  void didChangeDependencies() {
    if (_isInit) {
      final selectedCase = ModalRoute.of(context)!.settings.arguments as dynamic;
      if (selectedCase != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final insightProv = Provider.of<InsightProvider>(context, listen: false);
          insightProv.setSelectedCase(selectedCase);
          Provider.of<DisputeInsightsProvider>(context, listen: false).fetchDisputes(selectedCase.id);
        });
      }
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Disputes Log", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Consumer2<DisputeInsightsProvider, InsightProvider>(
        builder: (context, disputeProv, insightProv, child) {
          return RefreshIndicator(
            onRefresh: () => disputeProv.fetchDisputes(insightProv.selectedCase!.id),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Column(
                children: [

                  Row(
                    children: [
                      // 1. Case Dropdown (Takes remaining space)
                      Expanded(
                        child:  _buildDropdownSection(insightProv, disputeProv),
                      ),
                      const SizedBox(width: 12),
                      // 2. Filter Icon Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF7B2CBF)),
                          onPressed: () => _openFilterSheet(insightProv.selectedCase),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (disputeProv.isLoading)
                    const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 50), child: CircularProgressIndicator()))
                  else ...[
                    _buildHeaderCard(disputeProv),
                    const SizedBox(height: 20),
                    CustomSearchBar(
                      controller: _searchController,
                      hintText: "Search by status, category, name",
                      onChanged: (val) => disputeProv.filterBySearch(val),
                      onClear: () => disputeProv.clearAll(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("Dispute Analytics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Icon(Icons.error, color: Colors.redAccent),
                      ],
                    ),

                    if (disputeProv.disputes.isEmpty)
                      const Column(
                        children: [
                          SizedBox(height: 10,),
                          Text("No disputes found.", style: TextStyle(color: Colors.grey))
                        ],
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: disputeProv.disputes.length,
                        itemBuilder: (context, index) {
                          final data = disputeProv.disputes[index];
                          final date = (data['date'] as Timestamp).toDate();

                          bool showMonthHeader = false;
                          if (index == 0) showMonthHeader = true;
                          else {
                            final prevDate = (disputeProv.disputes[index - 1]['date'] as Timestamp).toDate();
                            if (date.month != prevDate.month || date.year != prevDate.year) showMonthHeader = true;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showMonthHeader) _buildMonthHeader(date),
                              _buildDisputeItem(context, data, date),
                            ],
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdownSection(InsightProvider insightProv, DisputeInsightsProvider disputeProv) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<dynamic>(
        isExpanded: true,
        value: insightProv.selectedCase,
        items: insightProv.allCases.map((c) => DropdownMenuItem<dynamic>(
          value: c,
          child: Text(insightProv.getCaseDisplayName(c), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList(),
        onChanged: (value) {
          insightProv.setSelectedCase(value);
          if (value != null) disputeProv.fetchDisputes((value as CaseModel).id);
        },
        buttonStyleData: const ButtonStyleData(height: 60, padding: EdgeInsets.zero),
        dropdownStyleData: DropdownStyleData(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white)),
      ),
    );
  }

  Widget _buildHeaderCard(DisputeInsightsProvider prov) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat("${prov.commCount}", "Communication"),
              _buildStat("${prov.transferCount}", "Transfer\nIssues"),
              _buildStat("${prov.paymentCount}", "Payment\nDisputes"),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat("${prov.openCount}", "Open", color: Colors.red),
              _buildStat("${prov.resolvedCount}", "Resolved", color: Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeItem(BuildContext context, Map<String, dynamic> data, DateTime date) {
    final status = data['disputeStatus'] ?? "Open";
    final color = status == "Open" ? Colors.red : Colors.green;
    final hasAttachments = (data['attachments'] as List?)?.isNotEmpty ?? false;
    final int logCount = data['logCount'] ?? 0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, DisputeDetailsScreen.routeName, arguments: data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(DateFormat('MMM dd').format(date), style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
                      if (hasAttachments) ...[
                        const SizedBox(width: 8),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                          child: const Icon(Icons.attachment, size: 14, color: Color(0xFF6200EE)),
                        ),                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(data['category'] ?? "General", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                      "$logCount ${logCount == 1 ? 'log' : 'logs'}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12)
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(DateFormat('MMMM yyyy').format(date),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildStat(String val, String label, {Color color = Colors.black}) {
    return Column(children: [
      Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey))
    ]);
  }
}