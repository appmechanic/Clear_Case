import 'package:clearcase/views/insights/custody_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/attachments.dart';
import '../../core/utils/custody_span.dart';
import '../../core/utils/timeframe.dart';
import '../../models/case_model.dart';
import '../../models/filter_model.dart';
import '../../provider/custody_insight_provider.dart';
import '../../provider/insight_provider.dart';
import '../widgets/custom_search_box.dart';
import '../widgets/filter_ui.dart';
import '../home/new_custody_screen.dart';
import '../widgets/quick_add_button.dart';

 class CustodyComplianceScreen extends StatefulWidget {
   static const routeName = '/custody-insight-compliance';
   const CustodyComplianceScreen({super.key});
 
   @override
   State<CustodyComplianceScreen> createState() => _CustodyComplianceScreenState();
 }

class _CustodyComplianceScreenState extends State<CustodyComplianceScreen>{
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final insightProv = Provider.of<InsightProvider>(context, listen: false);
      if (insightProv.selectedCase != null) {
        // Open on the same period the Insights screen is showing.
        Provider.of<CustodyInsightProvider>(context, listen: false)
            .fetchCustodyRecords(insightProv.selectedCase!.id, timePeriod: insightProv.timeframe);
      }
    });
  }

  void _openFilterSheet(dynamic selectedCase) {
    final custodyProv = Provider.of<CustodyInsightProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommonFilterSheet(
        type: FilterType.custody,
        children: selectedCase?.children ?? [],
        initialOptions: custodyProv.currentFilters,
        onApply: (newFilters) {
          Provider.of<CustodyInsightProvider>(context, listen: false).applyAdvancedFilters(newFilters);
        },
      ),
    );
  }

  // After a Quick Add: reload, then re-apply the filters and search the
  // screen is on.
  Future<void> _reloadAfterQuickAdd() async {
    if (!mounted) return;
    final selected = Provider.of<InsightProvider>(context, listen: false).selectedCase;
    if (selected == null) return;
    final provider = Provider.of<CustodyInsightProvider>(context, listen: false);
    final filters = provider.currentFilters;
    await provider.fetchCustodyRecords(selected.id, timePeriod: filters.selectedTimePeriod);
    provider.applyAdvancedFilters(filters);
    provider.filterBySearch(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // Add an entry here without going back to the Calendar.
      floatingActionButton: QuickAddButton(
        label: "Add Custody",
        routeName: NewCustodyScreen.routeName,
        onReturn: _reloadAfterQuickAdd,
      ),
      appBar: _buildAppBar("Insights"),
      body: Consumer2<InsightProvider, CustodyInsightProvider>(
        builder: (context, insightProv, custodyProv, child) {
          return RefreshIndicator(
            onRefresh: () async {
              if (insightProv.selectedCase != null) {
                // Execute them sequentially
                await insightProv.listenToUserCases();
                await custodyProv.fetchCustodyRecords(insightProv.selectedCase!.id,
                    timePeriod: custodyProv.currentFilters.selectedTimePeriod);
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96), // clear of the Quick Add button
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()
              ),
              child: Column(
                children: [
                  // Dropdown Row
                  Row(
                    children: [
                      Expanded(child: _buildDropdownSection(insightProv, custodyProv)),
                      const SizedBox(width: 12),
                      _buildFilterButton(insightProv.selectedCase),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildHeaderCard(custodyProv),
                  const SizedBox(height: 20),
                  CustomSearchBar(
                    controller: _searchController,
                    hintText: "Search notes or location...",
                    onChanged: (val) => custodyProv.filterBySearch(val),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Custody Records", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Icon(Icons.person, color: Colors.purple),
                    ],
                  ),



                  if (custodyProv.isLoading)
                    const Center(child: CircularProgressIndicator()),
                  if (custodyProv.records.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text("No Custody found for this case.", style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: custodyProv.records.length,
                      itemBuilder: (context, index) {
                        final record = custodyProv.records[index];
                        final DateTime? startDate = (record['startDate'] as Timestamp?)?.toDate();

                        // MONTH HEADER LOGIC
                        bool showMonthHeader = false;
                        if (startDate != null) {
                          if (index == 0) showMonthHeader = true;
                          else {
                            final prevDate = (custodyProv.records[index - 1]['startDate'] as Timestamp?)?.toDate();
                            if (prevDate != null && (startDate.month != prevDate.month || startDate.year != prevDate.year)) {
                              showMonthHeader = true;
                            }
                          }
                        }

                        final span = CustodySpan.fromMap(record);
                        final bool hasAttachment = readAttachmentUrls(record).isNotEmpty;
                        final String notes = (record['notes'] ?? "").toString().trim();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showMonthHeader) _buildMonthHeader(startDate!),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, CustodyDetailsScreen.routeName,arguments: record),
                              child: _buildCustodyItem(
                                date: span?.label ?? "N/A",
                                title: _childNames(insightProv.selectedCase, record['childIds']),
                                desc: notes.isEmpty ? "No notes provided" : notes,
                                nights: span?.nights ?? 0,
                                hasAttachment: hasAttachment,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
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

  // Names of the children an entry is for, e.g. "Emma, Liam".
  String _childNames(CaseModel? selectedCase, dynamic childIds) {
    final ids = (childIds as List?)?.map((e) => e.toString()).toSet() ?? {};
    final names = (selectedCase?.children ?? const <ChildModel>[])
        .where((c) => ids.contains(c.id))
        .map((c) => c.name.trim())
        .toList();
    return names.isEmpty ? "Custody Entry" : names.join(", ");
  }

  Widget _buildCustodyItem({
    required String date,
    required String title,
    required String desc,
    required int nights,
    required bool hasAttachment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(date, style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  if (hasAttachment)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                      child: const Icon(Icons.attachment, size: 14, color: Color(0xFF6200EE)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      nightsLabel(nights),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFilterButton(dynamic selectedCase) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: IconButton(
        icon: const Icon(Icons.filter_list_rounded, color: Colors.purple),
        onPressed: () => _openFilterSheet(selectedCase),
      ),
    );
  }

  // Totals for the entries currently shown (period + child filter + search).
  Widget _buildHeaderCard(CustodyInsightProvider custodyProv) {
    final String currentPeriod = Timeframe.describe(custodyProv.currentFilters.selectedTimePeriod);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Custody Compliance",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Icon(Icons.person, color: Colors.purple),
            ],
          ),
          Text(currentPeriod, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat("${custodyProv.totalNights}", "Total\nNights"),
              _buildStat("${custodyProv.totalEntries}", "Total\nEntries"),
            ],
          ),
        ],
      ),
    );
  }

// Updated _buildStat to support dynamic colors and better alignment
  Widget _buildStat(String val, String label, {Color color = Colors.black}) {
    return Expanded( // Added Expanded to ensure equal spacing like the main Insights screen
      child: Column(
        children: [
          Text(val,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey, height: 1.2))
        ],
      ),
    );
  }

  // No Export here — reports are exported from the main Insights screen.
  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
    );
  }


  Widget _buildDropdownSection(InsightProvider insightProv, CustodyInsightProvider custodyProv) {
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
          if (value != null) {
            custodyProv.fetchCustodyRecords((value as CaseModel).id,
                timePeriod: custodyProv.currentFilters.selectedTimePeriod);
          }
        },
        buttonStyleData: const ButtonStyleData(height: 60, padding: EdgeInsets.zero),
        dropdownStyleData: DropdownStyleData(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),color: Colors.white)),
      ),
    );
  }

}