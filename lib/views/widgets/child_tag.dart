import 'package:flutter/material.dart';

import '../../core/utils/child_names.dart';
import '../../models/case_model.dart';

/// The pill naming which child(ren) a record is about. Same look as the child
/// tag on payment and custody list items, so every category reads alike.
class ChildTag extends StatelessWidget {
  final String label;

  const ChildTag(this.label, {super.key});

  /// Tag for a record's [childIds]; empty reads as "All children".
  factory ChildTag.forIds(List<String>? childIds, CaseModel? caseModel, {Key? key}) =>
      ChildTag(childTagLabel(childIds, caseModel), key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
