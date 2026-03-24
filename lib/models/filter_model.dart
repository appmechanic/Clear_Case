enum FilterType { payment, dispute, nonCompliance, custody}

class FilterOptions {
  List<String> selectedChildIds = [];
  String selectedTimePeriod = "All Time";
  String? selectedCategory; // This will hold Payment Type, Dispute Status, or Severity

  FilterOptions({
    this.selectedTimePeriod = "All Time",
    this.selectedCategory,
    List<String>? selectedChildIds,
  }) : selectedChildIds = selectedChildIds ?? [];
}