import 'package:flutter/foundation.dart';

/// App-wide single source of truth for which case (child) is currently
/// selected. Every screen's case dropdown reads from and writes to this, so
/// selecting a child on one screen (e.g. the Calendar) is reflected on every
/// other screen (e.g. Insights, Scheduled Dates) automatically.
///
/// Providers push their selection here via [select] and listen for changes
/// from other providers. The [select] no-op guard on an unchanged id prevents
/// feedback loops between the providers that both read and write this value.
class CaseSelectionService extends ChangeNotifier {
  CaseSelectionService._();
  static final CaseSelectionService instance = CaseSelectionService._();

  String? _selectedCaseId;
  String? get selectedCaseId => _selectedCaseId;

  /// Sets the globally selected case id. Does nothing (and notifies nobody)
  /// when the id is unchanged — this is what keeps cross-provider syncing from
  /// looping.
  void select(String? caseId) {
    if (_selectedCaseId == caseId) return;
    _selectedCaseId = caseId;
    notifyListeners();
  }

  /// Clears the selection, e.g. on logout / account switch.
  void clear() {
    if (_selectedCaseId == null) return;
    _selectedCaseId = null;
    notifyListeners();
  }
}
