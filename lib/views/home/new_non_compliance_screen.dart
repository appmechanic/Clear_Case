import 'dart:io';
import 'package:clearcase/views/widgets/loader.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:clearcase/core/utils/attachments.dart';
import 'package:clearcase/views/widgets/attachment_picker_widget.dart';
import 'package:clearcase/views/widgets/attachment_preview.dart';
import 'package:clearcase/views/widgets/file_type_icon.dart';
import '../../provider/calender_provider.dart';
import '../../provider/non_compliance_provider.dart';
import '../widgets/custom_dropdown.dart';

class NewNonComplianceScreen extends StatefulWidget {
  static const routeName = '/new-non-compliance';
  const NewNonComplianceScreen({super.key});

  @override
  State<NewNonComplianceScreen> createState() => _NewNonComplianceScreenState();
}

class _NewNonComplianceScreenState extends State<NewNonComplianceScreen> {
  final _descController = TextEditingController();
  final _proofController = TextEditingController();
  final _descNode = FocusNode();
  final _proofNode = FocusNode();
  final _nameController = TextEditingController();
  final _nameNode = FocusNode();

  DateTime selectedDate = DateTime.now();
  String selectedType = "Late for pickup/handover";
  String selectedParty = "Mother";
  String severity = "Serious";
  bool flagEntry = false;
  bool isInitialized = false;
  bool _isFetching = false;

  String? _editingNonComplianceId;
  List<File> _selectedFiles = [];
  List<String> _existingAttachmentUrls = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final calProvider = Provider.of<CalendarProvider>(context, listen: false);

      if (args is String) {
        _editingNonComplianceId = args;
        if (calProvider.selectedCase != null) {
          _loadExistingData(args, calProvider.selectedCase!.id);
        }
      } else if (args is DateTime) {
        selectedDate = args;
      }
      isInitialized = true;
    }
  }

// 2. Update the loading function
  Future<void> _loadExistingData(String nonComplianceId, String caseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isFetching = true); // Start loader

    try {
      final doc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase')
          .collection('users').doc(user.uid).collection('cases').doc(caseId)
          .collection('nonComplianceRecords').doc(nonComplianceId).get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _descController.text = data['description'] ?? '';
          _proofController.text = data['proof'] ?? '';
          selectedDate = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
          selectedType = data['type'] ?? "Late for pickup/handover";
          selectedParty = data['party'] ?? "Mother";
          severity = data['severity'] ?? "Serious";
          _nameController.text = data['name'] ?? '';
          flagEntry = data['flagEntry'] ?? false;
          _existingAttachmentUrls = readAttachmentUrls(data);
        });
      }
    } finally {
      if (mounted) setState(() => _isFetching = false); // Stop loader
    }
  }

  void _submitForm(NonComplianceProvider provider, String caseId) {
    final data = {
      'date': selectedDate,
      'type': selectedType,
      'severity': severity,
      'description': _descController.text.trim(),
      'name': _nameController.text.trim(),
      'party': selectedParty,
      'proof': _proofController.text.trim(),
      'flagEntry': flagEntry,
    };

    if (_editingNonComplianceId == null) {
      provider.addNonCompliance(context, caseId, data, _selectedFiles);
    } else {
      provider.updateNonCompliance(context, caseId, _editingNonComplianceId!, data, _selectedFiles, _existingAttachmentUrls);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _proofController.dispose();
    _descNode.dispose();
    _proofNode.dispose();
    _nameController.dispose();
    _nameNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CalendarProvider, NonComplianceProvider>(
      builder: (context, calProvider, nonComplianceProvider, child) {
        final selectedCase = calProvider.selectedCase;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: _buildAppBar(calProvider),
            body: (nonComplianceProvider.isLoading || _isFetching)
          ? const Center(child: AppLoader())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                _buildClickableField("Date", DateFormat('dd MMM yyyy').format(selectedDate), () async {
                  final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2030));
                  if (d != null) setState(() => selectedDate = d);
                }),
                const SizedBox(height: 15),
                _buildLabel("Non-compliance Type"),
                CustomDropDown<String>(
                  value: selectedType,
                  hint: "Select Non-compliance Type",
                  items: ["Late for pickup/handover", "Missed Visit", "Unauthorized Travel"]
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
                const SizedBox(height: 15),
                Align(alignment: Alignment.centerLeft, child: Text("Severity", style: TextStyle(fontWeight: FontWeight.w500))),
                Row(children: ["Serious", "Moderate", "Minor"].map((l) => Padding(padding: const EdgeInsets.only(right: 10), child: _buildChip(l))).toList()),
                const SizedBox(height: 15),
                CustomTextField(labelText: "Description", hintText: "Describe the non-compliance...", maxLines: 3, controller: _descController, node: _descNode, borderRadius: 8, backgroundColor: Colors.grey.shade200),
                const SizedBox(height: 15),
                 CustomTextField(
                  labelText: "Name of the Related party",
                  hintText: "Enter the name",
                  maxLines: 1,
                  controller: _nameController,
                  node: _nameNode,
                  borderRadius: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 15),
                _buildLabel("Related Party"),
                CustomDropDown<String>(
                  value: selectedParty,
                  hint: "Select Party",
                  items: ["Mother", "Father"]
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedParty = v!),
                ),
                const SizedBox(height: 15),
                CustomTextField(labelText: "Evidence/Proof (Optional)", hintText: "Summarize proof", maxLines: 3, controller: _proofController, node: _proofNode, borderRadius: 8, backgroundColor: Colors.grey.shade200),
                const SizedBox(height: 15),

                // Attachments Section
                const Align(alignment: Alignment.centerLeft, child: Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold))),
                if (_existingAttachmentUrls.isNotEmpty)
                  Wrap(spacing: 8, children: _existingAttachmentUrls.map((url) => _buildExistingFilePreview(url)).toList()),
                AttachmentPickerWidget(onFilesChanged: (files) => setState(() => _selectedFiles = files)),

                const SizedBox(height: 20),
                SwitchListTile(title: const Text("Flag this entry"), value: flagEntry, onChanged: (v) => setState(() => flagEntry = v)),
                const SizedBox(height: 20),

                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                  onPressed: selectedCase == null ? null : () => _submitForm(nonComplianceProvider, selectedCase.id),
                  child: Text(_editingNonComplianceId == null ? "Save Record" : "Update Record", style: const TextStyle(color: Colors.white)),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets (Reusable) ---
  Widget _buildChip(String label) {
    bool isSelected = severity == label;
    return GestureDetector(
      onTap: () => setState(() => severity = label),
      child: Chip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.blue[900] : Colors.black)),
        backgroundColor: isSelected ? Colors.blue[100] : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey)),
      ),
    );
  }


  AppBar _buildAppBar(CalendarProvider calProvider) {
    bool isEditMode = _editingNonComplianceId != null;

    return AppBar(
      title: Text(
          !isEditMode ? "New Non Compliance" : "Edit Non Compliance",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      bottom: PreferredSize(
        // Height set to 70 to provide room for wrapped child names
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: IgnorePointer(
            ignoring: isEditMode,
            child: Opacity(
              opacity: isEditMode ? 0.6 : 1.0,
              child: CustomDropDown<String>(
                hint: "Select a Case",
                value: calProvider.selectedCase?.id,
                items: calProvider.allCases.map((c) {
                  return DropdownMenuItem<String>(
                    value: c.id,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        calProvider.getCaseDisplayName(c), // Displays "Case Number (Child Names)"
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                          height: 1.3, // Improves readability when text wraps
                        ),
                        softWrap: true,   // Allows text to wrap to the next line
                        maxLines: null,   // Allows expansion for many children
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    final selected = calProvider.allCases.firstWhere((c) => c.id == id);
                    calProvider.setSelectedCase(selected);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExistingFilePreview(String url) {
    final ext = extensionFromUrl(url);
    final isImage = isImageExtension(ext);
    final typeInfo = fileTypeFromExtension(ext);
    return Padding(
      padding: const EdgeInsets.only(top: 5, right: 5),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => AttachmentPreview.openUrl(context, url),
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                image: isImage ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
              ),
              child: isImage ? null : FileTypeTile(info: typeInfo),
            ),
          ),
          Positioned(
            right: -8, top: -8,
            child: GestureDetector(
              onTap: () => setState(() => _existingAttachmentUrls.remove(url)),
              child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableField(String l, String v, VoidCallback t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontWeight: FontWeight.w500)), const SizedBox(height: 8), InkWell(onTap: t, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Row(children: [Text(v), const Spacer(), const Icon(Icons.calendar_today, size: 18)])))]);
  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
  );
}
