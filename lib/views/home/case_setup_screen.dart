import 'package:clearcase/core/theme/app_colors.dart';
import 'package:clearcase/core/utils/helping_functions.dart';
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/services/notification_service.dart';
import 'package:clearcase/views/auth/login_screen.dart';
import 'package:clearcase/views/widgets/custom_secondary_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../provider/case_setup_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/weekday_selector.dart';

// Geocoded current-address auto-fill, matching the Location field on the custody
// and payment record screens. Throws a user-facing string on failure; returns
// null if no placemark resolved.
Future<String?> _fetchCurrentAddress() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) throw 'Location services are disabled.';
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw 'Location permissions are denied.';
    }
  }
  if (permission == LocationPermission.deniedForever) {
    throw 'Location permissions are permanently denied.';
  }
  final position =
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  final placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);
  if (placemarks.isEmpty) return null;
  final place = placemarks.first;
  final parts = <String>[];
  if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
  if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
  if (place.country != null && place.country!.isNotEmpty) parts.add(place.country!);
  if (place.postalCode != null && place.postalCode!.isNotEmpty) parts.add(place.postalCode!);
  return parts.join(", ");
}

// Status line under the address field: a spinner while fetching, a tip when
// empty, or a clear action once filled — same affordance as the record screens.
Widget _addressAutofillHint({
  required bool loading,
  required TextEditingController controller,
  required VoidCallback onClear,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: loading
        ? const Row(children: [
            SizedBox(
              height: 12,
              width: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A148C)),
            ),
            SizedBox(width: 8),
            Text("Fetching current location...",
                style: TextStyle(fontSize: 12, color: Color(0xFF4A148C))),
          ])
        : controller.text.isEmpty
            ? const Text("Tip: Tap field to auto-fill current address",
                style: TextStyle(fontSize: 11, color: Colors.grey))
            : GestureDetector(
                onTap: onClear,
                child: const Text("Clear address",
                    style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
  );
}

class CaseSetupScreen extends StatefulWidget {
  static const routeName = '/case-setup';

  /// Non-null opens the wizard in edit mode for an existing case, prefilled with
  /// its details, children, and scheduled rules. Null creates a new case.
  final CaseModel? existingCase;

  const CaseSetupScreen({super.key, this.existingCase});

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

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await PushNotificationService.deleteTokenOnLogout();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
    }
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, LoginScreen.routeName, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isNewUser = !Navigator.canPop(context);
    final List<Widget>? appBarActions = isNewUser
        ? [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: "Logout",
              onPressed: () => _handleLogout(context),
            ),
          ]
        : null;
    return ChangeNotifierProvider(
      create: (_) {
        final provider = CaseSetupProvider();
        final existing = widget.existingCase;
        if (existing != null) {
          provider.loadExistingCase(existing);
          // Fire-and-forget is safe: loadExistingCase has already set
          // rulesLoaded false, and _buildCurrentStep gates Step 3 on it, so a
          // user who outruns this load waits rather than seeding a blank form.
          provider.loadExistingRules(existing.id);
        }
        return provider;
      },
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
                title: Text(provider.isEditing ? "Edit Case" : "Case Setup", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                actions: appBarActions,
              ): AppBar(
                title: Text(provider.isEditing ? "Edit Case" : "Case Setup", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.surfaceColor,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                actions: appBarActions,
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
        // _Step3ConfigureRule seeds its form once in initState from the case's
        // existing rule. Building it before an edit-mode rule load finishes
        // would seed blank, and saving that blank form would fully overwrite the
        // real rule (submitCase writes rules with batch.set, no merge). Hold the
        // subtree back — not just its contents — so initState cannot run early.
        // rulesLoaded is always true for a new case, so the create flow never
        // sees this spinner.
        if (!provider.rulesLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // The load finished but THREW. In edit mode we cannot tell whether this
        // case has a rule, and _Step3ConfigureRule would seed blank; saving that
        // blank form would fully overwrite the real rule (submitCase writes rules
        // with batch.set, no merge). Show the error and offer a retry instead of
        // the form — there is no Save button to press, so the clobber is
        // impossible rather than merely discouraged.
        // rulesLoadFailed is only ever set by an edit-mode load, so the create
        // flow never reaches this branch.
        if (provider.isEditing && provider.rulesLoadFailed) {
          return _RuleLoadErrorState(provider: provider);
        }
        return _Step3ConfigureRule(provider: provider);
      default:
        return const SizedBox();
    }
  }


  Widget _buildBottomBar(BuildContext context, CaseSetupProvider provider) {
    bool isStep2 = provider.currentStep == 2;

    // We disable interactions if either a general load OR a submission is happening
    bool isBusy = provider.isLoading || provider.isSubmitting;

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
              // Disable button if busy, but ONLY show loader if isLoading is true
              onPressed: isBusy ? null : () {
                if (provider.currentStep == 1) {
                  if (provider.caseData.caseNumber.isEmpty || provider.caseData.legalRep.isEmpty) {
                    showSnackBar(context, "All fields are required");
                    return;
                  }
                  if (provider.caseData.children.isEmpty) {
                    showSnackBar(context, "Add at least one child");
                    return;
                  }
                  // Both new-case and edit flows run the full wizard: Step 1 -> 2 -> 3.
                  provider.nextStep();
                  _scrollToTop();
                } else if (provider.currentStep == 2) {
                  if (provider.selectedRuleType == null) {
                    showSnackBar(context, "Please select a rule type");
                    return;
                  }
                  provider.nextStep();
                  _scrollToTop();
                }
              },
              child: provider.isLoading
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
                  : const Text("Continue",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          if (isStep2) ...[
            const SizedBox(height: 12),
            // If submitting (skipping), show a small loader here instead of on the main button
            provider.isSubmitting
                ? const Center(
                child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B1FA2))
                )
            )
                : CustomSecondaryButton(
              text: "Skip Rules For Now",
              onPressed: () => provider.submitCase(context),
            ),
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
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  FocusNode caseNumNode = FocusNode();
  FocusNode legalRepNode = FocusNode();
  FocusNode nameNode = FocusNode();
  FocusNode schoolNode = FocusNode();
  FocusNode addressNode = FocusNode();
  bool _addressLoading = false;

  DateTime? _selectedDate;
  @override
  void initState() {
    super.initState();
    _caseNumCtrl = TextEditingController(text: widget.provider.caseData.caseNumber);
    _legalRepCtrl = TextEditingController(text: widget.provider.caseData.legalRep);
  }
  @override
  void dispose() {
    _caseNumCtrl.dispose();
    _legalRepCtrl.dispose();
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _addressCtrl.dispose();
    schoolNode.dispose();
    addressNode.dispose();
    super.dispose();
  }

  Future<void> _autofillAddress() async {
    setState(() => _addressLoading = true);
    try {
      final addr = await _fetchCurrentAddress();
      if (!mounted) return;
      if (addr != null) setState(() => _addressCtrl.text = addr);
    } catch (e) {
      if (mounted) showSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _addressLoading = false);
    }
  }
  void _addChild() {
    if (_nameCtrl.text.trim().isEmpty || _selectedDate == null) {
      showSnackBar(context, "Enter Child Name and DOB");
      return;
    }
    widget.provider.addChild(
      _nameCtrl.text,
      _selectedDate!,
      school: _emptyToNull(_schoolCtrl.text),
      address: _emptyToNull(_addressCtrl.text),
    );
    _nameCtrl.clear();
    _schoolCtrl.clear();
    _addressCtrl.clear();
    setState(() => _selectedDate = null);
    FocusScope.of(context).unfocus();
  }

  // Blank input means "not provided" — keep it null so the report shows "—"
  // rather than an empty row.
  static String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();
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
        ...widget.provider.caseData.children.map((c) => Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                onTap: () => _showEditChildDialog(c),
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade50,
                  child: const Icon(Icons.person, color: Colors.purple),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_childSubtitle(c)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Visible affordance for the tile's existing onTap edit.
                    IconButton(
                      icon: Icon(Icons.edit, color: AppColors.primary),
                      tooltip: "Edit child",
                      onPressed: () => _showEditChildDialog(c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: "Remove child",
                      onPressed: () => widget.provider.removeChild(c.id),
                    ),
                  ],
                ),
              ),
            )),
        const Divider(height: 30),],
        CustomTextField(labelText: "Child Name", hintText: "Enter name", controller: _nameCtrl, node: nameNode, nextNode: schoolNode),
        const SizedBox(height: 10),
        Text("Date of Birth", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 5),
        InkWell(onTap: () async { 
          final d = await showDatePicker(context: context, initialDate: DateTime.now(), 
          firstDate: DateTime(2000), lastDate: DateTime.now()); if (d != null) setState(() => _selectedDate = d); }, 
          child: Container(height: 54, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), 
          decoration: BoxDecoration(color: AppColors.textFieldBackgroundColor), 
          child: Row(children: [
            Text(_selectedDate == null ? "Select Date of Birth" : DateFormat('d MMM yyyy').format(_selectedDate!),
            style: TextStyle(color: _selectedDate == null ? AppColors.greyColor : Colors.black)), const Spacer(),
             const Icon(Icons.calendar_today, color: AppColors.greyColor)]),),),
        const SizedBox(height: 15),
        CustomTextField(labelText: "School", hintText: "eg. Springfield Primary", controller: _schoolCtrl, node: schoolNode, nextNode: addressNode),
        const SizedBox(height: 15),
        CustomTextField(
          labelText: "Address",
          hintText: "Tap to auto-fill or type manually",
          controller: _addressCtrl,
          node: addressNode,
          onTap: () {
            if (_addressCtrl.text.isEmpty && !_addressLoading) _autofillAddress();
          },
        ),
        _addressAutofillHint(
          loading: _addressLoading,
          controller: _addressCtrl,
          onClear: () => setState(() => _addressCtrl.clear()),
        ),
        const SizedBox(height: 16),
        CustomSecondaryButton(text: 'Add New Child', onPressed: _addChild ),
      ],
    );
  }

  // DOB, plus school and address when present. A child with neither reads
  // exactly as it did before these fields existed.
  String _childSubtitle(ChildModel c) {
    final parts = <String>[DateFormat('d MMM yyyy').format(c.dob)];
    if (c.school != null && c.school!.trim().isNotEmpty) parts.add(c.school!.trim());
    if (c.address != null && c.address!.trim().isNotEmpty) parts.add(c.address!.trim());
    return parts.join(' · ');
  }

  // Editing must preserve the child's id — see CaseSetupProvider.updateChild.
  void _showEditChildDialog(ChildModel child) {
    showDialog(
      context: context,
      builder: (ctx) => _EditChildDialog(
        child: child,
        onSave: (name, dob, school, address) {
          widget.provider.updateChild(
            child.id,
            name: name,
            dob: dob,
            school: school,
            address: address,
          );
        },
      ),
    );
  }
}

// Owns its own controllers and focus nodes so they're disposed when the dialog
// closes — CustomTextField does not take ownership of externally-supplied nodes.
class _EditChildDialog extends StatefulWidget {
  final ChildModel child;
  final void Function(String name, DateTime dob, String? school, String? address) onSave;
  const _EditChildDialog({required this.child, required this.onSave});

  @override
  State<_EditChildDialog> createState() => _EditChildDialogState();
}

class _EditChildDialogState extends State<_EditChildDialog> {
  late final TextEditingController _nameC;
  late final TextEditingController _schoolC;
  late final TextEditingController _addressC;
  final FocusNode _nameNode = FocusNode();
  final FocusNode _schoolNode = FocusNode();
  final FocusNode _addressNode = FocusNode();
  late DateTime _dob;
  bool _addressLoading = false;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.child.name);
    _schoolC = TextEditingController(text: widget.child.school ?? '');
    _addressC = TextEditingController(text: widget.child.address ?? '');
    _dob = widget.child.dob;
  }

  Future<void> _autofillAddress() async {
    setState(() => _addressLoading = true);
    try {
      final addr = await _fetchCurrentAddress();
      if (!mounted) return;
      if (addr != null) setState(() => _addressC.text = addr);
    } catch (e) {
      if (mounted) showSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _addressLoading = false);
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _schoolC.dispose();
    _addressC.dispose();
    _nameNode.dispose();
    _schoolNode.dispose();
    _addressNode.dispose();
    super.dispose();
  }

  static String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Edit Child", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(labelText: "Child Name", controller: _nameC, node: _nameNode),
            const SizedBox(height: 12),
            Text("Date of Birth",
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 5),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dob,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _dob = d);
              },
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(color: AppColors.textFieldBackgroundColor),
                child: Row(children: [
                  Text(DateFormat('d MMM yyyy').format(_dob)),
                  const Spacer(),
                  const Icon(Icons.calendar_today, color: AppColors.greyColor),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            CustomTextField(labelText: "School", controller: _schoolC, node: _schoolNode),
            const SizedBox(height: 12),
            CustomTextField(
              labelText: "Address",
              hintText: "Tap to auto-fill or type manually",
              controller: _addressC,
              node: _addressNode,
              onTap: () {
                if (_addressC.text.isEmpty && !_addressLoading) _autofillAddress();
              },
            ),
            _addressAutofillHint(
              loading: _addressLoading,
              controller: _addressC,
              onClear: () => setState(() => _addressC.clear()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.black)),
        ),
        TextButton(
          onPressed: () {
            if (_nameC.text.trim().isEmpty) {
              showSnackBar(context, "Enter Child Name");
              return;
            }
            widget.onSave(
              _nameC.text.trim(),
              _dob,
              _emptyToNull(_schoolC.text),
              _emptyToNull(_addressC.text),
            );
            Navigator.pop(context);
          },
          child: const Text("Save", style: TextStyle(color: Color(0xFF4A148C))),
        ),
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

/// Shown in place of Step 3 when an edit-mode rule load failed. Deliberately has
/// no Save affordance: with the case's existing rule unknown, any save would
/// write a blank rule over it.
class _RuleLoadErrorState extends StatelessWidget {
  final CaseSetupProvider provider;
  const _RuleLoadErrorState({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            "Couldn't load this case's schedule",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "We couldn't reach the server, so this case's existing rule can't be "
            "shown. Saving now could overwrite it, so editing is disabled until "
            "the schedule loads. Check your connection and try again.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: () => provider.retryLoadExistingRules(),
              child: const Text("Retry",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          CustomSecondaryButton(
            text: "Back",
            onPressed: () => provider.previousStep(),
          ),
        ],
      ),
    );
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
  bool hasEndDate = false; // By default, it is OFF (Indefinite)
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String notificationPref = "On the Scheduled day";
  bool isRepeat = true;
  Set<String> selectedChildIds = {};

  final List<String> notifOptions = ["On the Scheduled day", "1 Day Before", "7 Days Before", "Turn Off Notifications"];




   String selectedFrequency = "Weekly";

  final List<String> frequencyOptions = ["Weekly", "Fortnightly", "Monthly", "Custom"];

  // Selected weekdays for the "Custom" frequency (DateTime.weekday: Mon=1..Sun=7)
  Set<int> selectedDays = {};
  @override
  void initState() {
    super.initState();
    selectedChildIds = widget.provider.caseData.children.map((e) => e.id).toSet();

    // In edit mode, seed the form from the case's existing rule for this category
    // so a wizard re-run edits the current config instead of overwriting it from
    // blank. Null (no rule for this category yet) falls through to the defaults.
    final existingRule = widget.provider.isEditing
        ? widget.provider.existingRuleFor(widget.provider.selectedRuleType ?? '')
        : null;
    if (existingRule != null) {
      _seedFromExistingRule(existingRule);
    }
  }

  /// Inverts the `ruleData` map built by [_onSaveRule] back into form state.
  /// Every key read here is one written there — keep the two in sync.
  void _seedFromExistingRule(Map<String, dynamic> rule) {
    // "startDate" / "endDate" are written as ISO-8601 strings.
    startDate = _parseDate(rule['startDate']);
    endDate = _parseDate(rule['endDate']);

    // "startTime" / "endTime" are written as "HH:mm" (null when not applicable).
    startTime = _parseTime(rule['startTime']);
    endTime = _parseTime(rule['endTime']);

    // "notificationPref" feeds a DropdownButton whose value must match exactly
    // one item, so an unrecognised stored value has to fall back to the default.
    final pref = rule['notificationPref'];
    if (pref is String && notifOptions.contains(pref)) {
      notificationPref = pref;
    }

    // "repeatFrequency" is null exactly when the rule was saved non-recurring,
    // which is what the isRepeat toggle encodes.
    final freq = rule['repeatFrequency'];
    isRepeat = freq != null;
    if (freq is String && frequencyOptions.contains(freq)) {
      selectedFrequency = freq;
    }

    // "customDays" is only written for a recurring "Custom" rule; it round-trips
    // as a List of weekday ints (Mon=1..Sun=7).
    final days = rule['customDays'];
    if (days is List) {
      selectedDays = days.whereType<num>().map((d) => d.toInt()).toSet();
    }

    // A recurring rule only carries an endDate when the "Add End Date" toggle
    // was on, so the presence of one reconstructs the toggle.
    hasEndDate = isRepeat && endDate != null;

    // "notes" is written from the controller's raw text.
    final notes = rule['notes'];
    if (notes is String) _notesController.text = notes;

    // "appliedChildren" holds full ChildModel.toMap() entries; we only need the
    // ids back. Children deleted from the case since the rule was saved are
    // dropped, and an empty result keeps the default (all children) rather than
    // leaving a selection that _onSaveRule would reject.
    final applied = rule['appliedChildren'];
    if (applied is List) {
      final currentIds =
          widget.provider.caseData.children.map((e) => e.id).toSet();
      final appliedIds = applied
          .whereType<Map>()
          .map((m) => m['id'])
          .whereType<String>()
          .where(currentIds.contains)
          .toSet();
      if (appliedIds.isNotEmpty) selectedChildIds = appliedIds;
    }
  }

  DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  TimeOfDay? _parseTime(dynamic value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _onSaveRule() async {
    if (startDate == null || startTime == null) {
      showSnackBar(context, "Start Date and Time required");
      return;
    }

    // 2. Conditional Validation
    if (!isRepeat) {
      // ONE-TIME RULE: End Date/Time are MANDATORY
      if (endDate == null || endTime == null) {
        showSnackBar(context, "End Date and Time are required for non-recurring rules");
        return;
      }
    } else {
      // RECURRING RULE: Check Days and Toggle

      // Custom frequency requires at least one weekday
      if (selectedFrequency == "Custom" && selectedDays.isEmpty) {
        showSnackBar(context, "Please select at least one day of the week");
        return;
      }

      if (hasEndDate && (endDate == null || endTime == null)) {
        showSnackBar(context, "Please select an end date and time or turn off the toggle");
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
      "startTime": "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}",

      // Logic: Only send end date if it's non-repeat OR (repeat is ON and toggle is ON)
      "endDate": (!isRepeat || hasEndDate) ? endDate?.toIso8601String() : null,

      // Logic: If repeat is off, we need end time. If repeat is on and hasEndDate is on, we usually use the startTime as the "event end time" for daily logic, but sending endTime here if you have it.
      "endTime": (!isRepeat || hasEndDate) && endTime != null
          ? "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}"
          : null,

      "notificationPref": notificationPref,
       "repeatFrequency": isRepeat ? selectedFrequency : null,
      "customDays": (isRepeat && selectedFrequency == "Custom")
          ? selectedDays.toList()
          : null,
      "notes": _notesController.text,
      "appliedChildren": childrenData,
    };
    // 5. Submit
    widget.provider.setRuleConfiguration(ruleData);
    widget.provider.submitCase(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Rule Saved Successfully!"),
         ),
      );

      _resetForm();
    }
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


  void _resetForm() {
    setState(() {
      _notesController.clear();
      startDate = null;
      endDate = null;
      startTime = null;
      endTime = null;
      selectedFrequency = "Weekly";
      selectedDays = {};
      isRepeat = true;
      hasEndDate = false;
      selectedChildIds = widget.provider.caseData.children.map((e) => e.id).toSet();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Start Date
        _buildFieldLabel("Rule Start Date"),
        _buildInputContainer(
          text: startDate == null ? "--/--/----" : DateFormat('d MMM yyyy').format(startDate!),
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
          const Text("Repeat Frequency", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),

          // Frequency Selection Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.5,
            ),
            itemCount: frequencyOptions.length,
            itemBuilder: (context, index) {
              final option = frequencyOptions[index];
              bool isSelected = selectedFrequency == option;

              return GestureDetector(
                onTap: () => setState(() => selectedFrequency = option),
                child: Container(
                  decoration: BoxDecoration(
                    // Blue-ish background for selected as per your image
                    color: isSelected ? const Color(0xFFE1F5FE) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : const Color(0xFF7B1FA2),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option,
                    style: TextStyle(
                      color: const Color(0xFF4A148C),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),

          // Weekday picker (only for "Custom" frequency)
          if (selectedFrequency == "Custom") ...[
            const SizedBox(height: 16),
            const Text("Repeat On", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            const Text("Select one or more days of the week",
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 12),
            WeekdaySelector(
              selectedDays: selectedDays,
              onToggle: (weekday) => setState(() {
                if (selectedDays.contains(weekday)) {
                  selectedDays.remove(weekday);
                } else {
                  selectedDays.add(weekday);
                }
              }),
            ),
          ],

          const SizedBox(height: 20),

          // NEW: Add End Date Toggle (Only shows if isRepeat is TRUE)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Add End Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 2),
                    Text("Set a specific end date for this recurring rule", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: hasEndDate,
                activeTrackColor: const Color(0xFF4A148C),
                onChanged: (v) => setState(() => hasEndDate = v),
              ),
            ],
          ),

          // Conditional End Date/Time for Recurring Rule
          if (hasEndDate) ...[
            const SizedBox(height: 15),
            _buildFieldLabel("Rule End Date"),
            _buildInputContainer(
                text: endDate == null ? "--/--/----" : DateFormat('d MMM yyyy').format(endDate!),
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
        ] else ...[
          // If NOT repeating, End Date and Time are ALWAYS shown and REQUIRED
          _buildFieldLabel("Rule End Date"),
          _buildInputContainer(
              text: endDate == null ? "--/--/----" : DateFormat('d MMM yyyy').format(endDate!),
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
            DateFormat('d MMM yyyy').format(c.dob),
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