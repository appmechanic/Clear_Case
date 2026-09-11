import 'package:flutter/material.dart';

import '../../core/utils/evidence_source.dart';

/// Small corner badge on a photo tile: orange for photos picked from the
/// device library (location/time not verified), green for photos taken in the
/// app. Renders nothing for documents and untracked uploads. Tap it for the
/// full explanation.
class EvidenceSourceBadge extends StatelessWidget {
  final EvidenceSource source;
  final double size;
  const EvidenceSourceBadge({super.key, required this.source, this.size = 12});

  factory EvidenceSourceBadge.forPath(String pathOrUrl, {double size = 12}) =>
      EvidenceSourceBadge(source: evidenceSourceOf(pathOrUrl), size: size);

  @override
  Widget build(BuildContext context) {
    if (source == EvidenceSource.unknown) return const SizedBox.shrink();
    final isLibrary = source == EvidenceSource.library;
    final message = isLibrary ? libraryPhotoNotice : cameraPhotoNotice;
    return Tooltip(
      message: message,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isLibrary ? Colors.orange.shade700 : Colors.green.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Icon(
            isLibrary ? Icons.photo_library_outlined : Icons.verified_outlined,
            size: size,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Inline explanation shown under the picker and in the full-screen viewer
/// when a photo came from the device library.
class LibraryPhotoNotice extends StatelessWidget {
  final bool onDark;
  const LibraryPhotoNotice({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: onDark ? Colors.black.withValues(alpha: 0.6) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: onDark ? Colors.orange.shade200 : Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              libraryPhotoNotice,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: onDark ? Colors.white : Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
