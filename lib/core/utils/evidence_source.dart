/// Where an evidence photo came from.
///
/// - [camera]: captured in the app and stamped with the capture time and
///   location at that moment.
/// - [library]: an existing photo picked from the device's photo library or
///   files. Its location/geotag and original timestamp can't be verified the
///   same way.
/// - [unknown]: documents, and anything uploaded before sources were tracked.
///
/// The source travels in the file name (and so in the Storage download URL),
/// which means every record type and the PDF can read it back without any
/// extra Firestore fields.
enum EvidenceSource { camera, library, unknown }

const String _cameraTag = 'cc-camera';
const String _libraryTag = 'cc-library';

/// Tag to embed in a file name for [source] (empty for [EvidenceSource.unknown]).
String evidenceFileTag(EvidenceSource source) {
  switch (source) {
    case EvidenceSource.camera:
      return _cameraTag;
    case EvidenceSource.library:
      return _libraryTag;
    case EvidenceSource.unknown:
      return '';
  }
}

/// Reads the source back from a local path or a Firebase Storage URL (whose
/// object path is percent-encoded before the `?alt=media` query).
EvidenceSource evidenceSourceOf(String pathOrUrl) {
  String name = pathOrUrl.split('?').first;
  try {
    name = Uri.decodeComponent(name);
  } catch (_) {
    // Not encoded — use as-is.
  }
  name = name.split('/').last;
  if (name.contains(_cameraTag)) return EvidenceSource.camera;
  if (name.contains(_libraryTag)) return EvidenceSource.library;
  return EvidenceSource.unknown;
}

/// Storage file name that keeps the source tag of [localPath]. For uploaders
/// that don't otherwise preserve the local file name.
String taggedStorageName(String base, String localPath, String extension) {
  final tag = evidenceFileTag(evidenceSourceOf(localPath));
  return tag.isEmpty ? '$base.$extension' : '${base}_$tag.$extension';
}

/// Shown wherever a library photo appears as evidence.
const String libraryPhotoNotice =
    "Uploaded from photo library — location/geotag and original timestamp "
    "can't be verified as they can for photos taken in the app.";

const String cameraPhotoNotice =
    "Taken in the app — stamped with the capture time and location.";
