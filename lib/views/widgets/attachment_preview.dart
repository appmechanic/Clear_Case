import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'file_type_icon.dart';

/// Centralized tap-to-preview for attachments. Handles both local files
/// (just-picked) and remote Firebase Storage URLs (existing records being
/// edited). Dispatches by extension to the right viewer.
///
/// Images open in a pinch-zoom lightbox. PDFs open in a paginated viewer
/// (printing's PdfPreview). .txt files open as scrollable selectable text.
class AttachmentPreview {
  AttachmentPreview._();

  static void openFile(BuildContext context, File file) {
    final ext = file.path.split('.').last.toLowerCase();
    if (_isImage(ext)) {
      _showImageDialog(context, FileImage(file));
    } else if (ext == 'pdf') {
      _pushRoute(
        context,
        _PdfScaffold(
          title: file.path.split(Platform.pathSeparator).last,
          loadBytes: file.readAsBytes,
        ),
      );
    } else if (ext == 'txt') {
      _pushRoute(
        context,
        _TextScaffold(
          title: file.path.split(Platform.pathSeparator).last,
          loadText: file.readAsString,
        ),
      );
    } else {
      _unsupported(context);
    }
  }

  static Future<void> openUrl(BuildContext context, String url) async {
    var ext = _extFromUrl(url);
    // Legacy uploads carry no extension in the URL; the Storage object's
    // contentType still identifies them, so ask before giving up on an
    // in-app viewer and punting to the browser.
    if (ext.isEmpty) {
      ext = await extensionFromStorageMetadata(url) ?? '';
      if (!context.mounted) return;
    }
    final name = _fileNameFromUrl(url);
    if (_isImage(ext)) {
      _showImageDialog(context, NetworkImage(url));
    } else if (ext == 'pdf') {
      _pushRoute(
        context,
        _PdfScaffold(
          title: name,
          loadBytes: () => _fetchRemoteBytes(url),
        ),
      );
    } else if (ext == 'txt') {
      _pushRoute(
        context,
        _TextScaffold(
          title: name,
          loadText: () async {
            final bytes = await _fetchRemoteBytes(url);
            return String.fromCharCodes(bytes);
          },
        ),
      );
    } else {
      // Office docs / csv have no in-app viewer, but the picker allows them.
      // Hand the download URL to the OS so the user's own app opens it
      // instead of dead-ending on a snackbar.
      _openExternally(context, url);
    }
  }

  // ---- helpers ----

  static Future<void> _openExternally(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text("No app available to open this file")),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Could not open this file")),
      );
    }
  }

  static bool _isImage(String ext) =>
      ext == 'jpg' || ext == 'jpeg' || ext == 'png';

  // Firebase Storage download URLs encode the path; the extension still
  // appears in the URL (e.g. ".../file.pdf?alt=media&token=..."), so a
  // simple substring scan over a known list is reliable enough.
  static String _extFromUrl(String url) {
    final lower = url.toLowerCase();
    for (final candidate in const ['.pdf', '.txt', '.jpeg', '.jpg', '.png']) {
      if (lower.contains(candidate)) return candidate.substring(1);
    }
    return '';
  }

  static String _fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final decoded = Uri.decodeComponent(last);
      final name = decoded.split('/').last;
      return name.isEmpty ? 'Attachment' : name;
    } catch (_) {
      return 'Attachment';
    }
  }

  static Future<Uint8List> _fetchRemoteBytes(String url) async {
    // 20 MB ceiling — above the 10 MB attachment limit so we never truncate a
    // legitimate file. getData THROWS above its cap, so this must stay strictly
    // larger than _maxBytes in attachment_picker_widget.dart.
    final bytes = await FirebaseStorage.instance
        .refFromURL(url)
        .getData(20 * 1024 * 1024);
    if (bytes == null) {
      throw 'Could not download attachment';
    }
    return bytes;
  }

  static void _showImageDialog(BuildContext context, ImageProvider provider) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _ImageDialog(provider: provider),
    );
  }

  static void _pushRoute(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  static void _unsupported(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Preview not supported for this file")),
    );
  }
}

class _ImageDialog extends StatelessWidget {
  final ImageProvider provider;
  const _ImageDialog({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                      "Couldn't load image",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfScaffold extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function() loadBytes;
  const _PdfScaffold({required this.title, required this.loadBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) async => loadBytes(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: title,
      ),
    );
  }
}

class _TextScaffold extends StatelessWidget {
  final String title;
  final Future<String> Function() loadText;
  const _TextScaffold({required this.title, required this.loadText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<String>(
        future: loadText(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text("Couldn't load: ${snap.error}"),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snap.data ?? '',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          );
        },
      ),
    );
  }
}
