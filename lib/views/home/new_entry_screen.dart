import 'package:clearcase/views/home/new_breach_screen.dart';
import 'package:clearcase/views/home/new_custody_screen.dart';
import 'package:clearcase/views/home/new_dispute_screen.dart';
import 'package:clearcase/views/home/new_payment_screen.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class NewEntryScreen extends StatelessWidget {
  static const routeName = '/new-entry';

  const NewEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(
        title: const Text("New Entry", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("What type of entry would you like to Create?", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            
            _buildEntryCard(
              context, 
              "Custody Record", 
              "Track child custody and care details", 
              Icons.child_care, 
              Colors.purple,
              () {
                Navigator.pushNamed(context, NewCustodyScreen.routeName);
              }
            ),
            _buildEntryCard(
              context, 
              "Payment Record", 
              "Record child support and expenses", 
              Icons.payment, 
              Colors.green,
              () {
                Navigator.pushNamed(context, NewPaymentScreen.routeName);
              }
            ),
            _buildEntryCard(
              context, 
              "Disputes", 
              "Record communication disputes and conflicts", 
              Icons.warning_amber, 
              Colors.orange,
              () {
                Navigator.pushNamed(context, NewDisputeScreen.routeName);
              }
            ),
            _buildEntryCard(
              context, 
              "Breach Of Orders", 
              "Document violations of court orders", 
              Icons.cancel_outlined, 
              Colors.red,
              () {
                Navigator.pushNamed(context, NewBreachScreen.routeName);
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }
}