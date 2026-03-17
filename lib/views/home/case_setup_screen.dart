import 'package:clearcase/core/theme/app_colors.dart';
import 'package:clearcase/core/utils/helping_functions.dart';
import 'package:clearcase/views/widgets/custom_secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:provider/provider.dart';
import '../../provider/case_setup_provider.dart';
import '../widgets/custom_text_field.dart';
class CaseSetupScreen extends StatefulWidget {
  static const routeName = '/case-setup';
  const CaseSetupScreen({super.key});

  @override
  State<CaseSetupScreen> createState() => _CaseSetupScreenState();
}

class _CaseSetupScreenState extends State<CaseSetupScreen> {
  // 1. Create the controller
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 2. Helper to jump to top
  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CaseSetupProvider(),
      child: Consumer<CaseSetupProvider>(
        builder: (context, provider, child) {
          return PopScope(
            canPop: provider.currentStep == 1,
            onPopInvokedWithResult: (didPop, res) {
              if (didPop) return;
              provider.previousStep();
            },
            child: Scaffold(
              backgroundColor: AppColors.surfaceColor, 
              appBar: provider.currentStep>1 ? AppBar(
                title: const Text("Case Setup", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.surfaceColor,
                scrolledUnderElevation: 0, 
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: provider.currentStep > 1 ? Colors.black : Colors.grey),
                  onPressed: () {
                    if (provider.currentStep > 1) {
                      provider.previousStep();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ): AppBar(
                title: const Text("Case Setup", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.surfaceColor,
                scrolledUnderElevation: 0, 
                surfaceTintColor: Colors.transparent,
                elevation: 0,
              ),
              body: Column(
                children: [
                  _buildProgressHeader(provider.currentStep),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController, // <--- CRITICAL: YOU MISSED THIS
                      padding: const EdgeInsets.all(20),
                      child: _buildCurrentStep(context, provider),
                    ),
                  ),
                  if (provider.currentStep != 3) 
                    _buildBottomBar(context, provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader(int step) {
    String stepTitle = "Professional case configuration for compliance tracking.";
    String headerTitle = "Step $step of 3";
    String subHeader = "";

    if (step == 2) {
      stepTitle = "Choose the type of scheduled rule you want to create.\nThis selection is required for accurate compliance calculation and legal documentation.";
      subHeader = "Select Rule Type";
    }
    if (step == 3) {
      stepTitle = "Professional case configuration for compliance tracking.";
      subHeader = "Schedule Configuration";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(headerTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (subHeader.isNotEmpty) 
                Text(subHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Container(height: 4, color: const Color(0xFF7B1FA2))), 
              const SizedBox(width: 5),
              Expanded(child: Container(height: 4, color: step >= 2 ? const Color(0xFF7B1FA2) : Colors.grey[300])), 
              const SizedBox(width: 5),
              Expanded(child: Container(height: 4, color: step >= 3 ? const Color(0xFF7B1FA2) : Colors.grey[300])), 
            ],
          ),
          const SizedBox(height: 8),
          Text(stepTitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context, CaseSetupProvider provider) {
    switch (provider.currentStep) {
      case 1:
        return _Step1Form(provider: provider);
      case 2:
        return _Step2SelectRule(provider: provider);
      case 3:
        return _Step3ConfigureRule(provider: provider);
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar(BuildContext context, CaseSetupProvider provider) {
    bool isStep2 = provider.currentStep == 2;
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: provider.isLoading ? null : () {
                if (provider.currentStep == 1) {
                  if (provider.caseData.caseNumber.isEmpty || provider.caseData.legalRep.isEmpty) {
                    showSnackBar(context, "All fields are required");
                    return;
                  }
                  if (provider.caseData.children.isEmpty) {
                    showSnackBar(context, "Add at least one child");
                    return;
                  }
                  provider.nextStep();
                  _scrollToTop(); // <--- Add this
                } else if (provider.currentStep == 2) {
                   if (provider.selectedRuleType == null) {
                      showSnackBar(context, "Please select a rule type");
                      return;
                   }
                   provider.nextStep();
                   _scrollToTop(); // <--- Add this
                }
              },
              child: provider.isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Continue", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          if (isStep2) ...[
            const SizedBox(height: 12),
            CustomSecondaryButton(text: "Skip Rules For Now", onPressed: () => provider.submitCase(context)),
          ]
        ],
      ),
    );
  }
}

class _Step1Form extends StatefulWidget {
  final CaseSetupProvider provider;
  const _Step1Form({required this.provider});
  @override
  State<_Step1Form> createState() => _Step1FormState();
}
class _Step1FormState extends State<_Step1Form> {
  late TextEditingController _caseNumCtrl;
  late TextEditingController _legalRepCtrl;
  final TextEditingController _nameCtrl = TextEditingController();
  FocusNode caseNumNode = FocusNode();
  FocusNode legalRepNode = FocusNode();
  FocusNode nameNode = FocusNode();

  DateTime? _selectedDate;
  @override
  void initState() {
    super.initState();
    _caseNumCtrl = TextEditingController(text: widget.provider.caseData.caseNumber);
    _legalRepCtrl = TextEditingController(text: widget.provider.caseData.legalRep);
  }
  @override
  void dispose() {
    _caseNumCtrl.dispose(); _legalRepCtrl.dispose(); _nameCtrl.dispose(); super.dispose();
  }
  void _addChild() {
    if (_nameCtrl.text.trim().isEmpty || _selectedDate == null) {
      showSnackBar(context, "Enter Child Name and DOB");
      return;
    }
    widget.provider.addChild(_nameCtrl.text, _selectedDate!);
    _nameCtrl.clear();
    setState(() => _selectedDate = null);
    FocusScope.of(context).unfocus();
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Case Information", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 15),
        CustomTextField(labelText: "Case Number *", hintText: "eg. FAMS-5856", controller: _caseNumCtrl, node: caseNumNode, nextNode: legalRepNode, onChange: (v) => widget.provider.updateCaseInfo(v, _legalRepCtrl.text)),
        const SizedBox(height: 15),
        CustomTextField(labelText: "Legal Representative *", hintText: "eg. Sam Mark", controller: _legalRepCtrl, node: legalRepNode, nextNode: nameNode, onChange: (v) => widget.provider.updateCaseInfo(_caseNumCtrl.text, v)),
        const SizedBox(height: 25),
        if (widget.provider.caseData.children.isNotEmpty) ...[
        const Text("Children", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        ...widget.provider.caseData.children.map((c) => 
        Card(elevation: 0, 
        color: Colors.white, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.grey.shade200)), 
        child: ListTile(visualDensity: VisualDensity.compact,contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), leading: CircleAvatar(backgroundColor: Colors.purple.shade50, 
        child: const Icon(Icons.person, color: Colors.purple)), 
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
        subtitle: Text(DateFormat('dd MMM yyyy').format(c.dob)),
         trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), 
         onPressed: () => widget.provider.removeChild(c.id)),),)),
        const Divider(height: 30),],
        CustomTextField(labelText: "Child Name", hintText: "Enter name", controller: _nameCtrl, node: nameNode),
        const SizedBox(height: 10),
        Text("Date of Birth", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 5),
        InkWell(onTap: () async { 
          final d = await showDatePicker(context: context, initialDate: DateTime.now(), 
          firstDate: DateTime(2000), lastDate: DateTime.now()); if (d != null) setState(() => _selectedDate = d); }, 
          child: Container(height: 54, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), 
          decoration: BoxDecoration(color: AppColors.textFieldBackgroundColor), 
          child: Row(children: [
            Text(_selectedDate == null ? "Select Date of Birth" : DateFormat('dd MMM yyyy').format(_selectedDate!), 
            style: TextStyle(color: _selectedDate == null ? AppColors.greyColor : Colors.black)), const Spacer(),
             const Icon(Icons.calendar_today, color: AppColors.greyColor)]),),),
        const SizedBox(height: 16),
        CustomSecondaryButton(text: 'Add New Child', onPressed: _addChild ),
      ],
    );
  }
}

class _Step2SelectRule extends StatelessWidget {
  final CaseSetupProvider provider;
  const _Step2SelectRule({required this.provider});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         const SizedBox(height: 8),
        _buildSelectionCard("Scheduled Custody", "Set up recurring custody schedules, handover times, and parenting arrangements as defined in court orders.", ["Court-ordered", "Time-sensitive", "Compliance Tracking"], "Custody", provider),
        _buildSelectionCard("Scheduled Payments", "Configure recurring child support payments, medical expenses, education costs, and other financial obligations.", ["Financial", "Recurring", "Payment tracking"], "Payment", provider, tagColor: Colors.blue.shade100, tagTextColor: Colors.blue.shade900),
        _buildSelectionCard("Custom Order", "Create custom rules for communication schedules, special events, medical appointments, or other specific requirements.", ["Flexible", "Customizable", "Multi-purpose"], "Custom", provider, tagColor: Colors.green.shade100, tagTextColor: Colors.green.shade900),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)), child: Column(children: const [Text("Rule Type Required", style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 5), Text("Selecting a rule type is mandatory for compliance calculation. This ensures accurate tracking and proper categorization for legal documentation purposes.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black87))]))
    ]);
  }
  Widget _buildSelectionCard(String title, String desc, List<String> tags, String type, CaseSetupProvider provider, {Color? tagColor, Color? tagTextColor}) {
    bool isSelected = provider.selectedRuleType == type;
    return GestureDetector(
      onTap: () => provider.selectRuleType(type), 
      child: Container(margin: const EdgeInsets.only(bottom: 12), 
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), 
      border: Border.all(color: isSelected ? const Color(0xFF7B1FA2) : Colors.transparent, width: 2), 
      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]), 
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, 
      children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
      const SizedBox(height: 5), Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black54)),
       const SizedBox(height: 10), Wrap(spacing: 6, runSpacing: 6, children: tags.map((t) => 
       Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: tagColor ?? const Color(0xFFFFE0B2), 
        borderRadius: BorderRadius.circular(12)), 
        child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagTextColor ?? const Color(0xFFE65100))))).toList())])));
  }
}

class _Step3ConfigureRule extends StatefulWidget {
  final CaseSetupProvider provider;
  const _Step3ConfigureRule({required this.provider});

  @override
  State<_Step3ConfigureRule> createState() => _Step3ConfigureRuleState();
}

class _Step3ConfigureRuleState extends State<_Step3ConfigureRule> {
  final _notesController = TextEditingController();
  
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String notificationPref = "On the Scheduled day";
  bool isRepeat = true;
  String repeatFrequency = "Indefinitely";
  Set<String> selectedChildIds = {};

  final List<String> notifOptions = ["On the Scheduled day", "1 Day Before", "7 Days Before", "Turn Off Notifications"];

  @override
  void initState() {
    super.initState();
    selectedChildIds = widget.provider.caseData.children.map((e) => e.id).toSet();
  }

  void _onSaveRule() {
    // 1. Basic Null Checks (Always required)
    if (startDate == null || startTime == null) {
      showSnackBar(context, "Start Date and Time required");
      return;
    }

    // 2. Conditional Validation
    if (!isRepeat) {
      // If NOT repeating, End Date and End Time are now mandatory
      if (endDate == null || endTime == null) {
        showSnackBar(context, "End Date and Time are required for non-recurring rules");
        return;
      }
     }

    // 3. Child Selection Check
    if (selectedChildIds.isEmpty) {
      showSnackBar(context, "Please apply this rule to at least one child.");
      return;
    }

    // 4. Data Preparation
    List<Map<String, dynamic>> childrenData = widget.provider.caseData.children
        .where((c) => selectedChildIds.contains(c.id))
        .map((c) => c.toMap())
        .toList();

    Map<String, dynamic> ruleData = {
      "startDate": startDate!.toIso8601String(),
      "startTime": "${startTime!.hour}:${startTime!.minute}",
      // If repeating, we typically don't send end dates unless it's a "repeat until" logic
      "endDate": !isRepeat ? endDate?.toIso8601String() : null,
      "endTime": !isRepeat && endTime != null ? "${endTime!.hour}:${endTime!.minute}" : null,
      "notificationPref": notificationPref,
      "isRepeat": isRepeat,
      "frequency": isRepeat ? repeatFrequency : null,
      "notes": _notesController.text,
      "appliedChildren": childrenData,
    };

    // 5. Submit
    widget.provider.setRuleConfiguration(ruleData);
    widget.provider.submitCase(context);
  }

  // Pickers
  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();

    // If picking End Date, the earliest possible date is the Start Date (or now)
    DateTime firstAllowedDate = (isStart || startDate == null) ? DateTime(2000) : startDate!;

    final d = await showDatePicker(
        context: context,
        initialDate: (isStart) ? (startDate ?? now) : (endDate ?? firstAllowedDate),
        firstDate: (isStart) ? DateTime(2000) : firstAllowedDate,
        lastDate: DateTime(2100)
    );

    if (d != null) {
      setState(() {
        if (isStart) {
          startDate = d;
          // If the current end date is now before the new start date, reset or update it
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = startDate;
          }
        } else {
          endDate = d;
        }
      });
    }
  }
  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (t != null) setState(() => isStart ? startTime = t : endTime = t);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Start Date
        _buildFieldLabel("Rule Start Date"),
        _buildInputContainer(
          text: startDate == null ? "--/--/----" : DateFormat('dd/MM/yyyy').format(startDate!),
          icon: Icons.calendar_today_outlined,
          onTap: () => _pickDate(true)
        ),

        const SizedBox(height: 15),

        // 2. Start Time
        _buildFieldLabel("Start Time"),
        _buildInputContainer(
          text: startTime == null ? "00 : 00" : startTime!.format(context),
          icon: Icons.access_time,
          onTap: () => _pickTime(true)
        ),

        const SizedBox(height: 15),

        // 2. Repeat Schedule Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Repeat Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 2),
                Text("Enable recurring schedule patterns", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            Switch(
              value: isRepeat,
              activeTrackColor: const Color(0xFF4A148C),
              activeThumbColor: Colors.white,
              onChanged: (v) => setState(() => isRepeat = v),
            ),
          ],
        ),

        const SizedBox(height: 15),

        // 3. Conditional UI based on Toggle
        if (isRepeat) ...[
          // Show 4 Options (Frequency) when Toggle is ON
          Row(
            children: ["Indefinitely", "Fortnightly", "Monthly", "Weekly"].map((freq) {
              bool isSelected = repeatFrequency == freq;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => repeatFrequency = freq),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF7B1FA2), width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                        freq,
                        style: TextStyle(
                            color: const Color(0xFF7B1FA2),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12
                        )
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ] else ...[
          // Show End Date and End Time when Toggle is OFF
          _buildFieldLabel("Rule End Date"),
          _buildInputContainer(
              text: endDate == null ? "--/--/----" : DateFormat('dd/MM/yyyy').format(endDate!),
              icon: Icons.calendar_today_outlined,
              onTap: () => _pickDate(false)
          ),

          const SizedBox(height: 15),

          _buildFieldLabel("End Time"),
          _buildInputContainer(
              text: endTime == null ? "00 : 00" : endTime!.format(context),
              icon: Icons.access_time,
              onTap: () => _pickTime(false)
          ),
        ],
          const SizedBox(height: 15),
        // 5. Notification Preference
        _buildFieldLabel("Notification Preference"),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.transparent), // Flat white look
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: notificationPref,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: notifOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => notificationPref = v!),
            ),
          ),
        ),

        const SizedBox(height: 15),

        // 8. Notes
        _buildFieldLabel("Notes(Optional)"),
        Container(
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              hintText: "Enter Any Additional Details",
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey)
            ),
          ),
        ),

        const SizedBox(height: 25),

        // 9. Apply Rule to Children
        const Text("Apply Rule to Children", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),

        // Grey Info Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12)
          ),
          child: Column(
            children: const [
              Text("Compliance Calculation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 5),
              Text(
                "Compliance is calculated per child. Select which children this rule applies to for accurate tracking and legal documentation.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black87)
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        // Select All Item
        _buildChildItem(
          "Select All", 
          null, 
          selectedChildIds.length == widget.provider.caseData.children.length && widget.provider.caseData.children.isNotEmpty,
          () {
            setState(() {
              if (selectedChildIds.length == widget.provider.caseData.children.length) {
                selectedChildIds.clear();
              } else {
                selectedChildIds = widget.provider.caseData.children.map((e) => e.id).toSet();
              }
            });
          }
        ),

        // Child List
        ...widget.provider.caseData.children.map((c) => 
          _buildChildItem(
            c.name, 
            DateFormat('dd MMM yyyy').format(c.dob), 
            selectedChildIds.contains(c.id),
            () {
              setState(() {
                 selectedChildIds.contains(c.id) 
                   ? selectedChildIds.remove(c.id) 
                   : selectedChildIds.add(c.id);
              });
            }
          )
        ),

        const SizedBox(height: 30),

        // 10. Save Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            onPressed: widget.provider.isLoading ? null : _onSaveRule,
            child: widget.provider.isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Save Rule", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // --- Widgets Helpers ---

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildInputContainer({required String text, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[200], // Grey background like SS
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            Icon(icon, size: 18, color: Colors.purple), // Purple icon? Or black in SS? Looks slightly dark/purple.
          ],
        ),
      ),
    );
  }

  Widget _buildChildItem(String title, String? subtitle, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent), // Flat white card
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: subtitle == null 
           ? null // No avatar for Select All
           : CircleAvatar(
               backgroundColor: const Color(0xFFFFCDD2), // Pink bg
               child: const Icon(Icons.person, color: Color(0xFF7B1FA2)), // Purple user
             ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
        // Using Icon instead of Radio to control visual state manually without groupValue mess for "Select All"
        trailing: isSelected 
            ? const Icon(Icons.radio_button_checked, color: Color(0xFF7B1FA2)) 
            : const Icon(Icons.radio_button_off, color: Color(0xFF7B1FA2)),
      ),
    );
  }
}