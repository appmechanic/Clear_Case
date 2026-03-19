import 'package:clearcase/provider/breach_provider_insight.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/breach_model.dart';
import '../../models/case_model.dart';
import '../../provider/insight_provider.dart';
import '../widgets/custom_search_box.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class BreachHistoryScreen extends StatefulWidget {
  static const routeName = '/breach-history';
  const BreachHistoryScreen({super.key});

  @override
  State<BreachHistoryScreen> createState() => _BreachHistoryScreenState();
}

class _BreachHistoryScreenState extends State<BreachHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final selectedCase = ModalRoute.of(context)!.settings.arguments as dynamic;
      if (selectedCase != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Sync global case selection and fetch initial breaches
          final insightProv = Provider.of<InsightProvider>(context, listen: false);
          insightProv.setSelectedCase(selectedCase);

          Provider.of<BreachProviderInsight>(context, listen: false)
              .fetchBreaches(selectedCase.id);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Non Compliance", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Consumer2<BreachProviderInsight, InsightProvider>(
        builder: (context, breachProv, insightProv, child) {

          return RefreshIndicator(
            onRefresh: () async {
              if (insightProv.selectedCase != null) {
                await breachProv.fetchBreaches(insightProv.selectedCase!.id);
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Column(
                children: [
                  // --- CASE DROPDOWN ---
                  _buildDropdownSection(insightProv, breachProv),
                  const SizedBox(height: 20),

                  // Show loader only for the records section
                  if (breachProv.isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 50),
                      child: CircularProgressIndicator(),
                    ))
                  else ...[
                    _buildHeaderCard(breachProv),
                    const SizedBox(height: 20),
                    CustomSearchBar(
                      hintText: "Search by name, severity, type, party",
                      controller: _searchController,
                      onChanged: (val) => breachProv.filterBreaches(val),
                      onClear: () => breachProv.filterBreaches(""),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("Non Compliance History",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Icon(Icons.shield, color: Colors.red),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (breachProv.breaches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text("No compliance issues found.", style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: breachProv.breaches.length,
                        itemBuilder: (context, index) {
                          final record = breachProv.breaches[index];

                          bool showMonthHeader = false;
                          if (record.date != null) {
                            if (index == 0) showMonthHeader = true;
                            else {
                              final prevDate = breachProv.breaches[index - 1].date;
                              if (prevDate != null && (record.date!.month != prevDate.month || record.date!.year != prevDate.year)) {
                                showMonthHeader = true;
                              }
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showMonthHeader) _buildMonthHeader(record.date!),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/breach-details',
                                    arguments: record,
                                  );
                                },
                                child: _buildBreachItem(record),
                              ),
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

  // --- REUSABLE DROPDOWN ---
  Widget _buildDropdownSection(InsightProvider insightProv, BreachProviderInsight breachProv) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<dynamic>(
        isExpanded: true,
        value: insightProv.selectedCase,
        items: insightProv.allCases.map((caseItem) => DropdownMenuItem<dynamic>(
          value: caseItem,
          child: Text(insightProv.getCaseDisplayName(caseItem),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList(),
        onChanged: (value) {
          insightProv.setSelectedCase(value);
          if (value != null) {
            breachProv.fetchBreaches((value as CaseModel).id);
          }
        },
        buttonStyleData: const ButtonStyleData(height: 60, padding: EdgeInsets.zero),
        dropdownStyleData: DropdownStyleData(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildMonthHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(DateFormat('MMMM yyyy').format(date),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHeaderCard(BreachProviderInsight prov) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Icon(Icons.shield, color: Colors.red),
            ],
          ),
          const SizedBox(height: 10),
          Text("${prov.breaches.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32)),
          const Text("Total Issues", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat("${prov.totalSerious}", "Serious", Colors.red),
              _buildStat("${prov.totalModerate}", "Moderate", Colors.orange),
              _buildStat("${prov.totalMinor}", "Minor", Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreachItem(BreachRecordModel record) {
    Color severityColor = record.severity == "Serious" ? Colors.red :
    (record.severity == "Minor" ? Colors.green : Colors.orange);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(record.date != null ? DateFormat('MMM dd').format(record.date!) : "N/A",
                  style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (record.attachments != null && record.attachments!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                      child: const Icon(Icons.attachment, size: 14, color: Color(0xFF6200EE)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(record.severity,
                        style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(record.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(record.description, style: const TextStyle(color: Colors.black87, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(radius: 10, backgroundColor: Colors.purple.shade50, child: const Icon(Icons.person, size: 12, color: Colors.purple)),
              const SizedBox(width: 8),
              Text(record.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStat(String val, String label, Color color) {
    return Column(children: [
      Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))
    ]);
  }
}