import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/custody_model.dart';
import 'package:clearcase/provider/new_entry_provider.dart'; 
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:provider/provider.dart';

class NewCustodyScreen extends StatefulWidget {
  static const routeName = '/new-custody';
  const NewCustodyScreen({super.key});

  @override
  State<NewCustodyScreen> createState() => _NewCustodyScreenState();
}

class _NewCustodyScreenState extends State<NewCustodyScreen> {
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
  bool isScheduled = true;
  bool isFulfilled = true;
  bool flagEntry = false;
  
  Set<String> selectedChildIds = {};

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
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

    final newRecord = CustodyRecordModel(
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
      createdAt: DateTime.now(),
    );

    // Call the unified provider method
    provider.addCustodyRecord(context, newRecord);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NewEntryProvider()..init(),
      child: Consumer<NewEntryProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            appBar: _buildAppBar(context, provider),
            body: provider.isLoading 
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
                    
                    _buildAttachmentBox(),
                    const SizedBox(height: 20),
                    
                    _buildSwitchTile("Flag this entry", flagEntry, (v) => setState(() => flagEntry = v)),
                    const SizedBox(height: 30),
                    
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: () => _submitForm(provider), child: const Text("Save Record", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                  ],
                ),
              ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, NewEntryProvider provider) {
    return AppBar(
      title: const Text("New Custody Record", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          color: Colors.grey.shade100,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CaseModel>(
              isExpanded: true,
              hint: const Text("Select a Case"),
              value: provider.selectedCase,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A148C)),
              items: provider.userCases.map((c) => DropdownMenuItem(value: c, child: Text(c.caseNumber, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
              onChanged: (c) {
                provider.selectCase(c);
                setState(() => selectedChildIds.clear());
              },
            ),
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
  Widget _buildSwitchTile(String t, bool v, Function(bool) c) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), Switch(value: v, activeColor: const Color(0xFF4A148C), onChanged: c)]);
  Widget _buildAttachmentBox() => Container(height: 100, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFF8F5FB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF4A148C).withOpacity(0.3))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.upload_file, color: Color(0xFF4A148C)), SizedBox(height: 5), Text("Upload Attachment", style: TextStyle(color: Colors.grey))]));
}