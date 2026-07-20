import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'attachment_preview.dart';
import 'file_type_icon.dart';

/// Attachment thumbnail used on the record detail screens.
///
/// Tapping the thumbnail opens the in-app preview (image lightbox / PDF / text).
/// The corner "open in browser" badge launches the file's full Firebase
/// download URL in the external browser via url_launcher — the whole URL
/// (including the access token) is passed straight to the browser, so there's
/// no copy-paste truncation, and it works for any file type / for downloading.
class AttachmentThumbnail extends StatefulWidget {
  final String url;
  const AttachmentThumbnail({super.key, required this.url});

  @override
  State<AttachmentThumbnail> createState() => _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends State<AttachmentThumbnail> {
  String? _ext;

  String get url => widget.url;

  @override
  void initState() {
    super.initState();
    _ext = extensionFromUrl(url);
    // Legacy dispute-log uploads were stored without an extension, so the URL
    // alone can't identify them. Fall back to the object's contentType.
    if (_ext == null) _resolveFromMetadata();
  }

  Future<void> _resolveFromMetadata() async {
    final resolved = await extensionFromStorageMetadata(url);
    if (!mounted || resolved == null) return;
    setState(() => _ext = resolved);
  }

  Future<void> _openInBrowser(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    bool launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }
    if (!launched) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open the attachment in a browser")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = isImageExtension(_ext);
    final typeInfo = fileTypeFromExtension(_ext);
    // Decode the remote image down to the thumbnail's physical pixel size
    // instead of holding the full-resolution bitmap in memory per tile.
    final int cacheSize = (80 * MediaQuery.of(context).devicePixelRatio).round();

    // Only caption the tile when there's a real filename to show — the tile
    // already renders the type, so falling back to it here just prints
    // "FILE" twice.
    final label = displayNameFromUrl(url);

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTile(context, isImage, typeInfo, cacheSize),
          if (label != null) ...[
            const SizedBox(height: 4),
            Tooltip(
              message: label,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    bool isImage,
    FileTypeInfo typeInfo,
    int cacheSize,
  ) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          // Tap the thumbnail -> in-app preview (existing behaviour).
          GestureDetector(
            onTap: () => AttachmentPreview.openUrl(context, url),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isImage
                    ? Image.network(
                        url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        cacheWidth: cacheSize,
                        cacheHeight: cacheSize,
                        errorBuilder: (context, error, stackTrace) => FileTypeTile(info: typeInfo),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        },
                      )
                    : FileTypeTile(info: typeInfo),
              ),
            ),
          ),
          // Corner badge -> open / download in the external browser.
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _openInBrowser(context),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.open_in_new, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
