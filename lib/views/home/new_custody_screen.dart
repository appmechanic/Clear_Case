import 'dart:io';

import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/custody_model.dart';
import 'package:clearcase/provider/new_entry_provider.dart'; 
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:provider/provider.dart';
import '../widgets/attachment_picker_widget.dart';
import '../widgets/custom_dropdown.dart';


class NewCustodyScreen extends StatefulWidget {
  static const routeName = '/new-custody';
  const NewCustodyScreen({super.key});

  @override
  State<NewCustodyScreen> createState() => _NewCustodyScreenState();
}

class _NewCustodyScreenState extends State<NewCustodyScreen> {
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // Mode tracking
  String? editRecordId;
  bool isInitialized = false;
  bool _isFetching = false; // Add this

  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
  bool isScheduled = false;
  bool isFulfilled = true;
  bool flagEntry = false;

  List<File> _selectedFiles = [];
  List<String> _existingAttachmentUrls = []; // To store existing Firebase links
  Set<String> selectedChildIds = {};



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we passed an ID for editing
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String && !isInitialized) {
      editRecordId = args;
      _loadExistingData();
      isInitialized = true;
    }
  }

  Future<void> _loadExistingData() async {
    setState(() => _isFetching = true);

    final provider = Provider.of<NewEntryProvider>(context, listen: false);

    // 1. ADD THIS: Wait for the provider to have a selected case if it's not ready
    // This loop polls for up to 2 seconds to ensure the case is populated
    int retryCount = 0;
    while (provider.selectedCase == null && retryCount < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      retryCount++;
    }

    // 2. Now attempt to fetch
    if (provider.selectedCase != null && editRecordId != null) {
      final record = await provider.getCustodyRecordById(editRecordId!);

      if (mounted && record != null) {
        setState(() {
          selectedDate = record.startDate ?? DateTime.now();
          startTime = TimeOfDay.fromDateTime(record.startTime ?? DateTime.now());
          endTime = TimeOfDay.fromDateTime(record.endTime ?? DateTime.now());
          isScheduled = record.isScheduled ?? false;
          isFulfilled = record.isFulfilled ?? true;
          flagEntry = record.flagEntry ?? false;
          _locationController.text = record.location ?? "";
          _notesController.text = record.notes ?? "";
          selectedChildIds = Set.from(record.childIds ?? []);
          _existingAttachmentUrls = record.attachmentUrls ?? [];
        });
      }
    }

    // 3. Always hide loader
    if (mounted) {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _pickDate() async {


    final DateTime? picked = await showDatePicker(
        context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
        context: context, initialTime: isStart ? startTime : endTime);
    if (picked != null) setState(() => isStart ? startTime = picked : endTime = picked);
  }

  void _submitForm(NewEntryProvider provider) {
    if (provider.selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a case")));
      return;
    }
    if (selectedChildIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one child")));
      return;
    }

    final startDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
    final endDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime.hour, endTime.minute);

    if (startDateTime.isAtSameMomentAs(endDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Start time and End time cannot be the same.")));
      return;
    }

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End time cannot be before Start time.")));
      return;
    }

    final record = CustodyRecordModel(
      id: editRecordId, // Important for updates
      caseId: provider.selectedCase!.id,
      childIds: selectedChildIds.toList(),
      startDate: selectedDate,
      startTime: startDateTime,
      endTime: endDateTime,
      isScheduled: isScheduled,
      location: _locationController.text.trim(),
      isFulfilled: isFulfilled,
      notes: _notesController.text.trim(),
      flagEntry: flagEntry,
      createdAt: editRecordId == null ? DateTime.now() : null,
      attachmentUrls: _existingAttachmentUrls, // Keep existing ones
    );

    if (editRecordId == null) {
      provider.addCustodyRecord(context, record, _selectedFiles);
    } else {
      provider.updateCustodyRecord(context, record, _selectedFiles);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    // REMOVE: ChangeNotifierProvider(...)
    // USE: Only Consumer<NewEntryProvider>
    return Consumer<NewEntryProvider>(
      builder: (context, provider, child) {
        bool showLoader = provider.isLoading || _isFetching;
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            appBar: _buildAppBar(context, provider),
            body:showLoader
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChildSelector(provider),
                  const SizedBox(height: 20),
                  _buildClickableField("Start Date", DateFormat('dd MMM yyyy').format(selectedDate), Icons.calendar_today, _pickDate),
                  const SizedBox(height: 15),
                  Row(children: [
                    Expanded(child: _buildClickableField("Start Time", startTime.format(context), Icons.access_time, () => _pickTime(true))),
                    const SizedBox(width: 15),
                    Expanded(child: _buildClickableField("End Time", endTime.format(context), Icons.access_time, () => _pickTime(false))),
                  ]),
                  const SizedBox(height: 20),
                  _buildSwitchTile("It is a scheduled custody date", isScheduled, (v) => setState(() => isScheduled = v)),
                  const SizedBox(height: 15),
                  CustomTextField(labelText: "Location", hintText: "Enter location", controller: _locationController, node: FocusNode(), borderRadius: 8, backgroundColor: Colors.grey.shade200),
                  const SizedBox(height: 15),
                  _buildSwitchTile("Custody Fulfilled", isFulfilled, (v) => setState(() => isFulfilled = v)),
                  const SizedBox(height: 15),
                  CustomTextField(labelText: "Notes", hintText: "Enter details", maxLines: 3, controller: _notesController, node: FocusNode(), borderRadius: 8, backgroundColor: Colors.grey.shade200),
                  const SizedBox(height: 20),

                  const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // Display Existing Attachments from Firebase (Edit Mode)
                  if (_existingAttachmentUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        spacing: 8,
                        children: _existingAttachmentUrls.map((url) => _buildExistingFilePreview(url)).toList(),
                      ),
                    ),

                  AttachmentPickerWidget(
                    onFilesChanged: (files) {
                      setState(() => _selectedFiles = files);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSwitchTile("Flag this entry", flagEntry, (v) => setState(() => flagEntry = v)),
                  const SizedBox(height: 30),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: () => _submitForm(provider), child: Text(editRecordId == null ? "Save Record" : "Update Record", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                ],
              ),
            ),
          );
        },
     );
  }

  // Preview for files already in Firebase Storage
  Widget _buildExistingFilePreview(String url) {
    bool isPdf = url.toLowerCase().contains('.pdf');
    return Stack(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            image: isPdf ? null : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
          ),
          child: isPdf ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30) : null,
        ),
        Positioned(
          right: -5,
          top: -5,
          child: GestureDetector(
            onTap: () => setState(() => _existingAttachmentUrls.remove(url)),
            child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  AppBar _buildAppBar(BuildContext context, NewEntryProvider provider) {
    return AppBar(
      title: Text(editRecordId == null ? "New Custody Record" : "Edit Custody Record",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: CustomDropDown<CaseModel>(
            hint: "Select a Case",
            value: provider.selectedCase,
            items: provider.userCases.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c.caseNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
            )).toList(),
            onChanged: (c) {
              provider.selectCase(c);
              setState(() => selectedChildIds.clear());
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChildSelector(NewEntryProvider provider) {
    final children = provider.selectedCase?.children ?? [];
    if (children.isEmpty) return const Text("No children in this case");

    return Column(
      children: children.map((child) {
        final isSelected = selectedChildIds.contains(child.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.purple[50], child: const Icon(Icons.person, color: Colors.purple)),
            title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: const Color(0xFF4A148C)),
            onTap: () => setState(() => isSelected ? selectedChildIds.remove(child.id) : selectedChildIds.add(child.id)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClickableField(String l, String v, IconData i, VoidCallback t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontWeight: FontWeight.w500)), const SizedBox(height: 8), InkWell(onTap: t, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Row(children: [Text(v), const Spacer(), Icon(i, size: 18, color: Colors.grey[700])])))]);
  Widget _buildSwitchTile(String t, bool v, Function(bool) c) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), Switch(value: v,activeTrackColor: const Color(0xFF4A148C),activeThumbColor: Colors.white, onChanged: c)]);
}