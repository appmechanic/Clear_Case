import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RuleConfigurationScreen extends StatefulWidget {
  static const routeName = '/rule-configuration';
  final String ruleType;
  final List<ChildModel> availableChildren; // Receive children from Step 1

  const RuleConfigurationScreen({
    super.key, 
    this.ruleType = "Rule Configuration",
    required this.availableChildren,
  });

  @override
  State<RuleConfigurationScreen> createState() => _RuleConfigurationScreenState();
}

class _RuleConfigurationScreenState extends State<RuleConfigurationScreen> {
  final _notesController = TextEditingController();
  final _notesNode = FocusNode();

  // State Variables
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String notificationPref = "On the Scheduled day";
  bool isRepeat = true;
  String repeatFrequency = "Weekly";
  bool isEnabled = true;

  // Children Selection Logic
  Set<String> selectedChildIds = {};

  @override
  void initState() {
    super.initState();
    // Default select all children
    selectedChildIds = widget.availableChildren.map((e) => e.id).toSet();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesNode.dispose();
    super.dispose();
  }

  void _onSave() {
    if (startDate == null || startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Start Date and Time are required")));
      return;
    }
    if (!isRepeat && (endDate == null || endTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End Date and Time are required for one-time events")));
      return;
    }
    if (selectedChildIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one child")));
      return;
    }

    // Construct the Rule Object to store in Firebase
    List<ChildModel> selectedChildrenObjects = widget.availableChildren
        .where((child) => selectedChildIds.contains(child.id))
        .toList();

    // 2. CONVERT: Transform those objects into JSON Maps (for Firebase)
    List<Map<String, dynamic>> childrenData = selectedChildrenObjects
        .map((child) => child.toMap())
        .toList();

    final Map<String, dynamic> ruleData = {
      "startDate": startDate!.toIso8601String(),
      "startTime": "${startTime!.hour}:${startTime!.minute}",
      "isRepeat": isRepeat,
      "frequency": isRepeat ? repeatFrequency : null,
      "endDate": isRepeat ? null : endDate?.toIso8601String(),
      "endTime": isRepeat ? null : (endTime != null ? "${endTime!.hour}:${endTime!.minute}" : null),
      "notificationPref": notificationPref,
      "notes": _notesController.text.trim(),
      "isEnabled": isEnabled,
      // Storing Full Objects instead of just IDs
      "appliedChildren": childrenData, 
    };

    Navigator.pop(context, ruleData);
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => isStart ? startDate = picked : endDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (picked != null) setState(() => isStart ? startTime = picked : endTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(widget.ruleType, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Professional case configuration for compliance tracking.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),

            _buildInteractiveField("Rule Start Date *", startDate == null ? "--/--/----" : DateFormat('dd/MM/yyyy').format(startDate!), Icons.calendar_today, () => _pickDate(true)),
            const SizedBox(height: 15),
            _buildInteractiveField("Start Time *", startTime == null ? "--:--" : startTime!.format(context), Icons.access_time, () => _pickTime(true)),
            const SizedBox(height: 15),

            if (!isRepeat) ...[
              _buildInteractiveField("Rule End Date *", endDate == null ? "--/--/----" : DateFormat('dd/MM/yyyy').format(endDate!), Icons.calendar_today, () => _pickDate(false)),
              const SizedBox(height: 15),
              _buildInteractiveField("End Time *", endTime == null ? "--:--" : endTime!.format(context), Icons.access_time, () => _pickTime(false)),
              const SizedBox(height: 20),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Repeat Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Switch(value: isRepeat, activeColor: const Color(0xFF4A148C), onChanged: (v) => setState(() => isRepeat = v)),
              ],
            ),
            
            if (isRepeat) ...[
              const SizedBox(height: 10),
              Row(
                children: ["Weekly", "Fortnightly", "Monthly"].map((freq) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => repeatFrequency = freq),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: repeatFrequency == freq ? const Color(0xFFEDE7F6) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: repeatFrequency == freq ? const Color(0xFF4A148C) : Colors.grey.shade300),
                      ),
                      alignment: Alignment.center,
                      child: Text(freq, style: TextStyle(color: repeatFrequency == freq ? const Color(0xFF4A148C) : Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 20),
            CustomTextField(labelText: "Notes", hintText: "Enter Any Additional Details", maxLines: 3, controller: _notesController, node: _notesNode, borderRadius: 8, backgroundColor: Colors.grey.shade200),
            const SizedBox(height: 25),

            // --- SELECT CHILDREN SECTION (Restored UI) ---
            const Text("Select Children", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
              child: const Text("Select which children this rule applies to.", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black87)),
            ),
            const SizedBox(height: 15),

            // Select All Toggle
            _buildChildItem("Select All", isSelectAll: true),
            
            // Child List
            ...widget.availableChildren.map((child) => _buildChildItem(child.name, id: child.id, subtitle: DateFormat('dd MMM yyyy').format(child.dob))).toList(),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Enable Rule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Switch(value: isEnabled, activeColor: const Color(0xFF4A148C), onChanged: (v) => setState(() => isEnabled = v)),
              ],
            ),
            const SizedBox(height: 30),
            
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _onSave, child: const Text("Save Rule", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveField(String label, String value, IconData icon, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 8), InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(value, style: const TextStyle(fontSize: 14)), Icon(icon, size: 18, color: const Color(0xFF4A148C))])))] );
  }

  Widget _buildChildItem(String title, {String? id, String? subtitle, bool isSelectAll = false}) {
    bool isSelected = isSelectAll 
        ? selectedChildIds.length == widget.availableChildren.length && widget.availableChildren.isNotEmpty
        : selectedChildIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: isSelectAll ? null : CircleAvatar(backgroundColor: Colors.purple[50], child: const Icon(Icons.person, color: Colors.purple)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: const Color(0xFF4A148C)),
        onTap: () {
          setState(() {
            if (isSelectAll) {
              if (isSelected) {
                selectedChildIds.clear();
              } else {
                selectedChildIds = widget.availableChildren.map((e) => e.id).toSet();
              }
            } else {
              if (isSelected) {
                selectedChildIds.remove(id);
              } else {
                selectedChildIds.add(id!);
              }
            }
          });
        },
      ),
    );
  }
}