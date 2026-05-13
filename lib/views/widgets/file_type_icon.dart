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
