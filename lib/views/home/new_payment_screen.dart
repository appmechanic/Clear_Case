
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/payment_model.dart';
import 'package:clearcase/provider/new_entry_provider.dart';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class NewPaymentScreen extends StatefulWidget {
  static const routeName = '/new-payment';
  const NewPaymentScreen({super.key});

  @override
  State<NewPaymentScreen> createState() => _NewPaymentScreenState();
}

class _NewPaymentScreenState extends State<NewPaymentScreen> {
  // Controllers
  final _amountController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountNode = FocusNode();
  final _locationNode = FocusNode();
  final _notesNode = FocusNode();

  // State
  bool paymentReceived = true;
  String paymentTypeToggle = "Additional"; 
  DateTime selectedDate = DateTime.now();
  String selectedPaymentType = "Child Support";
  String selectedPaymentMethod = "Bank Transfer";
  bool flagEntry = false; // Added flag option if needed
  
  // Dropdown Options
  final List<String> paymentTypes = ["Child Support", "School Fees", "Medical", "Other"];
  final List<String> paymentMethods = ["Bank Transfer", "Cash", "Cheque", "Online"];

  @override
  void dispose() {
    _amountController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _amountNode.dispose();
    _locationNode.dispose();
    _notesNode.dispose();
    super.dispose();
  }
  
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  // --- SAVE LOGIC ---
  void _submitForm(NewEntryProvider provider) {
    // 1. Validate Case Selection
    if (provider.selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a case from the top bar")));
      return;
    }

    // 2. Validate Amount
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter an amount")));
      return;
    }
    double? amount = double.tryParse(_amountController.text);
    if (amount == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid amount format")));
       return;
    }

    // 3. Create Model
    final newRecord = PaymentRecordModel(
      caseId: provider.selectedCase!.id,
      amount: amount,
      date: selectedDate,
      paymentType: selectedPaymentType,
      category: paymentTypeToggle, // Additional vs Compulsory
      paymentMethod: selectedPaymentMethod,
      location: _locationController.text.trim(),
      notes: _notesController.text.trim(),
      isReceived: paymentReceived,
      flagEntry: flagEntry,
      createdAt: DateTime.now(),
    );

    // 4. Save via Provider
    provider.addPaymentRecord(context, newRecord);
  }

  @override
  Widget build(BuildContext context) {
    return  Consumer<NewEntryProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            appBar: _buildAppBar(context, provider),
            body: provider.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSwitchTile("Payment Received", paymentReceived, (v) => setState(() => paymentReceived = v)),
                    const SizedBox(height: 15),
                    
                    CustomTextField(
                      labelText: "Amount",
                      hintText: "0.0",
                      isNum: true,
                      controller: _amountController,
                      node: _amountNode,
                      nextNode: _locationNode,
                      borderRadius: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 15),
                    
                    _buildClickableField("Payment Date", DateFormat('dd MMM yyyy').format(selectedDate), Icons.calendar_today, _pickDate),
                    const SizedBox(height: 15),
                    
                    _buildInteractiveDropdown("Payment Type", selectedPaymentType, paymentTypes, (val) => setState(() => selectedPaymentType = val!)),
                    const SizedBox(height: 15),
                    
                    Row(
                      children: [
                        Expanded(child: _buildToggleButton("Additional", paymentTypeToggle == "Additional")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildToggleButton("Compulsory", paymentTypeToggle == "Compulsory")),
                      ],
                    ),
                    const SizedBox(height: 15),
                      
                    _buildInteractiveDropdown("Payment Method", selectedPaymentMethod, paymentMethods, (val) => setState(() => selectedPaymentMethod = val!)),
                    const SizedBox(height: 15),
                    
                    CustomTextField(
                      labelText: "Location",
                      hintText: "Enter Location",
                      controller: _locationController,
                      node: _locationNode,
                      nextNode: _notesNode,
                      borderRadius: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 15),
                      
                    CustomTextField(
                      labelText: "Notes (Optional)",
                      hintText: "Enter Any Additional Details",
                      maxLines: 3,
                      controller: _notesController,
                      node: _notesNode,
                      borderRadius: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    
                    const SizedBox(height: 15),
                     // Optional Flag Switch if needed
                    _buildSwitchTile("Flag this entry", flagEntry, (v) => setState(() => flagEntry = v)),

                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A148C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        onPressed: () => _submitForm(provider),
                        child: const Text("Save Record", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
          );
        },
    );
  }
  
  // --- AppBar with Case Selector ---
  AppBar _buildAppBar(BuildContext context, NewEntryProvider provider) {
    return AppBar(
      title: const Text("New Payment Record", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          color: Colors.grey.shade100,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CaseModel>(
              isExpanded: true,
              hint: const Text("Select a Case"),
              value: provider.selectedCase,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A148C)),
              items: provider.userCases.map((c) => DropdownMenuItem(value: c, child: Text(c.caseNumber, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
              onChanged: (c) {
                provider.selectCase(c);
              },
            ),
          ),
        ),
      ),
    );
  }
  
  // --- Widgets ---
  
  Widget _buildClickableField(String label, String value, IconData icon, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
                Icon(icon, size: 18, color: Colors.grey[700]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Switch(value: value, activeColor: const Color(0xFF4A148C), onChanged: onChanged),
      ],
    );
  }
  
  Widget _buildToggleButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => paymentTypeToggle = text),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A148C).withOpacity(0.1) : Colors.transparent, // Updated to match app theme
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF4A148C) : Colors.grey),
        ),
        child: Text(text, style: TextStyle(color: isSelected ? const Color(0xFF4A148C) : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}