import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/timeframe.dart';
import 'custom_dropdown.dart';
import 'custom_primary_button.dart';

/// Report generation progress: [progress] is 0.0–1.0, [message] the current
/// stage ("Adding photos (3 of 12)…").
typedef ReportProgressCallback = void Function(double progress, String message);

class ExportFilterSheet extends StatefulWidget {
  final List<dynamic> children;

  /// Awaited by the sheet, which shows a percentage progress panel for the
  /// whole generation. Must return a Future that completes when the report is
  /// done, and should forward the callback to PDFGenerator.generateReport.
  final Future<void> Function(ExportOptions options, ReportProgressCallback onProgress) onApply;

  /// Pre-selected period — the Insights screen passes its own timeframe.
  /// Defaults to the Australian financial year.
  final String initialTimePeriod;

  const ExportFilterSheet({
    super.key,
    required this.children,
    required this.onApply,
    this.initialTimePeriod = Timeframe.defaultOption,
  });

  @override
  State<ExportFilterSheet> createState() => _ExportFilterSheetState();
}

class _ExportFilterSheetState extends State<ExportFilterSheet> {
  List<String> selectedChildIds = [];
  String? selectedTimePeriod;
  DateTime? startDate;
  DateTime? endDate;
  bool _isGenerating = false;
  double _progress = 0;
  String _progressMessage = "";

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
    selectedTimePeriod = widget.initialTimePeriod;
  }

  bool get _isCustomRange => selectedTimePeriod == ExportOptions.customRange;

  @override
  Widget build(BuildContext context) {
    // No closing the sheet mid-generation — the progress panel is the only
    // sign the work is still running.
    return PopScope(
      canPop: !_isGenerating,
      child: _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
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
                    _buildTimePeriodDropdown(),
                    if (_isCustomRange) ...[
                      const SizedBox(height: 15),
                      _buildManualDateRange(),
                    ],
                    const SizedBox(height: 20),
                    _sectionTitle("Include in Report"),
                    _buildIncludeCheckboxes(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
              _isGenerating ? _buildProgressPanel() : _buildApplyButton(),
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
              onPressed: _isGenerating ? null : () => Navigator.pop(context),
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
  // Preset periods (Australian financial year by default) plus "Custom range",
  // which reveals start/end pickers.
  Widget _buildTimePeriodDropdown() {
    const options = [...Timeframe.options, ExportOptions.customRange];
    final value = options.contains(selectedTimePeriod) ? selectedTimePeriod : Timeframe.defaultOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomDropDown<String>(
          hint: "Select time period",
          value: value,
          items: options.map((option) => DropdownMenuItem<String>(
            value: option,
            child: Text(Timeframe.label(option), style: const TextStyle(fontSize: 14)),
          )).toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              selectedTimePeriod = val;
              if (!_isCustomRange) {
                startDate = null;
                endDate = null;
              }
            });
          },
        ),
        if (!_isCustomRange) ...[
          const SizedBox(height: 6),
          Text(Timeframe.describe(value), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ],
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
                        ? DateFormat('d MMM yyyy').format(selectedDate)
                        : "d MMM yyyy",
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

  Future<void> _generate() async {
    // Guard against a second tap slipping through before the first rebuild.
    if (_isGenerating) return;

    if (selectedChildIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one child")));
      return;
    }

    if (_isCustomRange && startDate == null && endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pick a start and/or end date for the custom range")));
      return;
    }

    final finalOptions = ExportOptions(
      childIds: selectedChildIds,
      timePeriod: selectedTimePeriod,
      startDate: _isCustomRange ? startDate : null,
      endDate: _isCustomRange ? endDate : null,
      reportSections: includeInReport,
    );

    setState(() {
      _isGenerating = true;
      _progress = 0;
      _progressMessage = "Preparing report…";
    });
    try {
      await widget.onApply(finalOptions, (progress, message) {
        if (!mounted) return;
        setState(() {
          // Never let the bar move backwards.
          if (progress > _progress) _progress = progress.clamp(0.0, 1.0);
          _progressMessage = message;
        });
      });
      if (!mounted) return;
      setState(() => _isGenerating = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not generate report: $e")),
      );
    }
  }

  // Replaces the Generate button while the report builds: a percentage and
  // the current stage, so a long photo download never looks like a freeze.
  Widget _buildProgressPanel() {
    final percent = (_progress * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text("Generating report",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Text("$percent%",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 8),
          Text(_progressMessage, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 2),
          Text("Please keep the app open until the report is ready.",
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: CustomPrimaryButton(
        text: "Generate Report",
        backgroundColor: const Color(0xFF7B2CBF),
        onPressed: _generate,
      ),
    );
  }
}

class ExportOptions {
  static const String customRange = "Custom range";

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

  /// The days the report covers: the manual range when one was picked,
  /// otherwise the selected preset period.
  TimeWindow get window {
    if (startDate != null || endDate != null) {
      return TimeWindow(start: startDate, end: endDate);
    }
    return Timeframe.windowFor(timePeriod);
  }

  /// "Current FY (FY 2026–27): 01/07/2026 - 30/06/2027" for the report cover.
  String get periodDescription {
    final dates = Timeframe.describeWindow(window, pattern: 'dd/MM/yyyy');
    if (startDate != null || endDate != null) return dates;
    final name = Timeframe.label(timePeriod ?? Timeframe.allTime);
    return window.isUnbounded ? name : "$name: $dates";
  }
}