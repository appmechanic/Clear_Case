import 'package:clearcase/views/widgets/loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clearcase/models/case_model.dart'; // Ensure ChildModel is accessible
import 'package:clearcase/views/widgets/custom_text_field.dart';
import '../../provider/rule_configuration_provider.dart';
import '../main_screen.dart';
import '../widgets/custom_dropdown.dart';


class RuleConfigurationScreen extends StatefulWidget {
  static const routeName = '/rule-configuration';
  final String? caseId;
  final String category;
  final List<ChildModel> availableChildren;

  const RuleConfigurationScreen({
    super.key,
    this.caseId,
    required this.category,
    required this.availableChildren,
  });

  @override
  State<RuleConfigurationScreen> createState() => _RuleConfigurationScreenState();
}


class _RuleConfigurationScreenState extends State<RuleConfigurationScreen>  {
  List<int> selectedDays = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pass only the 3 required arguments
      context.read<RuleConfigurationProvider>().init(
        widget.caseId,
        widget.category,
        widget.availableChildren,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RuleConfigurationProvider>();

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: AppLoader()));
    }



    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Rule Configuration", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Start Date & Time (Always Visible)
            _buildInteractiveField("Rule Start Date *", provider.startDate == null ? "--/--/----" : DateFormat('dd/MM/yyyy').format(provider.startDate!), Icons.calendar_today, () => _pickDate(context, true)),
            const SizedBox(height: 15),
            _buildInteractiveField("Start Time *", provider.startTime == null ? "--:--" : provider.startTime!.format(context), Icons.access_time, () => _pickTime(context, true)),

            const SizedBox(height: 15),

            // 2. Repeat Toggle
            _buildRepeatToggle(provider),

            const SizedBox(height: 15),

            // 3. Conditional UI logic
            if (provider.isRepeat) ...[
              const Text("Select Days", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              _buildDaySelector(provider),
              const SizedBox(height: 20),

               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Add End Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text("Set a specific end date for this rule", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  Switch(
                    value: provider.hasEndDate,
                    activeTrackColor: const Color(0xFF4A148C),
                    onChanged: (v) => provider.toggleHasEndDate(v),
                  ),
                ],
              ),

               if (provider.hasEndDate) ...[
                const SizedBox(height: 15),
                _buildInteractiveField("Rule End Date", provider.endDate == null ? "--/--/----" : DateFormat('dd/MM/yyyy').format(provider.endDate!), Icons.calendar_today, () => _pickDate(context, false)),
                const SizedBox(height: 15),
                _buildInteractiveField("End Time", provider.endTime == null ? "--:--" : provider.endTime!.format(context), Icons.access_time, () => _pickTime(context, false)),
              ],
              ] else ...[
               _buildInteractiveField("Rule End Date", provider.endDate == null ? "--/--/----" : DateFormat('dd/MM/yyyy').format(provider.endDate!), Icons.calendar_today, () => _pickDate(context, false)),
              const SizedBox(height: 15),
              _buildInteractiveField("End Time", provider.endTime == null ? "--:--" : provider.endTime!.format(context), Icons.access_time, () => _pickTime(context, false)),
            ],

            const SizedBox(height: 20),

            // 4. Notification & Notes
            const Text("Notification Preference", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _buildNotificationDropdown(provider),
            const SizedBox(height: 20),
            CustomTextField(
              labelText: "Notes",
              hintText: "Enter Any Additional Details",
              maxLines: 3,
              node: provider.notesNode,
              controller: provider.notesController,
              borderRadius: 8,
              backgroundColor: Colors.grey.shade200,
            ),

            const SizedBox(height: 25),
            const Text("Select Children", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            _buildComplianceNote(),
            const SizedBox(height: 10),

            // 5. Children Selection List
            _buildChildItem(
              "Select All",
              null,
              provider.selectedChildIds.length == provider.allChildrenOptions.length && provider.allChildrenOptions.isNotEmpty,
                  () {
                if (provider.selectedChildIds.length == provider.allChildrenOptions.length) {
                  provider.clearSelectedChildren();
                } else {
                  provider.selectAllChildrenFromMap(provider.allChildrenOptions);
                }
              },
            ),

            ...provider.allChildrenOptions.map((childMap) {
              final String id = childMap['id'].toString();
              final String name = childMap['name'];
              DateTime dob = (childMap['dob'] is Timestamp)
                  ? (childMap['dob'] as Timestamp).toDate()
                  : DateTime.parse(childMap['dob'].toString());

              return _buildChildItem(
                name,
                DateFormat('dd MMM yyyy').format(dob),
                provider.selectedChildIds.contains(id),
                    () => provider.toggleChildSelection(id),
              );
            }).toList(),

            const SizedBox(height: 15),
            _buildAddNewChildButton(context, provider),
            const SizedBox(height: 20),
            _buildEnableToggle(provider),
            const SizedBox(height: 30),
            _buildSaveButton(context, provider),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }


  Widget _buildDaySelector(RuleConfigurationProvider provider) {
    final List<Map<String, dynamic>> weekDays = [
      {"name": "Mon", "value": DateTime.monday},
      {"name": "Tue", "value": DateTime.tuesday},
      {"name": "Wed", "value": DateTime.wednesday},
      {"name": "Thu", "value": DateTime.thursday},
      {"name": "Fri", "value": DateTime.friday},
      {"name": "Sat", "value": DateTime.saturday},
      {"name": "Sun", "value": DateTime.sunday},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDays.map((day) {
        bool isSelected = provider.selectedDays.contains(day['value']);
        return GestureDetector(
          onTap: () => provider.toggleDay(day['value']),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4A148C) : Colors.grey[200],
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Colors.purple : Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: Text(
              day['name'],
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComplianceNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
      child: const Column(
        children: [
          Text("Compliance Calculation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 6),
          Text(
            "Compliance is calculated per child. Select which children this rule applies to for accurate tracking and legal documentation.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewChildButton(BuildContext context, RuleConfigurationProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF4A148C)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: const Color(0xFFE1F5FE).withOpacity(0.5),
        ),
        onPressed: () => _showAddChildPopup(context, provider),
        child: const Text("Add New Child", style: TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Popup for adding a child as requested
  void _showAddChildPopup(BuildContext context, RuleConfigurationProvider provider) {
    final nameCtrl = TextEditingController();
    DateTime tempDob = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Add New Child", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Child Name", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: tempDob,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setPopupState(() => tempDob = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd/MM/yyyy').format(tempDob)),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            // Inside _showAddChildPopup
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C)),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  // Pass IDs so the provider knows if it needs to sync to DB immediately
                  provider.addChild(
                      nameCtrl.text.trim(),
                      tempDob,
                      widget.caseId,
                      widget.category
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text("Add", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // --- Core Form Components ---

  Widget _buildNotificationDropdown(RuleConfigurationProvider provider) {
    // Define the master list of options
    final List<String> options = [
      "On the Scheduled day", "1 Day Before", "7 Days Before", "Turn Off Notifications"
    ];

    // SAFETY CHECK: If the current value in provider isn't in our list,
    // we must either add it or set the dropdown value to null to prevent a crash.
    final String? currentValue = options.contains(provider.notificationPref)
        ? provider.notificationPref
        : null;

    return CustomDropDown<String>(
      value: currentValue,
      hint: "Select Notification Preference",
      items: options.map((val) => DropdownMenuItem(
          value: val,
          child: Text(val, style: const TextStyle(fontSize: 14))
      )).toList(),
      onChanged: (val) {
        if (val != null) provider.setNotification(val);
      },
    );
  }

  Widget _buildRepeatToggle(RuleConfigurationProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Repeat Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Switch(value: provider.isRepeat,activeTrackColor: const Color(0xFF4A148C),activeThumbColor: Colors.white, onChanged: (v) => provider.toggleRepeat(v)),
      ],
    );
  }


  Widget _buildEnableToggle(RuleConfigurationProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Enable Rule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Switch(value: provider.isEnabled, activeThumbColor: const Color(0xFF4A148C), onChanged: (v) => provider.toggleEnabled(v)),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, RuleConfigurationProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A148C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        onPressed: () async {
          // 1. Validate Children
          if (provider.selectedChildIds.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one child.")));
            return;
          }
          // 2. Start Date & Time Validation
          if (provider.startDate == null || provider.startTime == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Start Date and Time.")));
            return;
          }

           if (!provider.isRepeat) {
             if (provider.endDate == null || provider.endTime == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End Date and Time are required for non-recurring rules.")));
              return;
            }
          } else if (provider.hasEndDate && provider.endDate == null) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an end date or turn off the toggle.")));
            return;
          }

          if (provider.isRepeat && provider.selectedDays.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select at least one day for the schedule"))
            );
            return;
          }


          // 3. Execution
          bool success = await provider.updateRuleInFirestore(caseId: widget.caseId, category: widget.category);

          if (success && context.mounted) {
            // Show Success SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Rule Sync Successful!"),
              ),
            );

            // Wait a brief moment so the user sees the SnackBar before navigating away
            await Future.delayed(const Duration(milliseconds: 800));

            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                MainScreen.routeName,
                arguments: 0,
                    (route) => false,
              );
            }
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save. Check your connection.")));
          }
        },
        child: const Text("Save Rule", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }


  Widget _buildInteractiveField(String label, String value, IconData icon, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(value, style: const TextStyle(fontSize: 14)),
            Icon(icon, size: 18, color: const Color(0xFF4A148C))
          ]),
        ),
      ),
    ]);
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final provider = context.read<RuleConfigurationProvider>();
    DateTime initialDate = (isStart || provider.startDate == null) ? DateTime.now() : provider.startDate!;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: (isStart) ? DateTime(2000) : initialDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      if (isStart) {
        provider.updateStartDate(picked);
        if (provider.endDate != null && provider.endDate!.isBefore(picked)) {
          provider.updateEndDate(picked);
        }
      } else {
        provider.updateEndDate(picked);
      }
    }
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0)
    );
    if (picked != null) {
      final provider = context.read<RuleConfigurationProvider>();
      if (isStart) provider.updateStartTime(picked);
      else provider.updateEndTime(picked);
    }
  }

  Widget _buildChildItem(String title, String? subtitle, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1F5FE)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF3E5F5),
          child: Icon(Icons.person, color: Color(0xFF4A148C), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)) : null,
        trailing: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: const Color(0xFF4A148C),
        ),
      ),
    );
  }
}