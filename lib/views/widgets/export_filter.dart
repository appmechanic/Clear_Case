import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExportFilterSheet extends StatefulWidget {
  final List<dynamic> children;
  final Function(ExportOptions) onApply;

  const ExportFilterSheet({
    super.key,
    required this.children,
    required this.onApply,
  });

  @override
  State<ExportFilterSheet> createState() => _ExportFilterSheetState();
}

class _ExportFilterSheetState extends State<ExportFilterSheet> {
  List<String> selectedChildIds = [];
  String? selectedTimePeriod;
  DateTime? startDate;
  DateTime? endDate;

  Map<String, bool> includeInReport = {
    "Custody": true,
    "Payments": true,
    "Disputes": true,
    "Non-Compliance": true,
    "Flagged Events": true,
  };

  @override
  void initState() {
    super.initState();
    selectedChildIds = widget.children.map((e) => e.id as String).toList();
     selectedTimePeriod = "All Time";
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
               Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              _buildHeader(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 10),
                    _sectionTitle("Children"),
                    _buildChildSelector(),
                    const SizedBox(height: 20),
                    _sectionTitle("Time Period"),
                    _buildTimePeriodChips(),
                    const SizedBox(height: 20),
                    _sectionTitle("Manual Entry"),
                    _buildManualDateRange(),
                    const SizedBox(height: 20),
                    _sectionTitle("Include in Report"),
                    _buildIncludeCheckboxes(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
              _buildApplyButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Export Report",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  // --- 1. Child Selector ---
  Widget _buildChildSelector() {
    bool isAllSelected = selectedChildIds.length == widget.children.length;
    return Column(
      children: [
        _childTile("Select All", isSelected: isAllSelected, onTap: () {
          setState(() {
            if (isAllSelected) {
              selectedChildIds.clear();
            } else {
              selectedChildIds =
                  widget.children.map((e) => e.id as String).toList();
            }
          });
        }),
        ...widget.children.map((child) => _childTile(
          child.name,
          isSelected: selectedChildIds.contains(child.id),
          onTap: () {
            setState(() {
              if (selectedChildIds.contains(child.id)) {
                selectedChildIds.remove(child.id);
              } else {
                selectedChildIds.add(child.id);
              }
            });
          },
        )),
      ],
    );
  }

  Widget _childTile(String title,
      {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. Time Period ---
  Widget _buildTimePeriodChips() {
    List<String> options = [
      "Last month",
      "Quarter",
      "Bi-annual",
      "Yearly",
      "Current FY",
      "All Time"
    ];
    return Wrap(
      spacing: 8,
      children: options.map((option) {
        bool isSelected = selectedTimePeriod == option;
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (val) => setState(() {
            selectedTimePeriod = val ? option : null;
          }),
          selectedColor: const Color(0xFFE3F2FD),
          labelStyle: TextStyle(
              color: isSelected ? const Color(0xFF6200EE) : Colors.black87),
        );
      }).toList(),
    );
  }

  // --- 3. Manual Date Entry ---
  Widget _buildManualDateRange() {
    return Row(
      children: [
        Expanded(
            child: _datePickerField("Start Date", startDate,
                    (date) => setState(() => startDate = date))),
        const SizedBox(width: 15),
        Expanded(
          child: _datePickerField(
            "End Date",
            endDate,
                (date) {
              if (startDate != null && date.isBefore(startDate!)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("End date cannot be before start date")));
                return;
              }
              setState(() => endDate = date);
            },
          ),
        ),
      ],
    );
  }

  Widget _datePickerField(
      String label, DateTime? selectedDate, Function(DateTime) onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        InkWell(
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    selectedDate != null
                        ? DateFormat('dd-MM-yyyy').format(selectedDate)
                        : "dd-mm-yyyy",
                    style: TextStyle(
                        color:
                        selectedDate != null ? Colors.black : Colors.grey)),
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 4. Include Checkboxes ---
  Widget _buildIncludeCheckboxes() {
    return Column(
      children: includeInReport.keys.map((key) {
        return CheckboxListTile(
          title: Text(key, style: const TextStyle(fontSize: 14)),
          value: includeInReport[key],
          activeColor: const Color(0xFF7B2CBF),
          contentPadding: EdgeInsets.zero,
          dense: true,
          onChanged: (val) => setState(() => includeInReport[key] = val!),
        );
      }).toList(),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7B2CBF),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: () {
          if (selectedChildIds.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Select at least one child")));
            return;
          }

          ExportOptions finalOptions = ExportOptions(
            childIds: selectedChildIds,
            timePeriod: selectedTimePeriod,
            startDate: startDate,
            endDate: endDate,
            reportSections: includeInReport,
          );

          widget.onApply(finalOptions);
          Navigator.pop(context);
        },
        child: const Text("Generate Report",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ),
    );
  }
}

class ExportOptions {
  final List<String> childIds;
  final String? timePeriod;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, bool> reportSections;

  ExportOptions({
    required this.childIds,
    this.timePeriod,
    this.startDate,
    this.endDate,
    required this.reportSections,
  });
}