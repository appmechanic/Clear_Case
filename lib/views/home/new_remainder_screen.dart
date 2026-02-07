
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/remainder_model.dart';
import 'package:clearcase/provider/remainder_provider.dart';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class NewReminderScreen extends StatefulWidget {
  static const routeName = '/new-reminder';
  const NewReminderScreen({super.key});

  @override
  State<NewReminderScreen> createState() => _NewReminderScreenState();
}

class _NewReminderScreenState extends State<NewReminderScreen> {
  final _titleController = TextEditingController();
  final _daysController = TextEditingController();
  final _descController = TextEditingController();
  
  final _titleNode = FocusNode();
  final _daysNode = FocusNode();
  final _descNode = FocusNode();

  DateTime selectedDate = DateTime.now();
  DateTime? ruleEndDate;
  String selectedType = "Birthday";
  String repeatOption = "None"; // Default to None
  String remindMeOption = "On day of event";
  bool enableNotifications = true;

  final List<String> types = ["Birthday", "Medical", "School", "Court", "Other"];
  final List<String> repeatOptions = ["None", "Daily", "Weekly", "Monthly", "Custom interval (user-defined)"];
  final List<String> remindMeOptions = ["On day of event", "1 day before", "A week before", "Custom"];

  @override
  void dispose() {
    _titleController.dispose();
    _daysController.dispose();
    _descController.dispose();
    _titleNode.dispose();
    _daysNode.dispose();
    _descNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) selectedDate = picked;
        else ruleEndDate = picked;
      });
    }
  }

  void _submitForm(ReminderProvider provider) {
    if (provider.selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a case from the top bar")));
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
    }

    final newReminder = ReminderModel(
      caseId: provider.selectedCase!.id,
      date: selectedDate,
      title: _titleController.text.trim(),
      type: selectedType,
      repeatOption: repeatOption,
      days: repeatOption == "Custom interval (user-defined)" ? _daysController.text.trim() : null,
      ruleEndDate: ruleEndDate,
      description: _descController.text.trim(),
      remindMeOption: remindMeOption,
      enableNotifications: enableNotifications,
      createdAt: DateTime.now(),
    );

    provider.addReminder(context, newReminder);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReminderProvider()..init(),
      child: Consumer<ReminderProvider>(
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
                    _buildClickableField(
                      label: "Date",
                      value: DateFormat('dd MMM yyyy').format(selectedDate),
                      icon: Icons.calendar_today,
                      onTap: () => _pickDate(true),
                    ),
                    const SizedBox(height: 15),

                    CustomTextField(
                      labelText: "Reminder Title",
                      hintText: "e.g. Emma's birthday",
                      controller: _titleController,
                      node: _titleNode,
                      borderRadius: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 15),

                    _buildDropdown("Type", selectedType, types, (val) => setState(() => selectedType = val!)),
                    const SizedBox(height: 15),

                    _buildDropdown("Repeat Reminder", repeatOption, repeatOptions, (val) => setState(() => repeatOption = val!)),
                    const SizedBox(height: 15),

                    if (repeatOption == "Custom interval (user-defined)") ...[
                      CustomTextField(
                        labelText: "Days",
                        hintText: "10 days",
                        isNum: true,
                        icon: Icons.calendar_today,
                        controller: _daysController,
                        node: _daysNode,
                        borderRadius: 8,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 15),
                    ],

                    _buildClickableField(
                      label: "Rule End Date",
                      value: ruleEndDate == null ? "Select Date" : DateFormat('dd/MM/yyyy').format(ruleEndDate!),
                      icon: Icons.calendar_today,
                      onTap: () => _pickDate(false),
                    ),
                    const SizedBox(height: 15),

                    CustomTextField(
                      labelText: "Description",
                      hintText: "Describe the event...",
                      maxLines: 3,
                      controller: _descController,
                      node: _descNode,
                      borderRadius: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 15),

                    _buildDropdown("Remind me", remindMeOption, remindMeOptions, (val) => setState(() => remindMeOption = val!)),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("Enable Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            SizedBox(height: 4),
                            Text("Receive push notifications", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        Switch(
                          value: enableNotifications,
                          activeColor: const Color(0xFF4A148C),
                          onChanged: (val) => setState(() => enableNotifications = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A148C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        onPressed: () => _submitForm(provider),
                        child: const Text("Save Record", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, ReminderProvider provider) {
    return AppBar(
      title: const Text("Add Reminder", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              items: provider.userCases.map((CaseModel c) {
                return DropdownMenuItem<CaseModel>(
                  value: c,
                  child: Text(
                    "${c.caseNumber} (${c.children.map((e)=>e.name).join(', ')})",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: provider.selectCase,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClickableField({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 8), InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(value, style: const TextStyle(fontSize: 14)), Icon(icon, size: 18, color: Colors.grey[700])])))] );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, items: items.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: onChanged)))]);
  }
}