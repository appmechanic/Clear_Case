import 'package:clearcase/views/insights/custody_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/case_model.dart';
import '../../models/filter_model.dart';
import '../../provider/custody_insight_provider.dart';
import '../../provider/insight_provider.dart';
import '../widgets/custom_search_box.dart';
import '../widgets/filter_ui.dart';

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
        Provider.of<CustodyInsightProvider>(context, listen: false)
            .fetchCustodyRecords(insightProv.selectedCase!.id);
      }
    });
  }

  void _openFilterSheet(dynamic selectedCase) {
    // Current filter state should be managed locally in state or pulled from provider
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommonFilterSheet(
        type: FilterType.custody,
        children: selectedCase?.children ?? [],
        initialOptions: FilterOptions(selectedTimePeriod: "All Time", selectedCategory: "All Records"),
        onApply: (newFilters) {
          Provider.of<CustodyInsightProvider>(context, listen: false).applyAdvancedFilters(newFilters);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar("Insights"),
      body: Consumer2<InsightProvider, CustodyInsightProvider>(
        builder: (context, insightProv, custodyProv, child) {
          return RefreshIndicator(
            onRefresh: () async {
              if (insightProv.selectedCase != null) {
                await custodyProv.fetchCustodyRecords(insightProv.selectedCase!.id);
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                  _buildHeaderCard(custodyProv), // Static UI as requested
                  const SizedBox(height: 20),
                  CustomSearchBar(
                    controller: _searchController,
                    hintText: "Search by notes...",
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
                    const Center(child: CircularProgressIndicator())
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

                        final bool isFulfilled = record['isFulfilled'] ?? false;
                        final bool hasAttachment = record['attachmentUrls'] != null && (record['attachmentUrls'] as List).isNotEmpty;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showMonthHeader) _buildMonthHeader(startDate!),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, CustodyDetailsScreen.routeName,arguments: record),
                              child: _buildCustodyItem(
                                date: startDate != null ? DateFormat('MMM dd').format(startDate) : "N/A",
                                title: record['isScheduled'] == true ? "Scheduled Custody" : "Non-Scheduled Custody",
                                desc: record['notes'] ?? "No notes provided",
                                isFulfilled: isFulfilled,
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

  Widget _buildCustodyItem({
    required String date,
    required String title,
    required String desc,
    required bool isFulfilled,
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
              Text(date, style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
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
                      color: isFulfilled ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isFulfilled ? "Fulfilled" : "Unfulfilled",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isFulfilled ? Colors.green : Colors.red
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
  Widget _buildHeaderCard(CustodyInsightProvider custodyProv) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Custody Compliance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Icon(Icons.person, color: Colors.purple),
            ],
          ),
          const Text("December 2025", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat("16", "Custody Days\n(fulfilled)"),
              _buildStat("2", "With\nJustification"),
              _buildStat("16", "Missed Days\n(No Justification)"),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Overall Compliance", style: TextStyle(color: Colors.black54)),
              Text("96%", style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          )
        ],
      ),
    );
  }


  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        Container(margin: const EdgeInsets.only(right: 20), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)), child: Row(children: const [Text("Export", style: TextStyle(color: Colors.blue)), SizedBox(width: 5), Icon(Icons.upload, size: 16, color: Colors.blue)])),
      ],
    );
  }



  Widget _buildStat(String val, String label) {
    return Column(children: [Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey))]);
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
          if (value != null) custodyProv.fetchCustodyRecords((value as CaseModel).id);
        },
        buttonStyleData: const ButtonStyleData(height: 60, padding: EdgeInsets.zero),
        dropdownStyleData: DropdownStyleData(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

}