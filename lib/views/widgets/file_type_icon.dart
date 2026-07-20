import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Visual metadata for an attachment file extension. Shared across the
/// attachment picker, edit-screen "existing files" lists, and the insight
/// detail thumbnail so every surface shows the same icon + colour per type.
class FileTypeInfo {
  final IconData icon;
  final Color color;
  final String label;

  const FileTypeInfo({
    required this.icon,
    required this.color,
    required this.label,
  });
}

FileTypeInfo fileTypeFromExtension(String? rawExt) {
  switch ((rawExt ?? '').toLowerCase()) {
    case 'pdf':
      return const FileTypeInfo(
        icon: Icons.picture_as_pdf,
        color: Color(0xFFD32F2F),
        label: 'PDF',
      );
    case 'doc':
    case 'docx':
      return const FileTypeInfo(
        icon: Icons.description,
        color: Color(0xFF1976D2),
        label: 'DOC',
      );
    case 'xls':
    case 'xlsx':
    case 'csv':
      return const FileTypeInfo(
        icon: Icons.table_chart,
        color: Color(0xFF388E3C),
        label: 'XLS',
      );
    case 'ppt':
    case 'pptx':
      return const FileTypeInfo(
        icon: Icons.slideshow,
        color: Color(0xFFE64A19),
        label: 'PPT',
      );
    case 'txt':
      return const FileTypeInfo(
        icon: Icons.text_snippet,
        color: Color(0xFF616161),
        label: 'TXT',
      );
    default:
      return const FileTypeInfo(
        icon: Icons.insert_drive_file,
        color: Color(0xFF616161),
        label: 'FILE',
      );
  }
}

/// True for raster types we render as a thumbnail rather than an icon.
bool isImageExtension(String? ext) {
  final e = (ext ?? '').toLowerCase();
  return e == 'jpg' || e == 'jpeg' || e == 'png';
}

/// Pulls a usable extension out of a Firebase Storage URL — the encoded
/// path keeps the original file extension (e.g. ".../foo.docx?alt=media...").
String? extensionFromUrl(String url) {
  final lower = url.toLowerCase();
  // Order matters — match longer extensions first so ".docx" doesn't get
  // shortened to ".doc".
  const known = [
    'pdf', 'docx', 'doc', 'xlsx', 'xls', 'csv',
    'pptx', 'ppt', 'txt', 'jpeg', 'jpg', 'png',
  ];
  for (final ext in known) {
    if (lower.contains('.$ext')) return ext;
  }
  return null;
}

/// Human-readable original filename recovered from a Storage URL.
///
/// Uploads are named `<millis>_<original name>`, so the timestamp prefix is
/// stripped back off for display. Returns null when nothing useful survives —
/// legacy dispute-log uploads were named `<millis>_<index>` with no original
/// name and no extension, and older dispute records `<millis>_<index>.<ext>`,
/// so there is genuinely no name to show and callers should fall back to the
/// file-type label.
String? displayNameFromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    if (uri.pathSegments.isEmpty) return null;
    final decoded = Uri.decodeComponent(uri.pathSegments.last);
    final raw = decoded.split('/').last;
    if (raw.isEmpty) return null;

    // Strip the `<millis>_` upload prefix.
    final stripped = raw.replaceFirst(RegExp(r'^\d{10,}_'), '');
    if (stripped.isEmpty) return null;

    // `<millis>_0` / `<millis>_0.pdf` carry no original name — the leftover is
    // just the loop index, which is noise rather than information.
    final stem = stripped.contains('.')
        ? stripped.substring(0, stripped.lastIndexOf('.'))
        : stripped;
    if (stem.isEmpty || RegExp(r'^\d+$').hasMatch(stem)) return null;

    return stripped;
  } catch (_) {
    return null;
  }
}

/// Maps a MIME content type to the extension our type table understands.
String? _extFromContentType(String? contentType) {
  final type = (contentType ?? '').toLowerCase().split(';').first.trim();
  switch (type) {
    case 'application/pdf':
      return 'pdf';
    case 'image/jpeg':
    case 'image/jpg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'text/plain':
      return 'txt';
    case 'text/csv':
      return 'csv';
    case 'application/msword':
      return 'doc';
    case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      return 'docx';
    case 'application/vnd.ms-excel':
      return 'xls';
    case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      return 'xlsx';
    case 'application/vnd.ms-powerpoint':
      return 'ppt';
    case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      return 'pptx';
    default:
      return null;
  }
}

/// Resolved-once cache so a thumbnail rebuild doesn't refetch metadata.
/// Present-with-null means "we asked and Storage had nothing useful".
final Map<String, String?> _metadataExtCache = {};

/// Last-resort file type for attachments whose URL carries no extension.
///
/// Dispute-log uploads were historically named `<millis>_<index>`, discarding
/// the extension, so those URLs can't be classified by parsing alone. `putFile`
/// does record a contentType on the Storage object, so for those legacy files
/// the type is recoverable — at the cost of one network round trip per tile.
/// Returns null (and caches that) when the object has no usable contentType.
Future<String?> extensionFromStorageMetadata(String url) async {
  if (_metadataExtCache.containsKey(url)) return _metadataExtCache[url];
  String? ext;
  try {
    final meta = await FirebaseStorage.instance.refFromURL(url).getMetadata();
    ext = _extFromContentType(meta.contentType);
  } catch (_) {
    ext = null;
  }
  _metadataExtCache[url] = ext;
  return ext;
}

/// Square icon tile for non-image attachments. Used inside fixed-size
/// thumbnails (70×70 in edit screens, 80-wide in the insight detail).
class FileTypeTile extends StatelessWidget {
  final FileTypeInfo info;
  final double iconSize;

  const FileTypeTile({super.key, required this.info, this.iconSize = 30});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(info.icon, color: info.color, size: iconSize),
        const SizedBox(height: 2),
        Text(
          info.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: info.color,
          ),
        ),
      ],
    );
  }
}
