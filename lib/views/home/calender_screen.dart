import 'package:clearcase/models/calender_event_model.dart';
import 'package:clearcase/provider/calender_provider.dart';
import 'package:clearcase/views/home/new_breach_screen.dart';
import 'package:clearcase/views/home/new_custody_screen.dart';
import 'package:clearcase/views/home/new_dispute_screen.dart';
import 'package:clearcase/views/home/new_entry_screen.dart';
import 'package:clearcase/views/home/new_payment_screen.dart';
import 'package:clearcase/views/home/new_remainder_screen.dart';
import 'package:clearcase/views/home/scheduled_dates_screen.dart';
import 'package:clearcase/views/widgets/custom_dialog.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/delete_entries_confirmation.dart';
import 'case_setup_screen.dart';


class CalenderScreen extends StatefulWidget {
  const CalenderScreen({super.key});

  @override
  State<CalenderScreen> createState() => _CalenderScreenState();
}

class _CalenderScreenState extends State<CalenderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.surfaceColor,
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          shape: const CircleBorder(),
          onPressed: () => Navigator.pushNamed(context, NewEntryScreen.routeName),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      // Inside _CalenderScreenState's build method
      body: SafeArea(
        child: Consumer<CalendarProvider>(
          builder: (context, provider, child) {
            return RefreshIndicator(
              onRefresh: () async {
                // 1. Refresh the list of cases first
                await provider.fetchUserCases();

                // 2. Then refresh events for the currently selected case
                if (provider.selectedCase != null) {
                  await provider.fetchEventsForCase(provider.selectedCase!.id);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),child:  Column(
                    children: [
                      _buildHeader(context),
                      _buildCalendar(context, provider),
                       const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Column(
                          children: [
                            _buildBottomButton("Scheduled Dates", () {
                              Navigator.pushNamed(context, ScheduledDatesScreen.routeName);
                            }),
                            const SizedBox(height: 12),
                            _buildBottomButton("Calendar legends", () {
                              _showLegendsPopup(context);
                            }),
                          ],
                        ),
                      )
                    ],
                  ),
               ),
            );
          },
        ),
      )
      );
  }


  Widget _buildHeader(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Select Case",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),

                    // Handle loading state to prevent the "item not found" crash during fetch
                    provider.isLoading
                        ? _buildLoadingPlaceholder()
                        : ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 45,
                        maxHeight: 100,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<String>( // Change type to String
                          isExpanded: true,
                          // Use the ID as the value. Fallback to null if not found.
                          value: provider.allCases.any((c) => c.id == provider.selectedCase?.id)
                              ? provider.selectedCase?.id
                              : null,
                          selectedItemBuilder: (context) {
                            return provider.allCases.map((caseItem) {
                              return Container(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  provider.getCaseDisplayName(caseItem),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black,
                                    height: 1.2,
                                  ),
                                  maxLines: 3,
                                  softWrap: true,
                                ),
                              );
                            }).toList();
                          },
                          items: [
                            ...provider.allCases.map((caseItem) => DropdownMenuItem<String>(
                              value: caseItem.id, // Value is the ID
                              child: Text(
                                provider.getCaseDisplayName(caseItem),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            )),
                            const DropdownMenuItem<String>(
                              value: "add_new",
                              child: Text(
                                "Add New Case",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == "add_new") {
                              Navigator.pushNamed(context, CaseSetupScreen.routeName);
                            } else if (value != null) {
                              // Find the actual object by the ID string
                              final selected = provider.allCases.firstWhere((c) => c.id == value);
                              provider.setSelectedCase(selected);
                            }
                          },
                          buttonStyleData: const ButtonStyleData(
                            padding: EdgeInsets.zero,
                            height: null,
                          ),
                          iconStyleData: const IconStyleData(
                            icon: Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 24),
                            openMenuIcon: Icon(Icons.keyboard_arrow_up, color: Colors.black, size: 24),
                          ),
                          dropdownStyleData: DropdownStyleData(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white,
                            ),
                            offset: const Offset(0, -5),
                            elevation: 4,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildExportButton(),
            ],
          ),
        );
      },
    );
  }

// Simple loading placeholder
  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 45,
      alignment: Alignment.centerLeft,
      child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
      ),
    );
  }
  Widget _buildExportButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Text("Export", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          SizedBox(width: 5),
          Icon(Icons.upload, color: Colors.blue, size: 16),
        ],
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, CalendarProvider provider) {
    // We use a fixed height or a Stack to ensure the loader appears
    // in the same space the calendar occupies.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      height: 400, // Matches your existing calendar height
      child: provider.isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      )
          : TableCalendar<CalendarEvent>(
        firstDay: DateTime.utc(2020, 10, 16),
        lastDay: DateTime.utc(2030, 3, 14),
        focusedDay: provider.focusedDay,
        selectedDayPredicate: (day) => provider.isSameDay(provider.selectedDay, day),
        eventLoader: provider.getEventsForDay,
        onDaySelected: (selectedDay, focusedDay) {
          provider.onDaySelected(selectedDay, focusedDay);
          _showDayDetailsSheet(context, provider, selectedDay);
        },
        onPageChanged: provider.onPageChanged,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: const TextStyle(color: Colors.black),
          defaultTextStyle: const TextStyle(fontWeight: FontWeight.w600),
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(12),
          ),
          selectedDecoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(10),
          ),
          markerSize: 6,
          cellMargin: const EdgeInsets.symmetric(horizontal: 2, vertical:1),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;

            double screenWidth = MediaQuery.of(context).size.width;
            // Lower the icons slightly by increasing bottom value
            double bottomPadding = screenWidth < 350 ? 2 : 4;
            double iconSize = screenWidth > 600 ? 11 : 10; // Slightly smaller to prevent clipping

            return Stack(
              alignment: Alignment.bottomCenter, // Anchor to the bottom
              children: [
                Positioned(
                  bottom: bottomPadding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...events.take(2).map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.0),
                          child: Icon(
                            _getIconForType(e.type),
                            size: iconSize,
                            color: provider.isSameDay(provider.selectedDay, date)
                                ? Colors.white.withOpacity(0.9)
                                : _getColorForType(e.type),
                          ),
                        );
                      }),
                      if (events.length > 2)
                        FittedBox(
                          child: Text(
                            "+${events.length - 2}",
                            style: TextStyle(
                              fontSize: iconSize - 2,
                              fontWeight: FontWeight.bold,
                              color: provider.isSameDay(provider.selectedDay, date)
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },   ),      ),
    );
  }


  Widget _buildBottomButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide.none,
          ),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  void _showDayDetailsSheet(BuildContext context, CalendarProvider provider, DateTime date) {
    final events = provider.getEventsForDay(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, // Increased slightly for better initial view
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column( // Main container remains a column
            children: [
              // Handle bar
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),

              Text(
                DateFormat('EEEE, MMMM d, y').format(date),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 15),

              // Use Expanded to let the scrollable area take up remaining space
              Expanded(
                child: ListView(
                  controller: controller, // Attach the sheet's controller here
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // 1. Show Events List first
                    if (events.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                            child: Text("No events scheduled.",
                                style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...events.map((event) => _buildEventCard(event)).toList(),

                    const SizedBox(height: 20),

                    // 2. Action Buttons are now INSIDE the scrollview
                    _buildActionButton("Add Entry", Icons.add, const Color(0xFF4A148C),
                        Colors.white, true, () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, NewEntryScreen.routeName,
                              arguments: date);
                        }),
                    const SizedBox(height: 12),
                    _buildActionButton("Add Reminder", Icons.access_time,
                        const Color(0xFF4A148C), const Color(0xFFE1F5FE), false, () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, NewReminderScreen.routeName,
                              arguments: date);
                        }),
                    const SizedBox(height: 12),
                    _buildActionButton("View Events", Icons.calendar_today,
                        const Color(0xFF4A148C), const Color(0xFFE1F5FE), false, () {
                          Navigator.pop(context);
                          _showEventsPopup(context, date, events);
                        }),
                    const SizedBox(height: 30), // Padding at the bottom
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLegendsPopup(BuildContext context) {
    TopPopupDialog.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Calendar Legends", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 10),
          _buildLegendItem("Custody", Icons.person, Colors.purple),
          _buildLegendItem("Payments", Icons.payment, Colors.green),
          _buildLegendItem("Non-Compliance", Icons.cancel_presentation, Colors.red),
          _buildLegendItem("Flagged Events", Icons.flag, Colors.orange),
          _buildLegendItem("Reminders", Icons.notifications, Colors.purpleAccent),
          _buildLegendItem("Disputes", Icons.error, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          Icon(icon, color: color, size: 28),
        ],
      ),
    );
  }

  // --- 3. Event Card Widget (Matches Screenshot 2026-01-27 174107.png) ---
  Widget _buildEventCard(CalendarEvent event) {
    Color typeColor = _getColorForType(event.type);
    Color lightColor = typeColor.withOpacity(0.1);

    String formattedDate = DateFormat('dd MMM yyyy').format(event.date);
    String tagText = event.type.name[0].toUpperCase() + event.type.name.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Add margin for spacing between cards
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align icons to top of wrapped text
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      if (event.isFlagged)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Icon(Icons.flag, color: Colors.orange, size: 18),
                          ),
                        ),
                    ],
                  ),
                  softWrap: true, // Allows automatic wrapping
                ),
              ),
              const SizedBox(width: 5),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      // Navigate first
                      if (event.type == EventType.custody) {
                        await Navigator.pushNamed(context, NewCustodyScreen.routeName, arguments: event.id);
                      } else if (event.type == EventType.payment) {
                        await Navigator.pushNamed(context, NewPaymentScreen.routeName, arguments: event.id);
                      } else if (event.type == EventType.reminder) {
                        await Navigator.pushNamed(context, NewReminderScreen.routeName, arguments: event.id);
                      }else if (event.type == EventType.dispute) {
                        await Navigator.pushNamed(context, NewDisputeScreen.routeName, arguments: event.id);
                      }else if (event.type == EventType.breach) {
                        await Navigator.pushNamed(context, NewBreachScreen.routeName, arguments: event.id);
                      }

                      // Now pop the bottom sheet safely
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Icon(Icons.edit, size: 20),
                  ),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onTap: () {
                      final calProvider = Provider.of<CalendarProvider>(context, listen: false);

                      DeleteEntriesConfirmation.show(context, () async {
                        // 1. Close the Bottom Sheet immediately (if one is open)
                        // This ensures the Snackbar has a clean Scaffold to display on
                        Navigator.pop(context);

                        // 2. Trigger the delete
                        await calProvider.deleteRecord(
                          context: context,
                          recordId: event.id,
                          type: event.type,
                          attachmentUrls: event.attachmentUrls,
                        );
                      });
                    },
                    child: const Icon(Icons.delete, color: Colors.red, size: 20),
                  ),
                  
                 ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                  event.type == EventType.payment ? Icons.payment : Icons.person,
                  size: 16,
                  color: typeColor
              ),
              const SizedBox(width: 5),
              Text(formattedDate, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: lightColor, borderRadius: BorderRadius.circular(8)),
                child: Text(tagText, style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            ],
          ),

          if (event.type == EventType.payment && event.amount != null) ...[
            const SizedBox(height: 10),
            Text(
              "Amount: ₹${event.amount!.toStringAsFixed(2)}", // Changed to ₹ based on your locale
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
            ),
          ],

          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              event.description!,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Inside _buildEventCard:
            if (event.childNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,         // Space between chips horizontally
                runSpacing: 6,      // Space between rows if they wrap
                children: event.childNames.map((name) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                )).toList(),
              ),
            ],
           ]
        ],
      ),
    );
  }  // --- 4. Action Button Builder ---
  Widget _buildActionButton(String label, IconData icon, Color iconColor, Color bgColor, bool isFilled, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isFilled ? iconColor : bgColor,
          foregroundColor: isFilled ? Colors.white : iconColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: isFilled ? BorderSide.none : BorderSide(color: iconColor, width: 1),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, color: isFilled ? Colors.white : iconColor),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  // --- 5. Top Popup Logic ---
  void _showEventsPopup(BuildContext context, DateTime date, List<CalendarEvent> events) {
    TopPopupDialog.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Keeps it tight to content
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Events", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 10),
          Text(DateFormat('EEEE, MMMM d, y').format(date), style: const TextStyle(color: Colors.grey)),


          // --- CHANGE HERE: Wrap in Expanded and ListView ---
          // We use ConstrainedBox to limit the height so it doesn't take up the whole screen
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No events found."),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5, // Limit to 50% of screen height
              ),
              child: ListView.builder(
                shrinkWrap: true, // Crucial for using ListView inside Column/Dialog
                physics: const BouncingScrollPhysics(),
                itemCount: events.length,
                itemBuilder: (context, index) => _buildEventCard(events[index]),
              ),
            )
        ],
      ),
    );
  }
  Color _getColorForType(EventType type) {
    switch (type) {
      case EventType.custody: return Colors.purple;
      case EventType.payment: return Colors.green;
      case EventType.dispute: return Colors.red;
      case EventType.breach: return Colors.redAccent;
      case EventType.reminder: return Colors.purpleAccent;
    }
  }

  IconData _getIconForType(EventType type) {
    switch (type) {
      case EventType.custody: return Icons.person;
      case EventType.payment: return Icons.payment;
      case EventType.dispute: return Icons.error_outlined;
      case EventType.breach: return Icons.cancel_presentation;
      case EventType.reminder: return Icons.notifications;
    }
  }
}