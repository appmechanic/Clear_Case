import 'package:flutter/material.dart';
import '../../models/case_model.dart';
import '../../provider/scheduled_dates_provider.dart';
import '../widgets/loader.dart';
import 'rule_configuration_screen.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';


class ScheduledDatesScreen extends StatelessWidget {
  static const routeName = '/scheduled-dates';
  const ScheduledDatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dynamic args = ModalRoute.of(context)!.settings.arguments;
    final String? initialCaseId = args is CaseModel ? args.id : (args is String ? args : null);
    return ChangeNotifierProvider(
      create: (_) => ScheduledDatesProvider()..init(initialCaseId: initialCaseId),
            child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            "Scheduled dates",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
        ),
        body: Consumer<ScheduledDatesProvider>(
          builder: (context, provider, child) {
            // 1. Full Screen Loader
            if (provider.isLoading) {
              return const Center(child: AppLoader());
            }

            // 2. Empty State
            if (provider.allCases.isEmpty) {
              return const Center(
                child: Text("No cases found.", style: TextStyle(color: Colors.grey)),
              );
            }

            // 3. Main Content
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Case",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),

                  _buildDropdownSection(provider),

                  const SizedBox(height: 25),

                  _buildRuleCard(
                    context,
                    title: "Scheduled Custody",
                    desc: "Set up recurring custody schedules, handover times, and parenting arrangements...",
                    tags: ["Court-ordered", "Time-sensitive", "Compliance Tracking"],
                    color: Colors.green,
                    isSet: provider.hasCustody,
                    recordId: provider.custodyRecordId,
                    category: "custody",
                  ),

                  _buildRuleCard(
                    context,
                    title: "Scheduled Payments",
                    desc: "Configure recurring child support payments, medical expenses...",
                    tags: ["Financial", "Recurring", "Payment tracking"],
                    color: Colors.orange,
                    isSet: provider.hasPayments,
                    recordId: provider.paymentRecordId,
                    category: "payment",
                  ),

                  _buildRuleCard(
                    context,
                    title: "Custom Order",
                    desc: "Create custom rules for communication schedules, special events...",
                    tags: ["Flexible", "Customizable", "Multi-purpose"],
                    color: Colors.blue,
                    isSet: provider.hasCustom,
                    recordId: provider.customOrderId,
                    category: "custom",
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  Widget _buildDropdownSection(ScheduledDatesProvider provider) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<dynamic>(
        isExpanded: true,
        value: provider.selectedCase,
        selectedItemBuilder: (context) {
          return provider.allCases.map((caseItem) {
            return Container(
              alignment: Alignment.centerLeft,
              constraints: const BoxConstraints(minHeight: 48), // Gives enough vertical space
              child: Text(
                provider.getCaseDisplayName(caseItem),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
                // REMOVED: maxLines: 1 and TextOverflow.ellipsis
                softWrap: true, // This allows the text to wrap
              ),
            );
          }).toList();
        },
        items: provider.allCases.map((caseItem) => DropdownMenuItem<dynamic>(
          value: caseItem,
          child: Text(
            provider.getCaseDisplayName(caseItem),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            softWrap: true, // Also allow wrapping inside the menu
          ),
        )).toList(),
        onChanged: (value) => provider.setSelectedCase(value),
        buttonStyleData: const ButtonStyleData(
          padding: EdgeInsets.zero,
          height: 60, // INCREASED height to accommodate two lines
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 24),
          openMenuIcon: Icon(Icons.keyboard_arrow_up, color: Colors.black, size: 24),
        ),
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white
          ),
          offset: const Offset(0, -5),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildRuleCard(BuildContext context, {
    required String title,
    required String desc,
    required List<String> tags,
    required Color color,
    required bool isSet,
    required String? recordId,
    required String category,
  }) {
    // Note: Fetching without listening as this is inside an event handler
    final provider = Provider.of<ScheduledDatesProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSet ? Border.all(color: color, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (isSet)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          RuleConfigurationScreen.routeName,
                          arguments: {
                            'caseId': provider.selectedCase?.id,
                            'category': category, // <--- ADD THIS LINEad
                            'availableChildren': provider.selectedCase?.children ?? [], // Pass the children!
                          },
                        );
                      },
                    ),
                    // Inside _buildRuleCard...
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () {

                        _showDeleteDialog(
                            context,
                            provider.selectedCase!.id,
                            recordId!,
                            category,
                            provider
                        );
                      },
                    ),
                  ],
                )
              else
                IconButton(
                  icon: Icon(Icons.add_circle, color: color, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      RuleConfigurationScreen.routeName,
                      arguments: {
                        'caseId': provider.selectedCase?.id,

                        'category': category,
                        'availableChildren': provider.selectedCase?.children ?? [], // CRITICAL: This must not be empty
                      },
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(t, style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.bold)
              ),
            )).toList(),
          )
        ],
      ),
    );
  }


  void _showDeleteDialog(BuildContext context, String caseId, String recordId, String category, ScheduledDatesProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Delete Rule",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 20),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Are you sure you want to Delete this rule?",
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Cancel Button
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B39B2), // Purple color from image
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      ),
                      child: const Text("Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    // Delete Button
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close dialog
                        await provider.deleteRule(provider.selectedCase!.id, recordId, category);
                       },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE55353), // Red color from image
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      ),
                      child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

}