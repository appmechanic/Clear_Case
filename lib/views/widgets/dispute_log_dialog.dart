import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/dispute_insight_provider.dart';
import 'attachment_picker_widget.dart';
import 'attachment_preview.dart';
import 'file_type_icon.dart';
import 'custom_text_field.dart';

/// Add/edit dialog for a dispute log. Shared by DisputeDetailsScreen (list rows
/// and "Add New Log") and DisputeLogViewerScreen (full-screen reader).
///
/// Owns its own busy state: it is used from two different screens, so it cannot
/// reach into a host's `_isLoading`. Resolves true when a log was saved.
Future<bool?> showDisputeLogDialog(
  BuildContext context, {
  required String caseId,
  required String disputeId,
  Map<String, dynamic>? existingLog,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _DisputeLogDialog(
      caseId: caseId,
      disputeId: disputeId,
      existingLog: existingLog,
    ),
  );
}

class _DisputeLogDialog extends StatefulWidget {
  final String caseId;
  final String disputeId;
  final Map<String, dynamic>? existingLog;

  const _DisputeLogDialog({
    required this.caseId,
    required this.disputeId,
    this.existingLog,
  });

  @override
  State<_DisputeLogDialog> createState() => _DisputeLogDialogState();
}

class _DisputeLogDialogState extends State<_DisputeLogDialog> {
  late final TextEditingController _titleC;
  late final TextEditingController _descC;
  final FocusNode _titleNode = FocusNode();
  final FocusNode _descNode = FocusNode();

  List<File> _newFiles = [];
  late List<String> _currentUrls;
  bool _isSaving = false;

  bool get _isEdit => widget.existingLog != null;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController(text: widget.existingLog?['title']);
    _descC = TextEditingController(text: widget.existingLog?['description']);
    _currentUrls = widget.existingLog != null
        ? List<String>.from(widget.existingLog!['attachments'] ?? [])
        : [];
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _titleNode.dispose();
    _descNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<DisputeInsightsProvider>(context, listen: false);
    try {
      await provider.saveLog(
        caseId: widget.caseId,
        disputeId: widget.disputeId,
        logId: widget.existingLog?['id'],
        title: _titleC.text,
        desc: _descC.text,
        files: _newFiles,
        remainingUrls: _currentUrls,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? "Log updated" : "Log added")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(const SnackBar(content: Text("Error saving log")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(_isEdit ? "Edit Log" : "New Log",
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(labelText: "Log Title", controller: _titleC, node: _titleNode),
            const SizedBox(height: 10),
            CustomTextField(labelText: "Description", maxLines: 3, controller: _descC, node: _descNode),
            const SizedBox(height: 15),
            const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold)),
            if (_currentUrls.isNotEmpty) const SizedBox(height: 5),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _currentUrls
                  .map((url) => _buildExistingFilePreview(url, () {
                        setState(() => _currentUrls.remove(url));
                      }))
                  .toList(),
            ),
            const SizedBox(height: 5),
            AttachmentPickerWidget(onFilesChanged: (f) {
              setState(() => _newFiles = f);
            }),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: _buttonStyle(),
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: _buttonStyle(),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? "Update log" : "Add log",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }

  ButtonStyle _buttonStyle() => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7B2CBF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  Widget _buildExistingFilePreview(String url, VoidCallback onDelete) {
    final ext = extensionFromUrl(url);
    final isImage = isImageExtension(ext);
    final typeInfo = fileTypeFromExtension(ext);

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: GestureDetector(
            onTap: () => AttachmentPreview.openUrl(context, url),
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
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => FileTypeTile(info: typeInfo),
                      ),
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
