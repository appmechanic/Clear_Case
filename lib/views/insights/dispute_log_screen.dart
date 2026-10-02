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
import '../widgets/child_tag.dart';
import '../../core/utils/attachments.dart';
import '../../core/utils/child_names.dart';
import 'dispute_log_details_screen.dart';
import '../home/new_dispute_screen.dart';
import '../widgets/quick_add_button.dart';

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
        // Start on the period the Insights screen is showing.
        _currentFilters.selectedTimePeriod =
            Provider.of<InsightProvider>(context, listen: false).timeframe;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final insightProv = Provider.of<InsightProvider>(context, listen: false);
          insightProv.setSelectedCase(selectedCase);
          Provider.of<DisputeInsightsProvider>(context, listen: false).fetchDisputes(selectedCase.id, timePeriod: _currentFilters.selectedTimePeriod);
        });
      }
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // After a Quick Add or pull-to-refresh: reload, then re-apply the filters
  // and search the screen is on (fetchDisputes resets the provider's).
  Future<void> _reloadAfterQuickAdd() async {
    if (!mounted) return;
    final selected = Provider.of<InsightProvider>(context, listen: false).selectedCase;
    if (selected == null) return;
    final provider = Provider.of<DisputeInsightsProvider>(context, listen: false);
    await provider.fetchDisputes(selected.id, timePeriod: _currentFilters.selectedTimePeriod);
    provider.applyAdvancedFilters(_currentFilters);
    provider.filterBySearch(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // Add an entry here without going back to the Calendar.
      floatingActionButton: QuickAddButton(
        label: "Add Dispute",
        routeName: NewDisputeScreen.routeName,
        onReturn: _reloadAfterQuickAdd,
      ),
      appBar: AppBar(
        title: const Text("Disputes Log", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Consumer2<DisputeInsightsProvider, InsightProvider>(
        builder: (context, disputeProv, insightProv, child) {
          return RefreshIndicator(
            onRefresh: _reloadAfterQuickAdd,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96), // clear of the Quick Add button
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
                      // Clearing the search keeps the filters picked in the sheet.
                      onClear: () => disputeProv.filterBySearch(""),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("Dispute History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Icon(Icons.error, color: Colors.redAccent),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (disputeProv.disputes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text("No disputes found.", style: TextStyle(color: Colors.grey)),
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
                              _buildDisputeItem(context, data, date, insightProv.selectedCase),
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
          // Child ids belong to the previous case; fetchDisputes also resets
          // the provider's filters, so start the new case unfiltered.
          setState(() {
            _currentFilters = FilterOptions(
              selectedTimePeriod: _currentFilters.selectedTimePeriod,
              selectedCategory: "All",
              selectedChildIds: [],
            );
          });
          _searchController.clear();
          if (value != null) disputeProv.fetchDisputes((value as CaseModel).id, timePeriod: _currentFilters.selectedTimePeriod);
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

  Widget _buildDisputeItem(
    BuildContext context,
    Map<String, dynamic> data,
    DateTime date,
    CaseModel? caseModel,
  ) {
    final String status = (data['disputeStatus'] ?? "Open").toString();
    final Color statusColor = status == "Resolved" ? Colors.green : Colors.red;
    final bool hasAttachments = readAttachmentUrls(data).isNotEmpty;
    final int logCount = data['logCount'] ?? 0;
    final String category = (data['category'] ?? "General").toString();
    final String description = (data['description'] ?? "").toString().trim();
    final String party = (data['party'] ?? "").toString().trim();
    final String name = (data['name'] ?? "").toString().trim();
    final String partyLine = [party, name].where((e) => e.isNotEmpty).join(" · ");

    return GestureDetector(
      onTap: () async {
        final provider = Provider.of<DisputeInsightsProvider>(context, listen: false);
        await Navigator.pushNamed(context, DisputeDetailsScreen.routeName, arguments: data);
        // Logs may have been added or deleted on the detail page.
        final caseId = data['caseId'], id = data['id'];
        if (caseId is String && id is String) provider.refreshLogCount(caseId, id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(DateFormat('MMM dd').format(date),
                    style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
                const Spacer(),
                if (hasAttachments)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                    child: const Icon(Icons.attachment, size: 14, color: Color(0xFF6200EE)),
                  ),
                _pill(status, statusColor),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill(category, const Color(0xFF7B2CBF)),
                ChildTag.forIds(readChildIds(data), caseModel),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description.isEmpty ? "No description" : description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: description.isEmpty ? Colors.grey : Colors.black87,
                fontSize: 13,
                fontStyle: description.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (partyLine.isNotEmpty) ...[
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.purple.shade50,
                    child: const Icon(Icons.person, size: 12, color: Colors.purple),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(partyLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(width: 8),
                const Icon(Icons.history, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text("$logCount ${logCount == 1 ? 'log' : 'logs'}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
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