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
import '../../models/remainder_model.dart';
import '../../provider/case_setup_provider.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/reminder_tag_picker.dart';
import 'new_remainder_screen.dart';

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
        if (existing != null) provider.loadExistingCase(existing);
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
                  _buildProgressHeader(provider),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController, // <--- CRITICAL: YOU MISSED THIS
                      padding: const EdgeInsets.all(20),
                      child: _buildCurrentStep(context, provider),
                    ),
                  ),
                  _buildBottomBar(context, provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader(CaseSetupProvider provider) {
    final step = provider.currentStep;
    String stepTitle = "Set up your case, children and related party.";
    String headerTitle = "Step $step of ${provider.stepCount}";
    String subHeader = "";

    if (provider.isEditing) {
      headerTitle = "Case details";
      stepTitle = "Update your case, children and related party.";
    } else if (step == 2) {
      stepTitle = "Optional: set up repeated reminders for custody and payments. You can skip this and add reminders any time.";
      subHeader = "Reminders";
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
          if (provider.stepCount > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 1; i <= provider.stepCount; i++) ...[
                  if (i > 1) const SizedBox(width: 5),
                  Expanded(child: Container(height: 4, color: step >= i ? const Color(0xFF7B1FA2) : Colors.grey[300])),
                ],
              ],
            ),
          ],
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
        return _Step2Reminders(provider: provider);
      default:
        return const SizedBox();
    }
  }

  // Step 1 must name the case and at least one child, and the related party is
  // all-or-nothing (the forms only offer a saved party with both parts).
  bool _validateStep1(BuildContext context, CaseSetupProvider provider) {
    final c = provider.caseData;
    if (c.caseNumber.isEmpty || c.legalRep.isEmpty) {
      showSnackBar(context, "All fields are required");
      return false;
    }
    if (c.children.isEmpty) {
      showSnackBar(context, "Add at least one child");
      return false;
    }
    final hasRelation = (c.relatedPartyRelation ?? '').isNotEmpty;
    final hasName = (c.relatedPartyName ?? '').isNotEmpty;
    if (hasName && !hasRelation) {
      showSnackBar(context, "Select the related party's relationship");
      return false;
    }
    if (hasRelation && !hasName) {
      showSnackBar(context, "Enter the related party's name");
      return false;
    }
    return true;
  }

  Widget _buildBottomBar(BuildContext context, CaseSetupProvider provider) {
    final isLastStep = provider.currentStep == provider.stepCount;
    final isBusy = provider.isLoading || provider.isSubmitting;

    final String label;
    if (provider.isEditing) {
      label = "Save Changes";
    } else if (isLastStep) {
      label = "Finish Setup";
    } else {
      label = "Continue";
    }

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
              onPressed: isBusy ? null : () {
                if (provider.currentStep == 1 && !_validateStep1(context, provider)) return;
                if (isLastStep) {
                  provider.submitCase(context);
                } else {
                  provider.nextStep();
                  _scrollToTop();
                }
              },
              child: provider.isSubmitting
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
                  : Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          if (!provider.isEditing && provider.currentStep == 2) ...[
            const SizedBox(height: 12),
            CustomSecondaryButton(
              text: "Skip Reminders For Now",
              onPressed: isBusy ? () {} : () => provider.submitCase(context, skipReminders: true),
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
  late TextEditingController _partyNameCtrl;
  final FocusNode _partyNameNode = FocusNode();
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
    _partyNameCtrl = TextEditingController(text: widget.provider.caseData.relatedPartyName ?? '');
  }
  @override
  void dispose() {
    _caseNumCtrl.dispose();
    _legalRepCtrl.dispose();
    _partyNameCtrl.dispose();
    _partyNameNode.dispose();
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
        CustomTextField(labelText: "Case Reference Number *", hintText: "eg. FAMS-5856", controller: _caseNumCtrl, node: caseNumNode, nextNode: legalRepNode, onChange: (v) => widget.provider.updateCaseInfo(v, _legalRepCtrl.text)),
        const SizedBox(height: 15),
        CustomTextField(labelText: "Legal Representative *", hintText: "eg. Sam Mark", controller: _legalRepCtrl, node: legalRepNode, nextNode: _partyNameNode, onChange: (v) => widget.provider.updateCaseInfo(_caseNumCtrl.text, v)),
        const SizedBox(height: 25),
        _buildRelatedPartySection(),
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

  // The other parent / guardian. Optional; when saved it pre-fills the related
  // party on new disputes and non-compliance records.
  Widget _buildRelatedPartySection() {
    final relation = widget.provider.caseData.relatedPartyRelation;
    final options = (relation == null || relatedPartyRelations.contains(relation))
        ? relatedPartyRelations
        : [...relatedPartyRelations, relation];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Related Party", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          "Optional. The other parent or guardian named in your court order — filled in automatically on new disputes and non-compliance records.",
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text("Relationship", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 5),
        CustomDropDown<String>(
          value: relation,
          hint: "Select relationship",
          items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => widget.provider.updateRelatedParty(relation: v, name: _partyNameCtrl.text),
        ),
        const SizedBox(height: 15),
        CustomTextField(
          labelText: "Name",
          hintText: "eg. Alex Smith",
          controller: _partyNameCtrl,
          node: _partyNameNode,
          nextNode: nameNode,
          onChange: (v) => widget.provider.updateRelatedParty(relation: relation, name: v),
        ),
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

class _Step2Reminders extends StatelessWidget {
  final CaseSetupProvider provider;
  const _Step2Reminders({required this.provider});

  static const _custodyColor = 0xFF8E24AA;
  static const _paymentColor = 0xFF43A047;

  bool _hasTag(String tag) =>
      provider.reminderDrafts.any((r) => r.tag.toLowerCase() == tag.toLowerCase());

  // Opens the repeated-reminder form without saving; the case doesn't exist
  // yet, so drafts are saved together with it in submitCase.
  Future<void> _openForm(BuildContext context, {int? editIndex, ReminderFormArgs? args}) async {
    final result = await Navigator.pushNamed(
      context,
      NewReminderScreen.routeName,
      arguments: args ??
          ReminderFormArgs(
            draftOnly: true,
            draft: editIndex == null ? null : provider.reminderDrafts[editIndex],
          ),
    );
    if (result is! ReminderModel) return;
    if (editIndex == null) {
      provider.addReminderDraft(result);
    } else {
      provider.replaceReminderDraft(editIndex, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.lightBlueColor, borderRadius: BorderRadius.circular(12)),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Repeated reminders keep you on top of your court order — e.g. a handover every second "
                  "Friday, or support due every fortnight. They show on your calendar and can notify you. "
                  "Reminders don't affect your insights or reports, which use the entries you record.",
                  style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!_hasTag("Custody"))
          _suggestionCard(
            context,
            title: "Custody reminder",
            subtitle: "e.g. Handover every second Friday",
            icon: Icons.child_care,
            color: _custodyColor,
            onTap: () => _openForm(context,
                args: const ReminderFormArgs(
                  draftOnly: true,
                  presetTitle: "Custody handover",
                  presetTag: "Custody",
                  presetColor: _custodyColor,
                )),
          ),
        if (!_hasTag("Payment"))
          _suggestionCard(
            context,
            title: "Payment reminder",
            subtitle: "e.g. Child support due every fortnight",
            icon: Icons.payment,
            color: _paymentColor,
            onTap: () => _openForm(context,
                args: const ReminderFormArgs(
                  draftOnly: true,
                  presetTitle: "Child support payment",
                  presetTag: "Payment",
                  presetColor: _paymentColor,
                )),
          ),
        if (provider.reminderDrafts.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text("Your reminders", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          for (var i = 0; i < provider.reminderDrafts.length; i++)
            _draftCard(context, i, provider.reminderDrafts[i]),
        ],
        const SizedBox(height: 8),
        CustomSecondaryButton(
          text: "Add Another Reminder",
          onPressed: () => _openForm(context, args: const ReminderFormArgs(draftOnly: true)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _suggestionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required int color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(color).withValues(alpha: 0.12),
                  child: Icon(icon, color: Color(color)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                const Text("Set up", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _draftCard(BuildContext context, int index, ReminderModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: r.colorValue, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                ReminderTagChip(tag: r.tag, color: r.color),
                const SizedBox(height: 6),
                Text(
                  "${r.scheduleSummary} · from ${DateFormat('d MMM yyyy').format(r.date)}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: "Edit",
            icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
            onPressed: () => _openForm(context, editIndex: index),
          ),
          IconButton(
            tooltip: "Remove",
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => provider.removeReminderDraft(index),
          ),
        ],
      ),
    );
  }
}
