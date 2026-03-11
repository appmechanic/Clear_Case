import 'dart:io';
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/payment_model.dart';
import 'package:clearcase/provider/new_entry_provider.dart';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/attachment_picker_widget.dart';
import '../widgets/custom_dropdown.dart';

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

  // State Variables
  String? editRecordId;
  bool isInitialized = false;
  bool _isFetching = false;

  bool paymentReceived = true;
  String paymentTypeToggle = "Additional";
  DateTime selectedDate = DateTime.now();
  String selectedPaymentType = "Child Support";
  String selectedPaymentMethod = "Bank Transfer";
  bool flagEntry = false;
  List<File> _selectedFiles = [];
  List<String> _existingAttachmentUrls = [];
  Set<String> selectedChildIds = {};

  // Dropdown Options (Defined inside State class)
  final List<String> paymentTypes = ["Child Support", "School Fees", "Medical", "Other"];
  final List<String> paymentMethods = ["Bank Transfer", "Cash", "Cheque", "Online"];

  @override
  void initState() {
    super.initState();
    // Initialize provider once when the screen is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NewEntryProvider>(context, listen: false).init();
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we passed an ID for editing
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String && !isInitialized) {
      editRecordId = args;
      _loadExistingData();
      isInitialized = true;
    }
  }

  Future<void> _loadExistingData() async {
    // Use listen: false to just get the instance
    final provider = Provider.of<NewEntryProvider>(context, listen: false);

    // Now that we aren't creating a new provider, this will have the actual data
    if (provider.selectedCase == null) return;

    setState(() => _isFetching = true);
    final record = await provider.getPaymentRecordById(editRecordId!);

    if (mounted && record != null) {
      setState(() {
        _isFetching = false;
        _amountController.text = record.amount?.toString() ?? "";
        selectedDate = record.date ?? DateTime.now();
        selectedPaymentType = record.paymentType ?? "";
        paymentTypeToggle = record.category ?? "";
        selectedPaymentMethod = record.paymentMethod ?? "";
        _locationController.text = record.location ?? "";
        _notesController.text = record.notes ?? "";
        paymentReceived = record.isReceived ?? true;
        flagEntry = record.flagEntry ?? false;
        selectedChildIds = Set.from(record.childIds ?? []);
        _existingAttachmentUrls = record.attachmentUrls ?? [];
      });
    } else {
      setState(() => _isFetching = false);
    }
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

  void _submitForm(NewEntryProvider provider) {
    if (provider.selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a case")));
      return;
    }
    double? amount = double.tryParse(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid amount")));
      return;
    }


    final newRecord = PaymentRecordModel(
      id: editRecordId,
      childIds: selectedChildIds.toList(),
      caseId: provider.selectedCase!.id,
      amount: amount,
      date: selectedDate,
      paymentType: selectedPaymentType,
      category: paymentTypeToggle,
      paymentMethod: selectedPaymentMethod,
      location: _locationController.text.trim(),
      notes: _notesController.text.trim(),
      isReceived: paymentReceived,
      flagEntry: flagEntry,
      attachmentUrls: _existingAttachmentUrls,
      createdAt: editRecordId == null ? DateTime.now() : null,
    );

    if (editRecordId == null) {
      provider.addPaymentRecord(context, newRecord, _selectedFiles);
    } else {
      provider.updatePaymentRecord(context, newRecord, _selectedFiles);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    // REMOVED ChangeNotifierProvider from here!
    return Consumer<NewEntryProvider>(
      builder: (context, provider, child) {
        bool showLoader = provider.isLoading || _isFetching;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: _buildAppBar(context, provider),
          body: showLoader
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChildSelector(provider), // Add this first
                    const SizedBox(height: 20),
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
                    const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold)),

                    // Display Existing Attachments from Firebase (Edit Mode)
                    if (_existingAttachmentUrls.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Wrap(
                          spacing: 8,
                          children: _existingAttachmentUrls.map((url) => _buildExistingFilePreview(url)).toList(),
                        ),
                      ),

                    const SizedBox(height: 10),
                     AttachmentPickerWidget(
                      onFilesChanged: (files) {
                        setState(() => _selectedFiles = files);
                      },
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
                        child: Text(editRecordId == null ? "Save Record" : "Update Record", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),                      ),
                    ),
                  ],
                ),
              ),
          );
        },
     );
  }

  Widget _buildExistingFilePreview(String url) {
    bool isPdf = url.toLowerCase().contains('.pdf');
    return Stack(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            image: isPdf ? null : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
          ),
          child: isPdf ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40) : null,
        ),
        Positioned(
          right: -5,
          top: -5,
          child: GestureDetector(
            onTap: () => setState(() => _existingAttachmentUrls.remove(url)),
            child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
          ),
        ),
      ],
    );
  }


  // --- AppBar with Case Selector ---


  AppBar _buildAppBar(BuildContext context, NewEntryProvider provider) {
    return AppBar(
      leading: IconButton(onPressed: (){
        Navigator.pop(context);
      }, icon: Icon(Icons.arrow_back, color: Colors.black)),

      title: Text(editRecordId == null ? "New Payment Record" : "Edit Payment Record",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: CustomDropDown<CaseModel>(
            hint: "Select a Case",
            value: provider.selectedCase,
            items: provider.userCases.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c.caseNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
            )).toList(),
            onChanged: (c) {
              provider.selectCase(c);
              setState(() => selectedChildIds.clear());
            },
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

  Widget _buildChildSelector(NewEntryProvider provider) {
    final children = provider.selectedCase?.children ?? [];
    if (children.isEmpty) return const Text("No children in this case");

    return Column(
      children: children.map((child) {
        final isSelected = selectedChildIds.contains(child.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.purple[50], child: const Icon(Icons.person, color: Colors.purple)),
            title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: const Color(0xFF4A148C)),
            onTap: () => setState(() => isSelected ? selectedChildIds.remove(child.id) : selectedChildIds.add(child.id)),
          ),
        );
      }).toList(),
    );
  }

 }