import '../core/utils/timeframe.dart';

enum FilterType { payment, dispute, nonCompliance, custody}

class FilterOptions {
  List<String> selectedChildIds = [];
  // One of Timeframe.options; the Australian financial year by default.
  String selectedTimePeriod = Timeframe.defaultOption;
  String? selectedCategory; // This will hold Payment Type, Dispute Status, or Severity

  FilterOptions({
    this.selectedTimePeriod = Timeframe.defaultOption,
    this.selectedCategory,
    List<String>? selectedChildIds,
  }) : selectedChildIds = selectedChildIds ?? [];
}
