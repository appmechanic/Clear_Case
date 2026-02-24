import 'package:clearcase/models/calender_event_model.dart';
import 'package:clearcase/provider/calender_provider.dart';
import 'package:clearcase/views/home/new_entry_screen.dart';
import 'package:clearcase/views/home/new_remainder_screen.dart';
import 'package:clearcase/views/home/scheduled_dates_screen.dart';
import 'package:clearcase/views/widgets/custom_dialog.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/case_model.dart';

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
        body: SafeArea(
          child: Consumer<CalendarProvider>(
            builder: (context, provider, child) {
              return Column(
                children: [
                  _buildHeader(context),
                  
                  _buildCalendar(context, provider),
                  
                  const Spacer(),
                  
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
              );
            },
          ),
        ),
      );
  }


  Widget _buildHeader(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Vertically center the Export button
            children: [
              // Left Side: Dropdown Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Select Case",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2), // Tight spacing like the image
                    DropdownButtonHideUnderline(
                      child: DropdownButton2<dynamic>(
                        isExpanded: true,
                        value: provider.selectedCase,
                        // Customizing the display of the selected item
                        selectedItemBuilder: (context) {
                          return provider.allCases.map((caseItem) {
                            return Text(
                              provider.getCaseDisplayName(caseItem),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18, // Slightly larger per screenshot
                                color: Colors.black,
                              ),
                              maxLines: 2, // Allows wrapping for 3+ children
                              overflow: TextOverflow.ellipsis,
                            );
                          }).toList();
                        },
                        items: [
                          ...provider.allCases.map((caseItem) => DropdownMenuItem<dynamic>(
                            value: caseItem,
                            child: Text(
                              provider.getCaseDisplayName(caseItem),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          )),
                          const DropdownMenuItem<dynamic>(
                            value: "add_new",
                            child: Text(
                              "Add New Case",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == "add_new") {
                             Navigator.pushNamed(context, NewEntryScreen.routeName);
                          } else {
                            provider.setSelectedCase(value as CaseModel);
                          }
                        },
                        buttonStyleData: const ButtonStyleData(
                          padding: EdgeInsets.zero,
                          height: 40, // Height to accommodate wrapped text
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
                  ],
                ),
              ),

              const SizedBox(width: 10), // Gap between text and export button

              // Right Side: Export Button
              _buildExportButton(),
            ],
          ),
        );
      },
    );
  }

// Helper for the Export UI
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
            borderRadius: BorderRadius.circular(12),
          ),
          markerSize: 6,
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
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: events.take(3).map((e) {
                Color color;
                switch (e.type) {
                  case EventType.custody: color = Colors.purple; break;
                  case EventType.payment: color = Colors.green; break;
                  case EventType.dispute: color = Colors.orange; break;
                  case EventType.breach: color = Colors.red; break;
                }
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(Icons.circle, size: 6, color: color),
                );
              }).toList(),
            );
          },
        ),
      ),
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
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              
              Text(
                DateFormat('EEEE, MMMM d, y').format(date),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: events.isEmpty 
                  ? const Center(child: Text("No events scheduled.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: controller,
                      itemCount: events.length,
                      itemBuilder: (context, index) => _buildEventCard(events[index]),
                    ),
              ),

              const SizedBox(height: 10),
              _buildActionButton("Add Entry", Icons.add, const Color(0xFF4A148C), Colors.white, true, () {
                 Navigator.pop(context);
                 Navigator.pushNamed(context, NewEntryScreen.routeName);
              }),
              const SizedBox(height: 10),
              _buildActionButton("Add Reminder", Icons.access_time, const Color(0xFF4A148C), const Color(0xFFE1F5FE), false, () {
                Navigator.pop(context); 
                Navigator.pushNamed(context, NewReminderScreen.routeName);
              }),
              const SizedBox(height: 10),
              _buildActionButton("View Events", Icons.calendar_today, const Color(0xFF4A148C), const Color(0xFFE1F5FE), false, () {
                 Navigator.pop(context); 
                 _showEventsPopup(context, date, events); 
              }),
              const SizedBox(height: 20),
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
              const Text("Calendar legends", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 10),
          _buildLegendItem("Custody", Icons.person, Colors.purple),
          _buildLegendItem("Payments", Icons.payment, Colors.green),
          _buildLegendItem("Breach of Orders", Icons.cancel_presentation, Colors.red),
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
    IconData icon = _getIconForType(event.type);
    
    // Customize text based on type (Mocking for visuals)
    String tagText = event.type.name[0].toUpperCase() + event.type.name.substring(1); // e.g., "Custody"
    if (event.type == EventType.payment) tagText = "Repeat Weekly"; // Match screenshot example

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 10),
                  const Icon(Icons.delete, color: Colors.red, size: 20),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (event.type == EventType.custody) ...[
                 Icon(Icons.person, size: 16, color: typeColor),
                 const SizedBox(width: 5),
              ],
              Text("21 Jun 2025", style: TextStyle(color: Colors.grey[800], fontSize: 13)), // Mock start date
              if (event.type == EventType.payment) ...[
                 const Spacer(),
                 Text("21 July 2025", style: TextStyle(color: Colors.grey[800], fontSize: 13)), // Mock end date
              ] else ...[
                 const SizedBox(width: 10),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(color: lightColor, borderRadius: BorderRadius.circular(8)),
                   child: Text(tagText, style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                 )
              ]
            ],
          ),
          if (event.type == EventType.payment) ...[
             const SizedBox(height: 10),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
               child: Text(tagText, style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
             )
          ],
          if (event.description != null && event.type != EventType.payment) ...[
             const SizedBox(height: 8),
             Text(event.description!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ]
        ],
      ),
    );
  }

  // --- 4. Action Button Builder ---
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
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 15),
          if (events.isEmpty)
            const Text("No events found.")
          else
            Column(
              children: events.map((e) => _buildEventCard(e)).toList(),
            )
        ],
      ),
    );
  }

  Color _getColorForType(EventType type) {
    switch (type) {
      case EventType.custody: return Colors.purple;
      case EventType.payment: return Colors.blue; // Matches "Repeat Weekly" tag blue
      case EventType.dispute: return Colors.orange;
      case EventType.breach: return Colors.red;
    }
  }

  IconData _getIconForType(EventType type) {
    switch (type) {
      case EventType.custody: return Icons.person;
      case EventType.payment: return Icons.payment;
      case EventType.dispute: return Icons.warning;
      case EventType.breach: return Icons.cancel;
    }
  }
}