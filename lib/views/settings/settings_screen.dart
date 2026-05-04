
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/provider/setting_provider.dart';
import 'package:clearcase/views/home/case_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/scheduled_dates_screen.dart';
import '../widgets/custom_dialog.dart';

class SettingsScreen extends StatelessWidget {
  static const routeName = '/settings';
  const SettingsScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
        builder: (context, provider, child) {
          return Scaffold(
              backgroundColor: const Color(0xFFF5F5F5),
              body: SafeArea(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                  color: const Color(0xFF4A148C),
                  onRefresh: () => provider.refreshData(),
                  child: SingleChildScrollView(
                     physics: const AlwaysScrollableScrollPhysics(
                       parent: BouncingScrollPhysics(),
                     ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                        const SizedBox(height: 20),

                        // 1. User Profile Card
                        _buildProfileCard(provider),
                        const SizedBox(height: 20),

                        // 2. Notifications Section
                        _buildNotificationSection(context, provider),
                        const SizedBox(height: 25),

                        const Text("Cases", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 15),

                        // 3. Cases List (Real Data)
                        if (provider.cases.isEmpty)
                          const Text("No cases found", style: TextStyle(color: Colors.grey)),

                        ...provider.cases.map((caseItem) => _buildCaseItem(context, provider, caseItem)),

                        const SizedBox(height: 10),

                        // 4. Add New Case Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              side: const BorderSide(color: Color(0xFF4A148C)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, CaseSetupScreen.routeName);
                            },
                            child: const Text("Add New Case", style: TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),

                        const SizedBox(height: 25),
                        const Text("Legal Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 15),

                        _buildLegalButton(
                            "Terms & Conditions",
                            "https://docs.google.com/document/d/19_TmhTBYzsrhPEviQk6IMptCLSPhJfHN4ihuBcdiZJI/edit?usp=sharing"
                        ),
                        const SizedBox(height: 12),
                        // 2. Privacy Policy
                        _buildLegalButton(
                            "Privacy Policy",
                            "https://docs.google.com/document/d/1M0pHs1VBdUwnaNqog1H_HpkRE5mqAfxcn_F3_Sd0laA/edit?usp=sharing"
                        ),

                        const SizedBox(height: 25),

                        // 6. Delete Account Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            ),
                            onPressed: () => _showDeleteAccountConfirmation(context, provider),
                            child: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // 7. Logout Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A148C),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            ),
                            onPressed: () => provider.logout(context),
                            child: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ));
        },
    );
  }

  Widget _buildProfileCard(SettingsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.purple.shade50,
            child: const Icon(Icons.person, color: Colors.purple),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${provider.userProfile?.firstName ?? ''} ${provider.userProfile?.lastName ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(provider.userProfile?.email ?? "No Email", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNotificationSection(BuildContext context, SettingsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Notifications",style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),

          // 1. Scheduled Dates Toggle
          _buildToggleItem(
            title: "Scheduled Dates",
            subtitle: "Get alerts for your custody/payments schedule",
            value: provider.isScheduledDatesEnabled,
            onChanged: provider.toggleScheduledDates,
          ),
          const Divider(height: 30),

          // 2. Reminders Toggle
          _buildToggleItem(
            title: "Reminders",
            subtitle: "Get alerts for your important date",
            value: provider.isRemindersEnabled,
            onChanged: provider.toggleReminders,
          ),
          const Divider(height: 30),

          // 3. Daily Reminder Toggle
          // _buildToggleItem(
          //   title: "Daily Reminder",
          //   subtitle: "Get alerts daily for important date",
          //   value: provider.isDailyReminderEnabled,
          //   onChanged: provider.toggleDailyReminder,
          // ),

          // RESTORED: Daily Time Picker Logic
          // if (provider.isDailyReminderEnabled) ...[
            const SizedBox(height: 20),
            const Text("Daily notification time", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: provider.notificationTime,
                );
                if (picked != null) {
                  provider.updateNotificationTime(picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.notificationTime.format(context), // Shows "09:00 AM" or "21:00" based on phone settings
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Icon(Icons.access_time, size: 18, color: Color(0xFF4A148C)),
                  ],
                ),
              ),
            ),
         ],
      ),
    );
  }

  // Helper widget for clean toggle rows
  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: const Color(0xFF4A148C),
          activeColor: Colors.white,
          onChanged: onChanged,
        ),
      ],
    );
  }
  Widget _buildCaseItem(BuildContext context, SettingsProvider provider, CaseModel caseItem) {
    // Generate names string (e.g., "Alex, Sam") from children list
    String childrenNames = caseItem.children.map((e) => e.name).join(", ");
    if (childrenNames.isEmpty) childrenNames = "No Children Added";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caseItem.caseNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(childrenNames, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                onPressed: () {
                  Navigator.pushNamed(context, ScheduledDatesScreen.routeName,arguments: caseItem.id,);
                },
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () {
                  // Confirm delete logic
                  showDialog(context: context, builder: (ctx) => AlertDialog(
                    title: const Text("Delete Case"),
                    content: const Text("This will permanently delete all records, photos, and documents for this case. This action cannot be undone."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Keep Case")),
                      TextButton(onPressed: () {
                        Navigator.pop(ctx);
                        provider.deleteCase(context, caseItem.id);
                      }, child: const Text("Delete Permanently", style: TextStyle(color: Colors.red))),
                    ],
                  ));
                },
                child: const Icon(Icons.delete, color: Colors.red, size: 20),
              ),
            ],
          )
        ],
      ),
    );
  }


  Widget _buildLegalButton(String title, String urlString) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: BorderSide(color: Colors.blue.shade50),
          ),
        ),
        onPressed: () async {
          // Use the url exactly as it is provided
          final Uri url = Uri.parse(urlString);

          try {
            if (await canLaunchUrl(url)) {
              await launchUrl(
                url,
                mode: LaunchMode.externalApplication,
              );
            } else {
              debugPrint("Could not launch $urlString");
            }
          } catch (e) {
            debugPrint("Error: $e");
          }
        },
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15)),
      ),
    );
  }
  void _showDeleteAccountConfirmation(BuildContext context, SettingsProvider provider) {
    TopPopupDialog.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          const Text(
            "Delete Account?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          const Text(
            "This will permanently remove your profile, all cases, records, and uploaded files. This action cannot be undone.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    provider.deleteUserAccount(context);
                  },
                  child: const Text("Delete All", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}