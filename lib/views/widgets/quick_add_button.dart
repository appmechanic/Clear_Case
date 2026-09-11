import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../provider/calender_provider.dart';
import '../../provider/insight_provider.dart';

/// "Quick Add" button for the Insights screens, so an entry can be added
/// without going back to the Calendar.
///
/// Opens the entry form at [routeName] for today. The forms read the case
/// from CalendarProvider, so it's lined up with the case selected in
/// Insights first. [onReturn] runs when the form closes, letting screens
/// that fetch once (rather than stream) reload their list.
class QuickAddButton extends StatelessWidget {
  /// Text beside the + icon. Null gives a round icon-only button, matching
  /// the Calendar's add button.
  final String? label;
  final String routeName;
  final VoidCallback? onReturn;

  const QuickAddButton({
    super.key,
    this.label,
    required this.routeName,
    this.onReturn,
  });

  Future<void> _open(BuildContext context) async {
    final selected = context.read<InsightProvider>().selectedCase;
    final calendar = context.read<CalendarProvider>();
    if (selected != null && calendar.selectedCase?.id != selected.id) {
      final match = calendar.allCases.where((c) => c.id == selected.id);
      if (match.isNotEmpty) calendar.setSelectedCase(match.first);
    }
    await Navigator.pushNamed(context, routeName);
    onReturn?.call();
  }

  @override
  Widget build(BuildContext context) {
    // One per screen; distinct tags keep Hero from clashing during route
    // transitions.
    final heroTag = 'quick-add-$routeName';
    if (label == null) {
      return FloatingActionButton(
        heroTag: heroTag,
        tooltip: "Quick Add",
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _open(context),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      );
    }
    return FloatingActionButton.extended(
      heroTag: heroTag,
      backgroundColor: AppColors.primary,
      onPressed: () => _open(context),
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(label!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
