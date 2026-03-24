import 'package:flutter/material.dart';

import '../../models/filter_model.dart';

class CommonFilterSheet extends StatefulWidget {
  final FilterType type;
  final List<dynamic> children; // Pass list of Child objects from Case
  final FilterOptions initialOptions;
  final Function(FilterOptions) onApply;

  const CommonFilterSheet({
    super.key,
    required this.type,
    required this.children,
    required this.initialOptions,
    required this.onApply,
  });

  @override
  State<CommonFilterSheet> createState() => _CommonFilterSheetState();
}

class _CommonFilterSheetState extends State<CommonFilterSheet> {
  late FilterOptions _tempOptions;

// Inside _CommonFilterSheetState
  @override
  void initState() {
    // Create a deep copy so we don't modify the parent state until 'Apply' is pressed
    _tempOptions = FilterOptions(
      selectedTimePeriod: widget.initialOptions.selectedTimePeriod,
      selectedCategory: widget.initialOptions.selectedCategory,
      selectedChildIds: List.from(widget.initialOptions.selectedChildIds),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),

          // 1. Children Section
          const Text("Children", style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 10),
          _buildChildSelector(),

          const SizedBox(height: 20),

          // 2. Time Period Section
          const Text("Time Period", style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 10),
          _buildChipGroup(
            [
              "Last month",
              "Quarter",
              "Bi-annual",
              "Yearly",
              "Current Financial year",
              "All Time"
            ],
            _tempOptions.selectedTimePeriod,
                (val) => setState(() => _tempOptions.selectedTimePeriod = val),
          ),

          const SizedBox(height: 20),

          // 3. Dynamic Category Section (Payment Type / Status / Severity)
          Text(_getCategoryLabel(), style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 10),
          _buildChipGroup(
            _getCategoryOptions(),
            _tempOptions.selectedCategory,
                (val) => setState(() => _tempOptions.selectedCategory = val),
          ),

          const SizedBox(height: 30),

          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B2CBF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                widget.onApply(_tempOptions);
                Navigator.pop(context);
              },
              child: const Text("Apply Filters", style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Filters",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        IconButton(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildChildSelector() {
    return Column(
      children: [
        _childTile("Select All", isAll: true),
        ...widget.children.map((child) => _childTile(child.name, id: child.id)),
      ],
    );
  }

  Widget _childTile(String title, {String? id, bool isAll = false}) {
    bool isSelected = isAll
        ? _tempOptions.selectedChildIds.length == widget.children.length
        : _tempOptions.selectedChildIds.contains(id);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isAll) {
            if (isSelected) {
              _tempOptions.selectedChildIds.clear();
            } else {
              _tempOptions.selectedChildIds =
                  widget.children.map((e) => e.id as String).toList();
            }
          } else {
            if (isSelected) {
              _tempOptions.selectedChildIds.remove(id);
            } else {
              _tempOptions.selectedChildIds.add(id!);
            }
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey
                  .shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipGroup(List<String> options, String? selected,
      Function(String) onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        bool isSelected = selected == option;
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) => onSelect(option),
          selectedColor: const Color(0xFFE3F2FD),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF6200EE) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: isSelected ? const Color(0xFF6200EE) : Colors.grey
                    .shade300),
          ),
        );
      }).toList(),
    );
  }

  String _getCategoryLabel() {
    switch (widget.type) {
      case FilterType.payment:
        return "Payment Type";
      case FilterType.dispute:
        return "Status";
      case FilterType.nonCompliance:
        return "Severity";
      case FilterType.custody:
        return "Custody Type";
    }
  }

  List<String> _getCategoryOptions() {
    switch (widget.type) {
      case FilterType.payment:
        return ["Payment Received", "Payment Paid", "All Payments(Combined)"];
      case FilterType.dispute:
        return ["Open", "Resolved", "All"];
      case FilterType.nonCompliance:
        return ["Serious", "Moderate", "Minor", "All"];
       case FilterType.custody:
        return ["Scheduled", "Non-Scheduled", "All Records"];
    }
  }
}