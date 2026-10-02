import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/case_model.dart';
import 'custom_dropdown.dart';
import 'custom_text_field.dart';

/// What the user has picked as a record's related party. The picker writes to
/// it as the user edits; the form reads it on save.
class RelatedPartyController {
  /// Stored on the record as `party`, e.g. "Mother".
  String relation = '';

  /// Stored on the record as `name`.
  String name = '';

  /// The case has no saved related party yet and the user asked to keep this
  /// one for next time. The form writes it to the case after saving.
  bool saveToCase = false;
}

/// Related-party section of the dispute and non-compliance forms.
///
/// When the case has a saved related party it's offered pre-selected, with
/// "Another party" opening a relationship dropdown and a name field. Without
/// one, those fields show directly with an option to save them to the case.
class RelatedPartyPicker extends StatefulWidget {
  final CaseModel? caseModel;
  final RelatedPartyController controller;

  /// The record's party when editing (`party`, `name`); null for a new record.
  final String? initialRelation;
  final String? initialName;

  const RelatedPartyPicker({
    super.key,
    required this.caseModel,
    required this.controller,
    this.initialRelation,
    this.initialName,
  });

  @override
  State<RelatedPartyPicker> createState() => _RelatedPartyPickerState();
}

class _RelatedPartyPickerState extends State<RelatedPartyPicker> {
  final _nameController = TextEditingController();
  final _nameNode = FocusNode();

  bool _useSaved = false;
  String? _otherRelation;
  bool _saveToCase = true;

  CaseModel? get _case => widget.caseModel;
  bool get _hasSaved => _case?.hasRelatedParty ?? false;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(covariant RelatedPartyPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different case was picked, the edited record finished loading, or the
    // case's saved party arrived — start over from it.
    if (oldWidget.caseModel?.id != widget.caseModel?.id ||
        oldWidget.initialRelation != widget.initialRelation ||
        oldWidget.initialName != widget.initialName ||
        oldWidget.caseModel?.hasRelatedParty != widget.caseModel?.hasRelatedParty) {
      _seed();
    }
  }

  void _seed() {
    final relation = widget.initialRelation?.trim() ?? '';
    final name = widget.initialName?.trim() ?? '';
    final isNewRecord = relation.isEmpty && name.isEmpty;
    final matchesSaved = _hasSaved &&
        relation == _case!.relatedPartyRelation!.trim() &&
        name == _case!.relatedPartyName!.trim();

    _useSaved = _hasSaved && (isNewRecord || matchesSaved);
    _otherRelation = (_useSaved || relation.isEmpty) ? null : relation;
    _nameController.text = _useSaved ? '' : name;
    _saveToCase = isNewRecord;
    _sync();
  }

  // Pushes the visible choice into the controller the form reads on save.
  void _sync() {
    final c = widget.controller;
    if (_useSaved) {
      c.relation = _case!.relatedPartyRelation!.trim();
      c.name = _case!.relatedPartyName!.trim();
      c.saveToCase = false;
    } else {
      c.relation = _otherRelation ?? '';
      c.name = _nameController.text.trim();
      c.saveToCase = !_hasSaved && _saveToCase;
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    _sync();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text("Related Party", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        if (_hasSaved) ...[
          _option(
            selected: _useSaved,
            title: _case!.relatedPartyName!.trim(),
            subtitle: _case!.relatedPartyRelation!.trim(),
            onTap: () => _update(() => _useSaved = true),
          ),
          _option(
            selected: !_useSaved,
            title: "Another party",
            subtitle: "Someone other than the saved related party",
            onTap: () => _update(() => _useSaved = false),
          ),
        ],
        if (!_useSaved) ...[
          if (_hasSaved) const SizedBox(height: 6),
          CustomDropDown<String>(
            value: _otherRelation,
            hint: "Select relationship",
            items: _relationOptions
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => _update(() => _otherRelation = v),
          ),
          const SizedBox(height: 15),
          CustomTextField(
            labelText: "Name of the Related Party",
            hintText: "Enter the name",
            controller: _nameController,
            node: _nameNode,
            borderRadius: 8,
            backgroundColor: Colors.grey.shade200,
            onChange: (_) => _sync(),
          ),
          if (!_hasSaved && _case != null)
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              dense: true,
              value: _saveToCase,
              onChanged: (v) => _update(() => _saveToCase = v ?? false),
              title: const Text("Save as this case's related party",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: const Text("Fill this in automatically next time",
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ),
        ],
      ],
    );
  }

  // Keeps a legacy relationship (e.g. "Grandparent") selectable when editing
  // an old record, so the dropdown always contains its current value.
  List<String> get _relationOptions {
    final current = _otherRelation;
    if (current == null || relatedPartyRelations.contains(current)) {
      return relatedPartyRelations;
    }
    return [...relatedPartyRelations, current];
  }

  Widget _option({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
