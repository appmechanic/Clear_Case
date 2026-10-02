import 'package:flutter/material.dart';

import '../../models/remainder_model.dart';
import 'custom_text_field.dart';

/// A reminder's tag (any text) and colour. Suggested tags fill the field and
/// switch to their usual colour; any colour can then be picked.
class ReminderTagPicker extends StatelessWidget {
  final TextEditingController tagController;
  final FocusNode tagNode;
  final int color;
  final ValueChanged<int> onColorChanged;

  /// Called when the tag text changes, so the parent can rebuild its preview.
  final VoidCallback onTagChanged;

  const ReminderTagPicker({
    super.key,
    required this.tagController,
    required this.tagNode,
    required this.color,
    required this.onColorChanged,
    required this.onTagChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tag = tagController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          labelText: "Tag",
          hintText: "e.g. Custody, Payment, Swimming",
          controller: tagController,
          node: tagNode,
          maxLength: 30,
          borderRadius: 8,
          backgroundColor: Colors.grey.shade200,
          onChange: (_) => onTagChanged(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: reminderTagSuggestions.entries.map((s) {
            final selected = tag.toLowerCase() == s.key.toLowerCase();
            return ChoiceChip(
              label: Text(s.key),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Color(s.value),
              ),
              selectedColor: Color(s.value),
              backgroundColor: Color(s.value).withValues(alpha: 0.1),
              side: BorderSide.none,
              shape: const StadiumBorder(),
              onSelected: (_) {
                tagController.text = s.key;
                onColorChanged(s.value);
                onTagChanged();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        const Text("Colour", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: reminderColors.map((c) {
            final selected = c == color;
            return GestureDetector(
              onTap: () => onColorChanged(c),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.black87 : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
            );
          }).toList(),
        ),
        if (tag.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Text("Preview  ", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ReminderTagChip(tag: tag, color: color),
            ],
          ),
        ],
      ],
    );
  }
}

/// A reminder's tag in its colour.
class ReminderTagChip extends StatelessWidget {
  final String tag;
  final int color;

  const ReminderTagChip({super.key, required this.tag, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = Color(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
