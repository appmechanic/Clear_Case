
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/provider/setting_provider.dart';
import 'package:clearcase/views/auth/login_screen.dart';
import 'package:clearcase/views/home/case_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                  : SingleChildScrollView(
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

                          _buildLegalButton("Terms & Conditions"),
                          const SizedBox(height: 12),
                          _buildLegalButton("Privacy Policy"),

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
                              onPressed: () {
                                // Add delete account logic here
                              },
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
          );
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Enable push notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Switch(
                value: provider.pushNotificationsEnabled,
                activeColor: const Color(0xFF4A148C),
                onChanged: provider.toggleNotifications,
              )
            ],
          ),
          const SizedBox(height: 5),
          const Text("Set the time for daily custody notifications", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 15),
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
                    "${provider.notificationTime.hour.toString().padLeft(2, '0')} : ${provider.notificationTime.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Icon(Icons.access_time, size: 18, color: Color(0xFF4A148C)),
                ],
              ),
            ),
          )
        ],
      ),
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
              const Icon(Icons.edit, size: 20),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () {
                  // Confirm delete logic
                  showDialog(context: context, builder: (ctx) => AlertDialog(
                    title: const Text("Delete Case"),
                    content: const Text("Are you sure you want to delete this case?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                      TextButton(onPressed: () {
                        Navigator.pop(ctx);
                        provider.deleteCase(context, caseItem.id);
                      }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
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

  Widget _buildLegalButton(String title) {
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
        onPressed: () {},
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15)),
      ),
    );
  }
}