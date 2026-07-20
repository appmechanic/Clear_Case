import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'attachment_preview.dart';
import 'file_type_icon.dart';

class AttachmentPickerWidget extends StatefulWidget {
  final Function(List<File>) onFilesChanged;
  const AttachmentPickerWidget({super.key, required this.onFilesChanged});

  @override
  State<AttachmentPickerWidget> createState() => _AttachmentPickerWidgetState();
}

class _AttachmentPickerWidgetState extends State<AttachmentPickerWidget> {
  final List<File> _selectedFiles = [];

  Widget _buildDottedOption(IconData icon, String text, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: DottedBorder(
      options: RectDottedBorderOptions(
        dashPattern: [10, 5],
        strokeWidth: 2,
        padding: EdgeInsets.all(16),
        color: Colors.purple,
      ),
      child: Row(children: [
        Icon(icon, color: Colors.purple),
        const SizedBox(width: 10),
        Expanded(child: Text(text))
      ]),
    ),
  );

  void _showSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Add Attachment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const Align(alignment: Alignment.centerLeft, child: Text("Select how you want to add your attachments")),
            const SizedBox(height: 20),
            _buildDottedOption(Icons.camera_alt, "Capture image using camera.", () {
              Navigator.pop(context);
              _pickFromSource(ImageSource.camera);
            }),
            const SizedBox(height: 15),
            _buildDottedOption(Icons.upload_file, "Upload Images or docs related to the Non Compliance", () {
              Navigator.pop(context);
              _pickFromGallery();
            }),
            const SizedBox(height: 20),
            const Text("Supports images, PDF, Word, Excel, PowerPoint and .txt", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    // Down-sample at capture so a modern phone's multi-megabyte JPEG fits
    // under the 2 MB upload ceiling without losing evidence-quality detail.
    final XFile? photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (photo != null) {
      _processAndAddFiles(
        [File(photo.path)],
        fromCamera: source == ImageSource.camera,
      );
    }
  }

  Future<void> _pickFromGallery() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg', 'png', 'jpeg',
        'pdf', 'txt',
        'doc', 'docx',
        'xls', 'xlsx', 'csv',
        'ppt', 'pptx',
      ],
    );
    if (result != null) _processAndAddFiles(result.files.map((f) => File(f.path!)).toList());
  }

  Future<void> _processAndAddFiles(List<File> files, {bool fromCamera = false}) async {
    List<File> processed = [];
    for (var file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png'].contains(ext);

      // Documents can't be compressed by this path — enforce size up front.
      if (!isImage) {
        if (await file.length() > _maxBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("File exceeds 10MB")));
          }
          continue;
        }
        processed.add(file);
        continue;
      }

      File outFile = file;
      // Only stamp photos captured in-app — gallery uploads are external
      // and already carry their own EXIF metadata.
      if (fromCamera) {
        final stamped = await _stampImageWithLoader(outFile);
        if (stamped != null) outFile = stamped;
      }

      // Compress after stamping: the stamp re-encodes via dart:ui, which can
      // only emit PNG, so the compressor is what produces the final JPEG.
      final compressed = await _compressImage(outFile);
      if (compressed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Couldn't process this image — try another photo")));
        }
        continue;
      }
      processed.add(compressed);
    }
    setState(() => _selectedFiles.addAll(processed));
    widget.onFilesChanged(_selectedFiles);
  }

  // Attachment ceiling. Documents are rejected above this; images are
  // compressed to fit and only rejected if compression somehow can't get
  // under it. Bounded by AttachmentPreview's 20 MB getData cap, which
  // throws for files larger than its limit.
  static const int _maxBytes = 10 * 1024 * 1024;

  // Re-encodes to JPEG, stepping quality down until the result fits under
  // _maxBytes. Replaces the old crop step, which was doing the compression
  // implicitly via compressQuality. Returns null if every attempt failed.
  Future<File?> _compressImage(File source) async {
    const qualities = [85, 75, 60, 50];
    for (final quality in qualities) {
      final target = '${source.path}_c$quality.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        target,
        quality: quality,
        minWidth: 1600,
        minHeight: 1600,
        format: CompressFormat.jpeg,
      );
      if (result == null) continue;
      final out = File(result.path);
      if (await out.length() <= _maxBytes) return out;
    }
    return null;
  }

  // ---- Stamping (timestamp + location overlay) ----

  Future<File?> _stampImageWithLoader(File source) async {
    if (!mounted) return null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.purple),
            ),
            SizedBox(width: 16),
            Flexible(child: Text("Adding timestamp & location…")),
          ],
        ),
      ),
    );
    File? result;
    try {
      result = await _stampImage(source);
    } catch (_) {
      result = null;
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    return result;
  }

  // Decodes the image, draws it onto a Canvas, then renders a subtle dark
  // pill in the bottom-right with timestamp + reverse-geocoded location.
  // dart:ui can only encode PNG, so this writes a PNG intermediate that
  // _compressImage then re-encodes to JPEG. Never upload this file directly —
  // a 1600px PNG photo routinely exceeds the size ceiling.
  Future<File?> _stampImage(File source) async {
    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final w = image.width.toDouble();
    final h = image.height.toDouble();

    final timeText = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
    final locationText = await _fetchLocationText();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    final lines = <String>[timeText];
    if (locationText != null && locationText.isNotEmpty) lines.add(locationText);

    final fontSize = math.max(12.0, w * 0.024);
    final padX = w * 0.025;
    final padY = w * 0.018;

    final spans = <TextSpan>[
      for (int i = 0; i < lines.length; i++)
        TextSpan(
          text: lines[i] + (i == lines.length - 1 ? '' : '\n'),
          style: TextStyle(
            color: Colors.white,
            fontSize: i == 0 ? fontSize : fontSize * 0.9,
            fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w500,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
            ],
            height: 1.2,
          ),
        ),
    ];

    // dart:ui's TextDirection enum — `intl` also exports a `TextDirection`
    // class that would otherwise shadow it in this file.
    final textPainter = TextPainter(
      text: TextSpan(children: spans),
      textAlign: TextAlign.right,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: w - padX * 4);

    final pillWidth = textPainter.width + padX * 1.4;
    final pillHeight = textPainter.height + padY * 1.2;
    final pillLeft = w - pillWidth - padX;
    final pillTop = h - pillHeight - padX;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
        Radius.circular(padX * 0.6),
      ),
      Paint()..color = Colors.black.withOpacity(0.45),
    );
    textPainter.paint(
      canvas,
      Offset(pillLeft + padX * 0.7, pillTop + padY * 0.6),
    );

    final picture = recorder.endRecording();
    final stamped = await picture.toImage(image.width, image.height);
    final byteData = await stamped.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final outFile = File('${source.path}_stamped.png');
    await outFile.writeAsBytes(byteData.buffer.asUint8List());
    return outFile;
  }

  // Best-effort location lookup. Returns null on any failure (denied
  // permission, disabled service, timeout) so the stamp falls back to
  // timestamp only without blocking the capture flow.
  Future<String?> _fetchLocationText() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 6));
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = <String>[];
      if (p.subLocality != null && p.subLocality!.isNotEmpty) parts.add(p.subLocality!);
      if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
      if (parts.isEmpty &&
          p.administrativeArea != null &&
          p.administrativeArea!.isNotEmpty) {
        parts.add(p.administrativeArea!);
      }
      if (p.country != null && p.country!.isNotEmpty) parts.add(p.country!);
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Wrap, not a shrinkWrap GridView: this widget is hosted inside
      // AlertDialogs (dispute_log_dialog) whose IntrinsicWidth measures its
      // subtree, and a viewport can't report intrinsic dimensions — it throws
      // "RenderShrinkWrappingViewport does not support returning intrinsic
      // dimensions". Fixed-size tiles in a Wrap have no such problem, and
      // match the existing-attachment tiles rendered beside them.
      if (_selectedFiles.isNotEmpty)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_selectedFiles.length, (index) {
            final file = _selectedFiles[index];
            return _buildSelectedFilePreview(file, () {
              setState(() {
                _selectedFiles.removeAt(index);
                widget.onFilesChanged(_selectedFiles);
              });
            });
          }),
        ),
      const SizedBox(height: 10),
      InkWell(onTap: _showSourceDialog, child: DottedBorder(
          options: RectDottedBorderOptions(dashPattern: [10, 5], strokeWidth: 2, padding: EdgeInsets.all(16), color: Colors.purple),
          child: Container(height: 100, width: double.infinity, alignment: Alignment.center, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.upload_file, color: Colors.purple), Text("Upload or Capture images using camera.")])))),
    ]);
  }

  Widget _buildSelectedFilePreview(File file, VoidCallback onDelete) {
    final ext = file.path.split('.').last.toLowerCase();
    final isImage = isImageExtension(ext);
    final typeInfo = fileTypeFromExtension(ext);

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: GestureDetector(
            onTap: () => AttachmentPreview.openFile(context, file),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(file, fit: BoxFit.cover),
                    )
                  : FileTypeTile(info: typeInfo),
            ),
          ),
        ),
        GestureDetector(
          onTap: onDelete,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
