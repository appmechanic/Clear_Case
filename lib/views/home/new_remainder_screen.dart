import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/remainder_model.dart';
import 'package:clearcase/provider/remainder_provider.dart';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_dropdown.dart';

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
  String repeatOption = "None";
  String remindMeOption = "On day of event";
  bool enableNotifications = true;

  bool _isInit = true;
  String? _editingId;
  bool _isFetching = false; // Add this

  final List<String> types = ["Birthday", "Medical", "School", "Court", "Other"];
  final List<String> repeatOptions = ["None", "Daily", "Weekly", "Monthly", "Custom interval (user-defined)"];
  final List<String> remindMeOptions = ["On day of event", "1 day before", "A week before"];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        _editingId = args;
        _loadReminderData(_editingId!);
      }
      _isInit = false;
    }
  }

  Future<void> _loadReminderData(String id) async {
    setState(() => _isFetching = true);

    final provider = Provider.of<ReminderProvider>(context, listen: false);

    // Poll for the case to be ready
    int attempts = 0;
    while (provider.selectedCase == null && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }

    try {
      if (provider.selectedCase != null) {
        final reminder = await provider.getReminderById(provider.selectedCase!.id, id);

        if (mounted && reminder != null) {
          setState(() {
            _titleController.text = reminder.title;
            _descController.text = reminder.description;
            selectedDate = reminder.date;
            selectedType = reminder.type;
            repeatOption = reminder.repeatOption;
            _daysController.text = reminder.days ?? "";
            ruleEndDate = reminder.ruleEndDate;
            remindMeOption = reminder.remindMeOption;
            enableNotifications = reminder.enableNotifications;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();

    // 1. Logic:
    // 'isStart == true' -> First date is year 2000 (Flexible)
    // 'isStart == false' -> First date is 'selectedDate' (Strict)
    final DateTime firstDate = isStart ? DateTime(2000) : selectedDate;

    // 2. Determine initial date
    // For End Date, if it's null, default to the start date
    final DateTime initialDate = isStart
        ? selectedDate
        : (ruleEndDate ?? selectedDate);

    final DateTime? picked = await showDatePicker(
      context: context,
      // Ensure we don't start before the firstDate
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          selectedDate = picked;
          // If start date moves past current end date, reset end date
          if (ruleEndDate != null && ruleEndDate!.isBefore(picked)) {
            ruleEndDate = picked;
          }
        } else {
          ruleEndDate = picked;
        }
      });
    }
  }

  void _submitForm(ReminderProvider provider) {
    if (provider.selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a case")));
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
    }

    final reminder = ReminderModel(
      id: _editingId,
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
      createdAt: _editingId == null ? DateTime.now() : null, // keep old timestamp on update
    );

    if (_editingId == null) {
      provider.addReminder(context, reminder);
    } else {
      provider.updateReminder(context, reminder);
    }
  }
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
  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderProvider>(
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
                _buildClickableField(
                  label: "Date",
                  value: DateFormat('dd MMM yyyy').format(selectedDate),
                  icon: Icons.calendar_today,
                  onTap: () => _pickDate(context, true),
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
                  onTap: () => _pickDate(context, false),
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Enable Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text("Receive push notifications", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    Switch(
                      value: enableNotifications,
                      activeTrackColor: const Color(0xFF4A148C),activeThumbColor: Colors.white,
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
                    child: Text(_editingId == null ? "Save Record" : "Update Record", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, ReminderProvider provider) {
    return AppBar(
      title: Text(_editingId == null ? "Add Reminder" : "Edit Reminder", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              child: Text("${c.caseNumber} (${c.children.map((e) => e.name).join(', ')})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            )).toList(),
            onChanged: provider.selectCase,
          ),
        ),
      ),
    );
  }

  Widget _buildClickableField({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 8), InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(value, style: const TextStyle(fontSize: 14)), Icon(icon, size: 18, color: Colors.grey[700])])))]);
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 8), CustomDropDown<String>(value: value, hint: "Select $label", items: items.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: onChanged)]);
  }
}