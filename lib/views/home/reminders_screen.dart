import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/calender_event_model.dart';
import '../../models/remainder_model.dart';
import '../../provider/calender_provider.dart';
import '../../provider/remainder_provider.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/delete_entries_confirmation.dart';
import '../widgets/reminder_tag_picker.dart';
import 'new_remainder_screen.dart';
import 'rule_configuration_screen.dart';

/// Every reminder for the calendar's selected case. "Upcoming" lists each
/// coming occurrence by date; "Repeated" lists the active repeating reminders
/// to edit. Schedules saved by the old case-setup flow appear in both.
///
/// Argument: optional int, the tab to open on (0 Upcoming, 1 Repeated).
class RemindersScreen extends StatefulWidget {
  static const routeName = '/reminders';
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  int _tab = 0;
  bool _isInit = true;

  // Colours the calendar already uses for the old case-setup schedules.
  static const Map<String, Color> _legacyColors = {
    'custody': Colors.purple,
    'payment': Colors.green,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) _tab = args.clamp(0, 1);
      _isInit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.surfaceColor,
          appBar: AppBar(
            title: const Text("Reminders", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.surfaceColor,
            scrolledUnderElevation: 0,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text("Add Reminder", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pushNamed(context, NewReminderScreen.routeName),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  children: [
                    if (provider.allCases.length > 1) ...[
                      CustomDropDown<String>(
                        hint: "Select a Case",
                        value: provider.selectedCase?.id,
                        items: provider.allCases
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(provider.getCaseDisplayName(c),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (id) =>
                            provider.setSelectedCase(provider.allCases.firstWhere((c) => c.id == id)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildToggle(),
                  ],
                ),
              ),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tab == 0
                        ? _buildUpcoming(provider)
                        : _buildRepeated(provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggle() {
    Widget half(String label, int index) {
      final selected = _tab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
      child: Row(children: [half("Upcoming Reminders", 0), half("Repeated Reminders", 1)]),
    );
  }

  // --- Upcoming --------------------------------------------------------------

  Widget _buildUpcoming(CalendarProvider provider) {
    final events = provider.upcomingReminders();
    if (events.isEmpty) {
      return _emptyState(Icons.notifications_none, "No upcoming reminders",
          "Reminders for the next 90 days show here.");
    }

    final children = <Widget>[];
    DateTime? lastDay;
    for (final e in events) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      if (lastDay != day) {
        children.add(_dayHeader(day));
        lastDay = day;
      }
      children.add(_upcomingTile(provider, e));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 96), children: children);
  }

  Widget _dayHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final String label;
    if (day == today) {
      label = "Today";
    } else if (day == today.add(const Duration(days: 1))) {
      label = "Tomorrow";
    } else {
      label = DateFormat('EEEE, d MMMM').format(day);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }

  Widget _upcomingTile(CalendarProvider provider, CalendarEvent e) {
    final legacy = e.isScheduledRule;
    final color = legacy
        ? (_legacyColors[(e.category ?? '').toLowerCase()] ?? Colors.lightBlue)
        : Color(e.color ?? defaultReminderColor);
    final tag = legacy ? "Schedule" : (e.category ?? "Reminder");
    return _card(
      color: color,
      onTap: () => legacy ? _openLegacyRule(provider, e.category ?? '') : _openReminder(e.id),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(child: ReminderTagChip(tag: tag, color: color.toARGB32())),
                    if (e.isRepeatedReminder || legacy) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.repeat, size: 14, color: Colors.grey[600]),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  // --- Repeated --------------------------------------------------------------

  Widget _buildRepeated(CalendarProvider provider) {
    final repeats = provider.reminders.where((r) => r.isActiveRepeat).toList()
      ..sort((a, b) {
        final an = a.nextOccurrence(), bn = b.nextOccurrence();
        if (an == null || bn == null) return an == null ? 1 : -1;
        return an.compareTo(bn);
      });
    final legacy = provider.scheduledRules;

    if (repeats.isEmpty && legacy.isEmpty) {
      return _emptyState(Icons.repeat, "No repeated reminders",
          "Add a repeated reminder for things like handovers or support payments.");
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      children: [
        ...repeats.map((r) => _repeatTile(provider, r)),
        if (legacy.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 8),
            child: Text("From your original case setup",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          ),
          ...legacy.map((rule) => _legacyRuleTile(provider, rule)),
        ],
      ],
    );
  }

  Widget _repeatTile(CalendarProvider provider, ReminderModel r) {
    final next = r.nextOccurrence();
    final details = <String>[
      if (next != null) "Next: ${DateFormat('EEE d MMM').format(next)}",
      r.endDate == null ? "No end date" : "Until ${DateFormat('d MMM yyyy').format(r.endDate!)}",
    ];
    return _card(
      color: r.colorValue,
      onTap: () => _openReminder(r.id!),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                ReminderTagChip(tag: r.tag, color: r.color),
                const SizedBox(height: 8),
                Text(r.scheduleSummary, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(details.join(" · "), style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                if (r.remindMeOption == reminderNotificationsOff) ...[
                  const SizedBox(height: 2),
                  Text("Notifications off", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: "Delete",
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              final caseId = provider.selectedCase?.id;
              if (caseId == null) return;
              final reminderProvider = Provider.of<ReminderProvider>(context, listen: false);
              DeleteEntriesConfirmation.show(
                context,
                () => reminderProvider.deleteReminder(context, caseId, r.id!),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legacyRuleTile(CalendarProvider provider, Map<String, dynamic> rule) {
    final id = (rule['id'] ?? '').toString();
    final name = id.isEmpty ? "Schedule" : id[0].toUpperCase() + id.substring(1);
    final freq = rule['repeatFrequency'];
    final start = DateTime.tryParse((rule['startDate'] ?? '').toString());
    final details = <String>[
      (freq is String && freq.isNotEmpty && freq != "None") ? freq : "One-off",
      if (start != null) "From ${DateFormat('d MMM yyyy').format(start)}",
    ];
    return _card(
      color: _legacyColors[id.toLowerCase()] ?? Colors.lightBlue,
      onTap: () => _openLegacyRule(provider, id),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Scheduled $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(details.join(" · "), style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: "Delete",
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => DeleteEntriesConfirmation.show(
              context,
              () => provider.deleteScheduledRule(id),
            ),
          ),
        ],
      ),
    );
  }

  // --- Shared ----------------------------------------------------------------

  void _openReminder(String id) => Navigator.pushNamed(context, NewReminderScreen.routeName, arguments: id);

  void _openLegacyRule(CalendarProvider provider, String ruleId) {
    final selected = provider.selectedCase;
    if (selected == null || ruleId.isEmpty) return;
    Navigator.pushNamed(context, RuleConfigurationScreen.routeName, arguments: {
      'caseId': selected.id,
      'category': ruleId,
      'availableChildren': selected.children,
    });
  }

  // White card with a stripe in the reminder's colour down the left edge.
  Widget _card({required Color color, required VoidCallback onTap, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      children: [
        Icon(icon, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}
