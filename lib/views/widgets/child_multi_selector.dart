import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/case_model.dart';

/// Pick which of a case's children a record is about. Same tiles as the
/// custody and payment forms, plus "Select All" for whole-family records.
class ChildMultiSelector extends StatelessWidget {
  final CaseModel? caseModel;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const ChildMultiSelector({
    super.key,
    required this.caseModel,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final children = caseModel?.children ?? const <ChildModel>[];
    if (caseModel == null) return const Text("Select a case first");
    if (children.isEmpty) {
      return const Text("This case has no children yet.", style: TextStyle(color: Colors.grey));
    }

    final allIds = children.map((c) => c.id).toSet();
    final allSelected = allIds.every(selectedIds.contains);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text("Children", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        if (children.length > 1)
          _tile(
            title: "Select All",
            selected: allSelected,
            showAvatar: false,
            onTap: () => onChanged(allSelected ? <String>{} : allIds),
          ),
        ...children.map((child) {
          final selected = selectedIds.contains(child.id);
          return _tile(
            title: child.name,
            selected: selected,
            onTap: () {
              final next = Set<String>.from(selectedIds);
              selected ? next.remove(child.id) : next.add(child.id);
              onChanged(next);
            },
          );
        }),
      ],
    );
  }

  Widget _tile({
    required String title,
    required bool selected,
    required VoidCallback onTap,
    bool showAvatar = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Material(
        // Gives the tile its own ink surface: the container's colour would
        // otherwise hide the tap ripple.
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: showAvatar
              ? CircleAvatar(backgroundColor: Colors.purple[50], child: const Icon(Icons.person, color: Colors.purple))
              : null,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: AppColors.primary,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
