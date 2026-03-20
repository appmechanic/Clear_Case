import 'dart:io';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:clearcase/views/widgets/loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
 import '../../provider/calender_provider.dart';
import '../../provider/dispute_provider.dart';
import '../widgets/attachment_picker_widget.dart';
import '../widgets/custom_dropdown.dart';


class NewDisputeScreen extends StatefulWidget {
  static const routeName = '/new-dispute';
  const NewDisputeScreen({super.key});

  @override
  State<NewDisputeScreen> createState() => _NewDisputeScreenState();
}

class _NewDisputeScreenState extends State<NewDisputeScreen> {
  final _descController = TextEditingController();
  final _descNode = FocusNode();

  DateTime selectedDate = DateTime.now();
  String selectedCategory = "Payment Disputes";
  String selectedParty = "Mother";
  bool flagEntry = false;
  bool isInitialized = false;
  bool _isFetching = false;

  String? _editingDisputeId; // Tracks if we are in Edit Mode
  List<File> _selectedFiles = [];
  List<String> _existingAttachmentUrls = [];

  final List<String> categories = ["Payment Disputes", "Transfer Issues", "Communication"];
  final List<String> parties = ["Mother", "Father", "Grandparent"];

  final _nameController = TextEditingController();
  final _nameNode = FocusNode();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final calProvider = Provider.of<CalendarProvider>(context, listen: false);

      if (args is String) {
        // Edit mode: ID passed directly
        _editingDisputeId = args;
        if (calProvider.selectedCase != null) {
          _loadExistingData(args, calProvider.selectedCase!.id);
        }
      } else if (args is Map<String, dynamic> && args.containsKey('id')) {
        // Edit mode: ID + full data passed
        _editingDisputeId = args['id'];
        final data = args['data'];
        _descController.text = data['description'] ?? '';
        _existingAttachmentUrls = List<String>.from(data['attachments'] ?? []);
        // ... fill other fields ...
      } else if (args is DateTime) {
        selectedDate = args;
      }
      isInitialized = true;
    }
  }

  Future<void> _loadExistingData(String disputeId, String caseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isFetching = true); // Start local loader

    try {
      final doc = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase')
          .collection('users').doc(user.uid).collection('cases').doc(caseId)
          .collection('disputeRecords').doc(disputeId).get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _descController.text = data['description'] ?? '';
          selectedDate = (data['date'] as Timestamp).toDate();
          selectedCategory = data['category'] ?? "Payment Disputes"; // Set default if null
          selectedParty = data['party'] ?? "Mother";
          flagEntry = data['flagEntry'] ?? false;
          _nameController.text = data['name'] ?? '';
          _existingAttachmentUrls = List<String>.from(data['attachments'] ?? []);
        });
      }
    } finally {
      if (mounted) setState(() => _isFetching = false); // Stop local loader
    }
  }

  void _submitForm(DisputeProvider provider, String caseId) {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a description")));
      return;
    }

    final data = {
      'date': selectedDate,
      'category': selectedCategory,
      'description': _descController.text.trim(),
      'name': _nameController.text.trim(), // Added
      'party': selectedParty,
      'flagEntry': flagEntry,
      'disputeStatus': _editingDisputeId == null ? 'Open' : null, // Set 'Open' only for new entries
    };
     data.removeWhere((key, value) => value == null);
    if (_editingDisputeId == null) {
      provider.addDispute(context: context, caseId: caseId, data: data, attachments: _selectedFiles);
    } else {
      // NOTE: Ensure your provider has the updateDispute method defined as discussed
      provider.updateDispute(
        context: context,
        caseId: caseId,
        disputeId: _editingDisputeId!,
        data: data,
        newAttachments: _selectedFiles,
        existingUrls: _existingAttachmentUrls,
      );
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _descNode.dispose();
    _nameController.dispose();
    _nameNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CalendarProvider, DisputeProvider>(
      builder: (context, calProvider, disputeProvider, child) {
        final selectedCase = calProvider.selectedCase;
        final isEditing = _editingDisputeId != null;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: _buildAppBar(calProvider),
            body: (disputeProvider.isLoading || _isFetching) // Check BOTH loaders
              ? const Center(child: AppLoader())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClickableField("Date", DateFormat('dd MMM yyyy').format(selectedDate), () async {
                  final d = await showDatePicker(
                      context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2030));
                  if (d != null) setState(() => selectedDate = d);
                }),
                const SizedBox(height: 15),
                _buildLabel("Category"),
                CustomDropDown<String>(
                  value: selectedCategory,
                  hint: "Select Category",
                  items: categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  labelText: "Description",
                  hintText: "Describe the dispute in detail.",
                  maxLines: 3,
                  controller: _descController,
                  node: _descNode,
                  borderRadius: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 15),
                 CustomTextField(
                   labelText: "Name of the Related party",
                  hintText: "Enter the name",
                  maxLines: 1, // Usually a name is a single line
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
                  items: parties.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => selectedParty = v!),
                ),
                const SizedBox(height: 25),
                const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                if (_existingAttachmentUrls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 8,
                      children: _existingAttachmentUrls.map((url) => _buildExistingFilePreview(url)).toList(),
                    ),
                  ),
                AttachmentPickerWidget(onFilesChanged: (files) => setState(() => _selectedFiles = files)),
                const SizedBox(height: 20),
                _buildSwitchTile("Flag this entry", flagEntry, (v) => setState(() => flagEntry = v)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    onPressed: selectedCase == null ? null : () => _submitForm(disputeProvider, selectedCase.id),
                    child: Text(isEditing ? "Update Dispute" : "Open Dispute",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildSwitchTile(String t, bool v, Function(bool) c) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      Switch(value: v, activeTrackColor: const Color(0xFF4A148C), activeThumbColor: Colors.white, onChanged: c)
    ],
  );

  AppBar _buildAppBar(CalendarProvider calProvider) {
    return AppBar(
      title: Text(_editingDisputeId == null ? "New Dispute" : "Edit Dispute",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent, elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: CustomDropDown<String>(
            hint: "Select a Case",
            value: calProvider.selectedCase?.id,
            items: calProvider.allCases.map((c) => DropdownMenuItem(value: c.id, child: Text(c.caseNumber))).toList(),
            onChanged: (id) => calProvider.setSelectedCase(calProvider.allCases.firstWhere((c) => c.id == id)),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)));

  Widget _buildClickableField(String label, String value, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildLabel(label),
      InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          child: Row(children: [Text(value, style: const TextStyle(fontSize: 15)), const Spacer(), const Icon(Icons.calendar_today, size: 18, color: Colors.grey)])))
    ]);
  }



// 1. Add this to handle the "Remove" button
  Widget _buildExistingFilePreview(String url) {
    bool isPdf = url.toLowerCase().contains('.pdf');
    return Padding(
      padding: const EdgeInsets.only(top: 5, right: 5),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              image: isPdf ? null : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
            ),
            child: isPdf ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30) : null,
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
}

