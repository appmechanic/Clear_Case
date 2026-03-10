import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clearcase/models/case_model.dart'; // Ensure ChildModel is accessible
import 'package:clearcase/views/widgets/custom_text_field.dart';
import '../../provider/rule_configuration_provider.dart';
import 'calender_screen.dart';


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


class _RuleConfigurationScreenState extends State<RuleConfigurationScreen> {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("Rule Configuration",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInteractiveField(
              "Rule Start Date *",
              provider.startDate == null ? "--/--/----" : DateFormat('dd/MM/yyyy').format(provider.startDate!),
              Icons.calendar_today,
                  () => _pickDate(context, true),
            ),
            const SizedBox(height: 15),
            _buildInteractiveField(
              "Start Time *",
              provider.startTime == null ? "--:--" : provider.startTime!.format(context),
              Icons.access_time,
                  () => _pickTime(context, true),
            ),
            const SizedBox(height: 15),
            _buildInteractiveField(
              "Rule End Date",
              provider.endDate == null ? "--/--/----" : DateFormat('dd/MM/yyyy').format(provider.endDate!),
              Icons.calendar_today,
                  () => _pickDate(context, false),
            ),
            const SizedBox(height: 15),
            _buildInteractiveField(
              "End Time",
              provider.endTime == null ? "--:--" : provider.endTime!.format(context),
              Icons.access_time,
                  () => _pickTime(context, false),
            ),
            const SizedBox(height: 20),
            const Text("Notification Preference", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _buildNotificationDropdown(provider),
            const SizedBox(height: 20),
            _buildRepeatToggle(provider),
            if (provider.isRepeat) _buildFrequencySelector(provider),
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

// ... inside your Column in build()

// ... inside your Column in build()

// ... inside your Column in build()

            const Text("Selected Children", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),

            _buildComplianceNote(),
            const SizedBox(height: 10),

// --- UNIFIED ACTIONABLE LIST ---
            if (provider.appliedChildrenList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No children applied. Click 'Add New Child' to start.",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              )
            else
              ...provider.appliedChildrenList.asMap().entries.map((entry) {
                return _buildActionableChildCard(
                    context,
                    entry.value,
                    entry.key,
                    widget.caseId,
                    widget.category
                );
              }).toList(),

            const SizedBox(height: 15),

// ADD NEW CHILD BUTTON: Common for both modes
            _buildAddNewChildButton(context, provider),

            const SizedBox(height: 20),
            _buildEnableToggle(provider),
           const SizedBox(height: 30),
            _buildSaveButton(context, provider),
          ],
        ),
      ),
    );
  }

  // Card UI matching your uploaded image (Image_2fda5d.png)
  Widget _buildActionableChildCard(BuildContext context, Map<String, dynamic> childData, int index, String? caseId,  String category) {
    // Safe parsing of Timestamp
    DateTime dobDate = (childData['dob'] is Timestamp)
        ? (childData['dob'] as Timestamp).toDate()
        : DateTime.parse(childData['dob'].toString());

    String formattedDob = DateFormat('dd MMM yyyy').format(dobDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1F5FE)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFF3E5F5),
            child: Icon(Icons.person, color: Color(0xFF4A148C)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(childData['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(formattedDob, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.read<RuleConfigurationProvider>().removeChild(index, widget.caseId, widget.category),
            icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.notificationPref,
          isExpanded: true,
          items: ["On the Scheduled day", "One day before", "X days before", "Turn off notifications"]
              .map((val) => DropdownMenuItem(value: val, child: Text(val)))
              .toList(),
          onChanged: (val) => provider.setNotification(val!),
        ),
      ),
    );
  }

  Widget _buildRepeatToggle(RuleConfigurationProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Repeat Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Switch(value: provider.isRepeat, activeThumbColor: const Color(0xFF4A148C), onChanged: (v) => provider.toggleRepeat(v)),
      ],
    );
  }

  Widget _buildFrequencySelector(RuleConfigurationProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: ["Weekly", "Fortnightly", "Monthly"].map((freq) => Expanded(
          child: GestureDetector(
            onTap: () => provider.setFrequency(freq),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: provider.repeatFrequency == freq ? const Color(0xFFEDE7F6) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: provider.repeatFrequency == freq ? const Color(0xFF4A148C) : Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text(freq, style: TextStyle(color: provider.repeatFrequency == freq ? const Color(0xFF4A148C) : Colors.black, fontSize: 12)),
            ),
          ),
        )).toList(),
      ),
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
          if (provider.appliedChildrenList.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one child.")));
            return;
          }

          // 2. Validate End Time (Only if both times exist)
          if (provider.startTime != null && provider.endTime != null) {
            final startMinutes = provider.startTime!.hour * 60 + provider.startTime!.minute;
            final endMinutes = provider.endTime!.hour * 60 + provider.endTime!.minute;

            if (endMinutes <= startMinutes) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("End time must be after Start time.")),
              );
              return;
            }
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
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const CalenderScreen()),
                      (route) => false
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
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      final provider = context.read<RuleConfigurationProvider>();
      if (isStart) provider.updateStartTime(picked);
      else provider.updateEndTime(picked);
    }
  }
}