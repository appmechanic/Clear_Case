import '../../models/case_model.dart';

/// Shown on a record that isn't tied to particular children. Disputes and
/// non-compliance records created before child selection existed have no
/// `childIds` and apply to the whole case.
const String allChildrenLabel = "All children";

/// Reads a record's `childIds` field; missing or malformed reads as empty.
List<String> readChildIds(Map<String, dynamic>? data) {
  final raw = data?['childIds'];
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList();
}

/// Names of [childIds] within [caseModel], in the case's child order. Ids that
/// no longer match a child (deleted since) are skipped.
List<String> childNamesFor(Iterable<String>? childIds, CaseModel? caseModel) {
  if (childIds == null || caseModel == null) return const [];
  final ids = childIds.toSet();
  return caseModel.children
      .where((c) => ids.contains(c.id))
      .map((c) => c.name.trim())
      .toList();
}

/// Text for a record's child tag. Empty [childIds] means the record covers
/// every child (see [allChildrenLabel]).
String childTagLabel(List<String>? childIds, CaseModel? caseModel) {
  if (childIds == null || childIds.isEmpty) return allChildrenLabel;
  final names = childNamesFor(childIds, caseModel);
  return names.isEmpty ? "Unknown child" : names.join(", ");
}

/// Whether a record tagged with [recordChildIds] belongs under a child filter
/// of [selectedChildIds]. An empty filter shows everything; an untagged
/// (whole-case) record shows under every child.
bool matchesChildFilter(List<String>? recordChildIds, List<String> selectedChildIds) {
  if (selectedChildIds.isEmpty) return true;
  if (recordChildIds == null || recordChildIds.isEmpty) return true;
  return recordChildIds.any(selectedChildIds.contains);
}

/// How a case is named in pickers and headers: its children, e.g.
/// "Jim/Billy/Anna", falling back to the case number when it has none.
String caseDisplayName(CaseModel caseModel, {String emptyFallback = ''}) {
  if (caseModel.children.isEmpty) {
    return caseModel.caseNumber.isEmpty ? emptyFallback : caseModel.caseNumber;
  }
  return caseModel.children.map((c) => c.name.trim()).join('/');
}
