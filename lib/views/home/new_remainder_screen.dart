import 'package:clearcase/models/remainder_model.dart';
import 'package:clearcase/provider/remainder_provider.dart';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helping_functions.dart';
import '../../provider/calender_provider.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/delete_entries_confirmation.dart';
import '../widgets/reminder_tag_picker.dart';
import '../widgets/weekday_selector.dart';

/// Opens the reminder form straight onto a given kind, optionally prefilled.
/// With [draftOnly] nothing is saved: the reminder is returned through
/// `Navigator.pop` — case setup uses this before the case exists.
class ReminderFormArgs {
  final bool repeated;
  final ReminderModel? draft;
  final String? presetTitle;
  final String? presetTag;
  final int? presetColor;
  final bool draftOnly;

  const ReminderFormArgs({
    this.repeated = true,
    this.draft,
    this.presetTitle,
    this.presetTag,
    this.presetColor,
    this.draftOnly = false,
  });
}

/// Add or edit a reminder. Arguments:
/// - none / a DateTime: asks "Single or Repeated?" first (the date prefills);
/// - a reminder id (String): edits it;
/// - [ReminderFormArgs]: skips the question.
class NewReminderScreen extends StatefulWidget {
  static const routeName = '/new-reminder';
  const NewReminderScreen({super.key});

  @override
  State<NewReminderScreen> createState() => _NewReminderScreenState();
}

enum _Mode { choose, single, repeated }

class _NewReminderScreenState extends State<NewReminderScreen> {
  final _titleController = TextEditingController();
  final _tagController = TextEditingController();
  final _descController = TextEditingController();
  final _titleNode = FocusNode();
  final _tagNode = FocusNode();
  final _descNode = FocusNode();

  _Mode _mode = _Mode.choose;
  // True when the form was reached through the chooser, so Back returns to it.
  bool _cameFromChooser = false;
  bool _draftOnly = false;
  String? _editingId;
  bool _isFetching = false;
  bool _isInitialized = false;

  DateTime _date = DateTime.now();
  int _color = reminderColors.first;
  Set<int> _weekdays = {};
  int _intervalWeeks = 1;
  bool _hasEndDate = false;
  DateTime? _endDate;
  String _remindMe = remindMeOptions.first;

  bool get _isRepeated => _mode == _Mode.repeated;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return;
    _isInitialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _editingId = args;
      _loadReminder(args);
    } else if (args is ReminderFormArgs) {
      _draftOnly = args.draftOnly;
      _mode = args.repeated ? _Mode.repeated : _Mode.single;
      final draft = args.draft;
      if (draft != null) {
        _fill(draft);
      } else {
        _titleController.text = args.presetTitle ?? '';
        _tagController.text = args.presetTag ?? '';
        _color = args.presetColor ?? _color;
      }
    } else if (args is DateTime) {
      _date = args;
    }
  }

  Future<void> _loadReminder(String id) async {
    final caseId = Provider.of<CalendarProvider>(context, listen: false).selectedCase?.id;
    if (caseId == null) return;
    setState(() => _isFetching = true);
    final reminder = await Provider.of<ReminderProvider>(context, listen: false).getReminderById(caseId, id);
    if (!mounted) return;
    setState(() {
      if (reminder != null) {
        _fill(reminder);
        _mode = reminder.isRepeat ? _Mode.repeated : _Mode.single;
      }
      _isFetching = false;
    });
  }

  void _fill(ReminderModel r) {
    _titleController.text = r.title;
    _tagController.text = r.tag;
    _descController.text = r.description;
    _color = r.color;
    _date = r.date;
    _weekdays = r.weekdays.toSet();
    _intervalWeeks = r.intervalWeeks;
    _endDate = r.endDate;
    _hasEndDate = r.endDate != null;
    _remindMe = remindMeOptions.contains(r.remindMeOption) ? r.remindMeOption : remindMeOptions.first;
  }

  void _choose(_Mode mode) {
    setState(() {
      _mode = mode;
      _cameFromChooser = true;
      // Starting a repeat from a tapped day: repeat on that weekday.
      if (mode == _Mode.repeated && _weekdays.isEmpty) _weekdays = {_date.weekday};
    });
  }

  ReminderModel _buildReminder(String caseId) {
    final tag = _tagController.text.trim();
    return ReminderModel(
      id: _editingId,
      caseId: caseId,
      date: _date,
      title: _titleController.text.trim(),
      tag: tag.isEmpty ? "Reminder" : tag,
      color: _color,
      isRepeat: _isRepeated,
      weekdays: _isRepeated ? (_weekdays.toList()..sort()) : const [],
      intervalWeeks: _isRepeated ? _intervalWeeks : 1,
      endDate: (_isRepeated && _hasEndDate) ? _endDate : null,
      description: _descController.text.trim(),
      remindMeOption: _remindMe,
    );
  }

  void _submit(ReminderProvider provider, String? caseId) {
    if (_titleController.text.trim().isEmpty) {
      showSnackBar(context, "Please enter a title");
      return;
    }
    if (_isRepeated) {
      if (_weekdays.isEmpty) {
        showSnackBar(context, "Select at least one day to repeat on");
        return;
      }
      if (_hasEndDate && _endDate == null) {
        showSnackBar(context, "Pick an end date, or turn off the end date");
        return;
      }
      if (_hasEndDate && _buildReminder('').nextOccurrence(from: _date) == null) {
        showSnackBar(context, "This reminder ends before it first repeats");
        return;
      }
    }

    if (_draftOnly) {
      Navigator.pop(context, _buildReminder(''));
      return;
    }
    if (caseId == null) {
      showSnackBar(context, "Select a case first");
      return;
    }
    final reminder = _buildReminder(caseId);
    if (_editingId == null) {
      provider.addReminder(context, reminder);
    } else {
      provider.updateReminder(context, reminder);
    }
  }

  void _confirmDelete(ReminderProvider provider, String caseId) {
    DeleteEntriesConfirmation.show(context, () async {
      await provider.deleteReminder(context, caseId, _editingId!);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    _descController.dispose();
    _titleNode.dispose();
    _tagNode.dispose();
    _descNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CalendarProvider, ReminderProvider>(
      builder: (context, calProvider, reminderProvider, child) {
        final selectedCase = calProvider.selectedCase;
        final showLoader = reminderProvider.isLoading || _isFetching;

        return PopScope(
          // From a form reached via the chooser, Back returns to the chooser.
          canPop: !(_cameFromChooser && _mode != _Mode.choose),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _mode = _Mode.choose);
          },
          child: Scaffold(
            backgroundColor: AppColors.surfaceColor,
            appBar: _buildAppBar(calProvider, reminderProvider),
            body: showLoader
                ? const Center(child: CircularProgressIndicator())
                : _mode == _Mode.choose
                    ? _buildChooser()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _isRepeated
                            ? _buildRepeatedForm(reminderProvider, selectedCase?.id)
                            : _buildSingleForm(reminderProvider, selectedCase?.id),
                      ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(CalendarProvider calProvider, ReminderProvider reminderProvider) {
    final isEditMode = _editingId != null;
    final String title;
    if (isEditMode) {
      title = "Edit Reminder";
    } else if (_mode == _Mode.single) {
      title = "Single Reminder";
    } else if (_mode == _Mode.repeated) {
      title = "Repeated Reminder";
    } else {
      title = "Add Reminder";
    }
    final showCasePicker = !_draftOnly && calProvider.allCases.length > 1;

    return AppBar(
      title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        if (isEditMode && calProvider.selectedCase != null)
          IconButton(
            tooltip: "Delete reminder",
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(reminderProvider, calProvider.selectedCase!.id),
          ),
      ],
      bottom: showCasePicker
          ? PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: IgnorePointer(
                  // Prevents case switching while editing
                  ignoring: isEditMode,
                  child: Opacity(
                    opacity: isEditMode ? 0.6 : 1.0,
                    child: CustomDropDown<String>(
                      hint: "Select a Case",
                      value: calProvider.selectedCase?.id,
                      items: calProvider.allCases
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(calProvider.getCaseDisplayName(c),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (id) {
                        final selected = calProvider.allCases.firstWhere((c) => c.id == id);
                        calProvider.setSelectedCase(selected);
                      },
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // --- Chooser ---------------------------------------------------------------

  Widget _buildChooser() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("What kind of reminder?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        _choiceCard(
          icon: Icons.event,
          title: "Single Reminder",
          subtitle: "A reminder on one specific date.",
          onTap: () => _choose(_Mode.single),
        ),
        _choiceCard(
          icon: Icons.repeat,
          title: "Repeated Reminder",
          subtitle: "Repeats on the days you choose — e.g. every second Monday and Friday.",
          onTap: () => _choose(_Mode.repeated),
        ),
      ],
    );
  }

  Widget _choiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Forms -----------------------------------------------------------------

  Widget _buildSingleForm(ReminderProvider provider, String? caseId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleField("e.g. Emma's dentist appointment"),
        const SizedBox(height: 15),
        _buildClickableField(
          label: "Date",
          value: DateFormat('EEE, d MMM yyyy').format(_date),
          onTap: () => _pickDate(
            initial: _date,
            first: DateTime(2000),
            onPicked: (d) => _date = d,
          ),
        ),
        const SizedBox(height: 20),
        _tagPicker(),
        const SizedBox(height: 20),
        _notificationField(),
        const SizedBox(height: 15),
        _descriptionField(),
        const SizedBox(height: 30),
        _saveButton(provider, caseId),
      ],
    );
  }

  Widget _buildRepeatedForm(ReminderProvider provider, String? caseId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleField("e.g. Weekend handover"),
        const SizedBox(height: 20),
        _tagPicker(),
        const SizedBox(height: 24),
        _label("Repeat on"),
        const Text("Select one or more days", style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 12),
        WeekdaySelector(
          selectedDays: _weekdays,
          onToggle: (d) => setState(() => _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d)),
        ),
        const SizedBox(height: 24),
        _label("Repeat frequency"),
        const SizedBox(height: 4),
        _frequencySelector(),
        const SizedBox(height: 20),
        _buildClickableField(
          label: "Starting from",
          value: DateFormat('EEE, d MMM yyyy').format(_date),
          onTap: () => _pickDate(
            initial: _date,
            first: DateTime(2000),
            onPicked: (d) {
              _date = d;
              if (_endDate != null && _endDate!.isBefore(d)) _endDate = d;
            },
          ),
        ),
        const SizedBox(height: 15),
        _endDateSection(),
        const SizedBox(height: 15),
        _scheduleSummary(),
        const SizedBox(height: 20),
        _notificationField(),
        const SizedBox(height: 15),
        _descriptionField(),
        const SizedBox(height: 30),
        _saveButton(provider, caseId),
      ],
    );
  }

  Widget _titleField(String hint) => CustomTextField(
        labelText: "Reminder Title",
        hintText: hint,
        controller: _titleController,
        node: _titleNode,
        nextNode: _tagNode,
        borderRadius: 8,
        backgroundColor: Colors.grey.shade200,
      );

  Widget _tagPicker() => ReminderTagPicker(
        tagController: _tagController,
        tagNode: _tagNode,
        color: _color,
        onColorChanged: (c) => setState(() => _color = c),
        onTagChanged: () => setState(() {}),
      );

  Widget _descriptionField() => CustomTextField(
        labelText: "Notes (Optional)",
        hintText: "Any extra details...",
        maxLines: 3,
        controller: _descController,
        node: _descNode,
        borderRadius: 8,
        backgroundColor: Colors.grey.shade200,
      );

  Widget _notificationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("Notification"),
        const SizedBox(height: 8),
        CustomDropDown<String>(
          value: _remindMe,
          hint: "Select notification",
          items: remindMeOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => _remindMe = v ?? remindMeOptions.first),
        ),
      ],
    );
  }

  Widget _frequencySelector() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 3.2,
      padding: const EdgeInsets.only(top: 8),
      children: reminderFrequencies.entries.map((f) {
        final selected = _intervalWeeks == f.key;
        return GestureDetector(
          onTap: () => setState(() => _intervalWeeks = f.key),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary),
            ),
            child: Text(
              f.value,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.primary,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _endDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("End date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 2),
                  Text("Optional — off repeats indefinitely", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: _hasEndDate,
              activeTrackColor: AppColors.primary,
              activeThumbColor: Colors.white,
              onChanged: (v) => setState(() => _hasEndDate = v),
            ),
          ],
        ),
        if (_hasEndDate) ...[
          const SizedBox(height: 10),
          _buildClickableField(
            label: "Ends on",
            value: _endDate == null ? "Select date" : DateFormat('EEE, d MMM yyyy').format(_endDate!),
            onTap: () => _pickDate(
              initial: _endDate ?? _date,
              first: _date,
              onPicked: (d) => _endDate = d,
            ),
          ),
        ],
      ],
    );
  }

  // Spells the repeat out and lists the next few dates, so "Fortnightly" on
  // Mon + Fri can be checked before saving.
  Widget _scheduleSummary() {
    if (_weekdays.isEmpty) return const SizedBox.shrink();
    final preview = _buildReminder('');
    final upcoming = preview
        .occurrencesBetween(_date, _date.add(Duration(days: 7 * _intervalWeeks * 3)))
        .take(4)
        .map((d) => DateFormat('EEE d MMM').format(d))
        .toList();
    final ends = (_hasEndDate && _endDate != null) ? ", until ${DateFormat('d MMM yyyy').format(_endDate!)}" : "";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(_color).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Repeats ${ReminderModel.describeRepeat(_weekdays, _intervalWeeks)}, "
            "from ${DateFormat('d MMM yyyy').format(_date)}$ends.",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text("Next: ${upcoming.join(' · ')}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _saveButton(ReminderProvider provider, String? caseId) {
    final String label;
    if (_draftOnly) {
      label = "Done";
    } else if (_editingId != null) {
      label = "Update Reminder";
    } else {
      label = "Save Reminder";
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        onPressed: () => _submit(provider, caseId),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initial,
    required DateTime first,
    required void Function(DateTime) onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500));

  Widget _buildClickableField({required String label, required String value, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontSize: 14)),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
