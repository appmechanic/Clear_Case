import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Deletes any Firebase Storage files that were attached to a record before
/// an edit but are no longer in the kept list. Best-effort — individual
/// failures (e.g. file already gone, bad URL) are swallowed so they never
/// block the user-visible save flow. Call after the Firestore write so the
/// record state is the source of truth even if storage cleanup fails.
Future<void> deleteOrphanedStorageUrls({
  required List<String> oldUrls,
  required List<String> keptUrls,
}) async {
  final keptSet = keptUrls.toSet();
  for (final url in oldUrls) {
    if (keptSet.contains(url)) continue;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Storage cleanup skipped for $url: $e');
    }
  }
}
