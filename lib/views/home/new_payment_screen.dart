import 'dart:io';
import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/payment_model.dart';
import 'package:clearcase/provider/new_entry_provider.dart';
import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../provider/calender_provider.dart';
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
  bool isDateSetFromArgs = false;

  bool _isLocationLoading = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(context, "Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar(context, "Location permissions are denied.");
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Extracting requested components
        List<String> addressParts = [];
        if (place.street != null && place.street!.isNotEmpty) addressParts.add(place.street!);
        if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
        if (place.country != null && place.country!.isNotEmpty) addressParts.add(place.country!);
        if (place.postalCode != null && place.postalCode!.isNotEmpty) addressParts.add(place.postalCode!);

        setState(() {
          _locationController.text = addressParts.join(", ");
        });
      }
    } catch (e) {
      _showSnackBar(context, "Could not fetch location: $e");
    } finally {
      setState(() => _isLocationLoading = false);
    }
  }
// Small helper for internal class use
  void _showSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // State Variables
  String transactionType = "PaymentReceived"; // "PaymentReceived" | "PaymentPaid"
  String paymentCategory = "Additional"; // Renamed from paymentTypeToggle


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (!isInitialized) {
      if (args is String) {
        // Handle Edit Mode
        editRecordId = args;
        _loadExistingData();
      } else if (args is DateTime && !isDateSetFromArgs) {
        selectedDate = args;
        isDateSetFromArgs = true;
      }
      isInitialized = true;
    }
  }

  Future<void> _loadExistingData() async {
    setState(() => _isFetching = true);
    final entryProvider = Provider.of<NewEntryProvider>(context, listen: false);
    final calProvider = Provider.of<CalendarProvider>(context, listen: false);

    if (calProvider.selectedCase != null && editRecordId != null) {
      final record = await entryProvider.getPaymentRecordById(calProvider.selectedCase!.id, editRecordId!);
      if (mounted && record != null) {
        setState(() {
          _amountController.text = record.amount?.toString() ?? "";
          selectedDate = record.date ?? DateTime.now();
          selectedPaymentType = record.paymentType ?? "Child Support";

          // CORRECTED FALLBACK
          paymentCategory = record.paymentCategory ?? record.paymentCategory ?? "Additional";
          transactionType = record.transactionType ?? (record.isReceived == true ? "PaymentReceived" : "PaymentPaid");

          selectedPaymentMethod = record.paymentMethod ?? "Bank Transfer";
          _locationController.text = record.location ?? "";
          _notesController.text = record.notes ?? "";
          flagEntry = record.flagEntry ?? false;
          selectedChildIds = Set.from(record.childIds ?? []);
          _existingAttachmentUrls = record.attachmentUrls ?? [];
        });
      }
    }
    if (mounted) setState(() => _isFetching = false);
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

  void _submitForm(NewEntryProvider entryProvider, String caseId) {
    double? amount = double.tryParse(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid amount")));
      return;
    }

    final newRecord = PaymentRecordModel(
      id: editRecordId,
      caseId: caseId,
      childIds: selectedChildIds.toList(),
      amount: amount,
      date: selectedDate,
      paymentType: selectedPaymentType,
      paymentCategory: paymentCategory, // New Field
      transactionType: transactionType, // New Field
      paymentMethod: selectedPaymentMethod,
      location: _locationController.text.trim(),
      notes: _notesController.text.trim(),
      isReceived: transactionType == "PaymentReceived", // Keep for legacy if needed
      flagEntry: flagEntry,
      attachmentUrls: _existingAttachmentUrls,
      createdAt: editRecordId == null ? DateTime.now() : null,
    );

    if (editRecordId == null) {
      entryProvider.addPaymentRecord(context, caseId, newRecord, _selectedFiles);
    } else {
      entryProvider.updatePaymentRecord(context, caseId, newRecord, _selectedFiles);
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
    return Consumer2<CalendarProvider, NewEntryProvider>(
      builder: (context, calProvider, entryProvider, child) {
        final selectedCase = calProvider.selectedCase;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(calProvider),
          body: (entryProvider.isLoading || _isFetching)
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChildSelector(selectedCase),
                    const SizedBox(height: 20),
                _buildTransactionToggle(),
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
                    Expanded(child: _buildCategoryButton("Additional", paymentCategory == "Additional")),
                    const SizedBox(width: 10),
                    Expanded(child: _buildCategoryButton("Compulsory", paymentCategory == "Compulsory")),
                  ],
                ),

                    const SizedBox(height: 15),

                    _buildInteractiveDropdown("Payment Method", selectedPaymentMethod, paymentMethods, (val) => setState(() => selectedPaymentMethod = val!)),
                    const SizedBox(height: 15),

                CustomTextField(
                  labelText: "Location",
                  hintText: "Tap to auto-fill or type manually",
                  controller: _locationController,
                  node: FocusNode(),
                  borderRadius: 8,
                  backgroundColor: Colors.grey.shade200,
                  onTap: () {
                    // Only fetch if empty to allow manual editing afterward
                    if (_locationController.text.isEmpty && !_isLocationLoading) {
                      _getCurrentLocation();
                    }
                  },
                ),

                // Status Indicator below the field
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isLocationLoading
                        ? const Row(
                      children: [
                        SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A148C)),
                        ),
                        SizedBox(width: 8),
                        Text("Fetching current location...", style: TextStyle(fontSize: 12, color: Color(0xFF4A148C))),
                      ],
                    )
                        : _locationController.text.isEmpty
                        ? const Text("Tip: Tap field to auto-fill current address", style: TextStyle(fontSize: 11, color: Colors.grey))
                        : GestureDetector(
                      onTap: () => setState(() => _locationController.clear()),
                      child: const Text("Clear location", style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ),
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
                        onPressed: selectedCase == null
                            ? null
                            : () => _submitForm(entryProvider, selectedCase.id),
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

    // Wrap the stack in a SizedBox or Padding to provide a "safe area" for the button
    return Padding(
      padding: const EdgeInsets.only(top: 5, right: 5),
      child: Stack(
        clipBehavior: Clip.none, // <--- CRITICAL: Allows the icon to sit outside the box
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              image: isPdf ? null : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
            ),
            child: isPdf
                ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30)
                : null,
          ),
          Positioned(
            right: -8, // Adjusted to sit nicely on the corner
            top: -8,
            child: GestureDetector(
              onTap: () => setState(() => _existingAttachmentUrls.remove(url)),
              child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close, size: 12, color: Colors.white)
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- AppBar with Case Selector ---


  AppBar _buildAppBar(CalendarProvider calProvider) {
    bool isEditMode = editRecordId != null;

    return AppBar(
      leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black)
      ),
      title: Text(
          !isEditMode ? "New Payment Record" : "Edit Payment Record",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      bottom: PreferredSize(
        // Increased height to 70 to handle potential wrapping without crowding
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: IgnorePointer(
            ignoring: isEditMode,
            child: Opacity(
              opacity: isEditMode ? 0.6 : 1.0,
              child: CustomDropDown<String>(
                hint: "Select a Case",
                value: calProvider.selectedCase?.id,
                items: calProvider.allCases.map((c) {
                  return DropdownMenuItem<String>(
                    value: c.id,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        calProvider.getCaseDisplayName(c), // Displays "Case # (Child Names)"
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                          height: 1.3, // Adds spacing between wrapped lines
                        ),
                        softWrap: true,   // Enables wrapping for multiple children
                        maxLines: null,   // Allows the item to expand vertically
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    final selected = calProvider.allCases.firstWhere((c) => c.id == id);
                    calProvider.setSelectedCase(selected);
                  }
                },
              ),
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

  Widget _buildInteractiveDropdown(
      String label,
      String? value,
      List<String> items,
      Function(String?) onChanged
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)
        ),
        const SizedBox(height: 8),
        // Now using your custom class
        CustomDropDown<String>(
          value: value,
          hint: "Select $label",
          items: items.map((String val) => DropdownMenuItem(
              value: val,
              child: Text(val)
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Switch(value: value, activeTrackColor: const Color(0xFF4A148C),activeThumbColor: Colors.white, onChanged: onChanged),
      ],
    );
  }


  // --- UI NEW TOGGLE WIDGET ---
  Widget _buildTransactionToggle() {
    return Container(
      width: double.infinity,
      height: 55,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F5FE), // Light blue background from your image
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
                "Payment Made",
                transactionType == "PaymentPaid",
                    () => setState(() => transactionType = "PaymentPaid")
            ),
          ),
          Expanded(
            child: _buildToggleButton(
                "Payment Received",
                transactionType == "PaymentReceived",
                    () => setState(() => transactionType = "PaymentReceived")
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          border: isSelected ? Border.all(color: const Color(0xFF4A148C), width: 1.5) : null,
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: const Color(0xFF4A148C),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildChildSelector(CaseModel? selectedCase) {
    if (selectedCase == null) return const Text("Select a case first");

     return Column(
      children: selectedCase.children.map((child) {
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


  Widget _buildCategoryButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => paymentCategory = text),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A148C).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A148C) : Colors.grey.shade400,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? const Color(0xFF4A148C) : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  }