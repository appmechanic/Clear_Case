import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

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
            const Text("Supported file Jpeg, Png, Pdf or .txt\nfile size < 2 Mb", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    final XFile? photo = await ImagePicker().pickImage(source: source);
    if (photo != null) _processAndAddFiles([File(photo.path)]);
  }

  Future<void> _pickFromGallery() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'txt'],
    );
    if (result != null) _processAndAddFiles(result.files.map((f) => File(f.path!)).toList());
  }

  Future<void> _processAndAddFiles(List<File> files) async {
    List<File> processed = [];
    for (var file in files) {
      if (await file.length() > 2 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${file.path.split('/').last} exceeds 2MB")));
        continue;
      }
      final ext = file.path.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png'].contains(ext)) {
        // Applying your custom circular cropping UI
        final cropped = await ImageCropper().cropImage(
          sourcePath: file.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              cropStyle: CropStyle.circle,
              toolbarTitle: 'Adjust Image',
              toolbarColor: Colors.black,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              hideBottomControls: true,
              showCropGrid: false,
              cropFrameColor: Colors.transparent,
              cropFrameStrokeWidth: 0,
              dimmedLayerColor: Colors.black.withOpacity(0.8),
            ),
            IOSUiSettings(
              cropStyle: CropStyle.circle,
              title: 'Adjust Image',
              aspectRatioLockEnabled: true,
            ),
          ],
        );
        if (cropped != null) processed.add(File(cropped.path));
      } else {
        processed.add(file);
      }
    }
    setState(() => _selectedFiles.addAll(processed));
    widget.onFilesChanged(_selectedFiles);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (_selectedFiles.isNotEmpty)
        GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              final isImage = ['jpg', 'jpeg', 'png'].contains(file.path.split('.').last.toLowerCase());
              return Stack(children: [
                Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: isImage ? Image.file(file, fit: BoxFit.cover, width: double.infinity) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.description, color: Colors.blue), Padding(padding: const EdgeInsets.all(4.0), child: Text(file.path.split('/').last, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)))]),),
                Positioned(right: 0, top: 0, child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() { _selectedFiles.removeAt(index); widget.onFilesChanged(_selectedFiles); })))
              ]);
            }),
      const SizedBox(height: 10),
      InkWell(onTap: _showSourceDialog, child: DottedBorder(
          options: RectDottedBorderOptions(dashPattern: [10, 5], strokeWidth: 2, padding: EdgeInsets.all(16), color: Colors.purple),
          child: Container(height: 100, width: double.infinity, alignment: Alignment.center, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.upload_file, color: Colors.purple), Text("Upload or Capture images using camera.")])))),
    ]);
  }
}