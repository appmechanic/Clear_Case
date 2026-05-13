/// Single source of truth for reading attachment URLs out of a Firestore
/// document map.
///
/// Custody and payment records historically used the key `attachmentUrls`,
/// while breach and dispute records used `attachments`. Going forward
/// everything writes `attachmentUrls`, but existing documents on the
/// `attachments` key still need to render correctly — read sites use this
/// helper so they don't have to know which generation a record belongs to.
List<String> readAttachmentUrls(Map<String, dynamic>? data) {
  if (data == null) return const [];
  final primary = data['attachmentUrls'];
  if (primary is List) return List<String>.from(primary);
  final legacy = data['attachments'];
  if (legacy is List) return List<String>.from(legacy);
  return const [];
}
