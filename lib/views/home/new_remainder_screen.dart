 import 'package:clearcase/models/remainder_model.dart';
import 'package:clearcase/provider/remainder_provider.dart';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../provider/calender_provider.dart';
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

  String? _editingId;
  bool _isFetching = false;

  DateTime selectedDate = DateTime.now();
  DateTime? ruleEndDate;
  String selectedType = "Birthday";
  bool isRepeat = false;
  String remindMeOption = "On day of event";
  bool enableNotifications = true;

  final List<String> types = ["Birthday", "Medical", "School", "Court", "Other"];
  final List<String> remindMeOptions = ["On day of event", "1 day before", "A week before"];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String && _editingId == null) {
      _editingId = args;
      _loadReminderData();
    } else if (args is DateTime) {
      setState(() {
        selectedDate = args; // <--- Set the date here
      });
    }
  }

  Future<void> _loadReminderData() async {
    setState(() => _isFetching = true);
    final reminderProvider = Provider.of<ReminderProvider>(context, listen: false);
    final calProvider = Provider.of<CalendarProvider>(context, listen: false);

    if (calProvider.selectedCase != null && _editingId != null) {
      final reminder = await reminderProvider.getReminderById(calProvider.selectedCase!.id, _editingId!);
      if (mounted && reminder != null) {
        setState(() {
          _titleController.text = reminder.title;
          _descController.text = reminder.description;
          selectedDate = reminder.date;
          selectedType = reminder.type;
          isRepeat = reminder.isRepeat;
          _daysController.text = reminder.days ?? "";
          ruleEndDate = reminder.ruleEndDate;
          remindMeOption = reminder.remindMeOption;
          enableNotifications = reminder.enableNotifications;
        });
      }
    }
    if (mounted) setState(() => _isFetching = false);
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final DateTime firstDate = isStart ? DateTime(2000) : selectedDate;
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

  void _submitForm(ReminderProvider provider, String caseId) {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
    }

    final reminder = ReminderModel(
      id: _editingId,
      caseId: caseId,
      date: selectedDate,
      title: _titleController.text.trim(),
      type: selectedType,
      isRepeat: isRepeat,
      days: isRepeat ? _daysController.text.trim() : null,
      ruleEndDate: ruleEndDate,
      description: _descController.text.trim(),
      remindMeOption: remindMeOption,
      enableNotifications: enableNotifications,
      createdAt: _editingId == null ? DateTime.now() : null, // keep old timestamp on update
    );

    if (_editingId == null) {
       provider.addReminder(context, caseId, reminder);
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
    return Consumer2<CalendarProvider, ReminderProvider>(
      builder: (context, calProvider, reminderProvider, child) {
        final selectedCase = calProvider.selectedCase;
        bool showLoader = reminderProvider.isLoading || _isFetching;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: _buildAppBar(calProvider),
          body: showLoader
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
                _buildRepeatToggle(),
                if (isRepeat) ...[
                  const SizedBox(height: 10),
                  CustomTextField(
                    labelText: "Days",
                    hintText: "e.g. 10",
                    isNum: true,
                    icon: Icons.calendar_today,
                    controller: _daysController,
                    node: _daysNode,
                    borderRadius: 8,
                    backgroundColor: Colors.grey.shade200,
                  ),

                ],
                const SizedBox(height: 20),
                _buildDropdown("Remind me", remindMeOption, remindMeOptions, (val) => setState(() => remindMeOption = val!)),
                 const SizedBox(height: 20),
                // _buildClickableField(
                //   label: "Rule End Date",
                //   value: ruleEndDate == null ? "Select Date" : DateFormat('dd/MM/yyyy').format(ruleEndDate!),
                //   icon: Icons.calendar_today,
                //   onTap: () => _pickDate(context, false),
                // ),
                // const SizedBox(height: 15),


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
                    onPressed: selectedCase == null ? null : () => _submitForm(reminderProvider, selectedCase.id),
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

  AppBar _buildAppBar(CalendarProvider calProvider) {
    return AppBar(
      leading: IconButton(onPressed: (){
        Navigator.pop(context);
      }, icon: Icon(Icons.arrow_back, color: Colors.black)),

      title: Text(_editingId == null ? "Add Reminder" : "Edit Reminder",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: CustomDropDown<String>(
            hint: "Select a Case",
            value: calProvider.selectedCase?.id,
            items: calProvider.allCases.map((c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.caseNumber),
            )).toList(),
            onChanged: (id) => calProvider.setSelectedCase(calProvider.allCases.firstWhere((c) => c.id == id)),
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
  Widget _buildRepeatToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Repeat Reminder", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Switch(
          value: isRepeat,
          activeTrackColor: const Color(0xFF4A148C),
          activeThumbColor: Colors.white,
          onChanged: (val) => setState(() => isRepeat = val),
        ),
      ],
    );
  }
}