import 'dart:io';

import 'package:clearcase/models/case_model.dart';
import 'package:clearcase/models/custody_model.dart';
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


class NewCustodyScreen extends StatefulWidget {
  static const routeName = '/new-custody';
  const NewCustodyScreen({super.key});

  @override
  State<NewCustodyScreen> createState() => _NewCustodyScreenState();
}

class _NewCustodyScreenState extends State<NewCustodyScreen> {
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  String? editRecordId;
  bool isInitialized = false;
  bool _isFetching = false;
  bool isDateSetFromArgs = false;

  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
  bool isScheduled = false;
  bool isFulfilled = true;
  bool flagEntry = false;

  List<File> _selectedFiles = [];
  List<String> _existingAttachmentUrls = [];
  Set<String> selectedChildIds = {};

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
        // Handle Add Mode with passed date
        // Use Future.microtask or check isDateSetFromArgs to prevent
        // overwriting manual selection on rebuilds.
        selectedDate = args;
        isDateSetFromArgs = true;
      }
      isInitialized = true;
    }
  }
    Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
        context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
        context: context, initialTime: isStart ? startTime : endTime);
    if (picked != null) setState(() => isStart ? startTime = picked : endTime = picked);
  }


  Future<void> _loadExistingData() async {
    setState(() => _isFetching = true);
    final entryProvider = Provider.of<NewEntryProvider>(context, listen: false);
    final calProvider = Provider.of<CalendarProvider>(context, listen: false);

    if (calProvider.selectedCase != null && editRecordId != null) {
      // Use the updated provider method that accepts caseId
      final record = await entryProvider.getCustodyRecordById(calProvider.selectedCase!.id, editRecordId!);

      if (mounted && record != null) {
        setState(() {
          selectedDate = record.startDate ?? DateTime.now();
          startTime = TimeOfDay.fromDateTime(record.startTime ?? DateTime.now());
          endTime = TimeOfDay.fromDateTime(record.endTime ?? DateTime.now());
          isScheduled = record.isScheduled ?? false;
          isFulfilled = record.isFulfilled ?? true;
          flagEntry = record.flagEntry ?? false;
          _locationController.text = record.location ?? "";
          _notesController.text = record.notes ?? "";
          selectedChildIds = Set.from(record.childIds ?? []);
          _existingAttachmentUrls = record.attachmentUrls ?? [];
        });
      }
    }
    if (mounted) setState(() => _isFetching = false);
  }

  void _submitForm(NewEntryProvider entryProvider, String caseId) {
    if (selectedChildIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one child")));
      return;
    }
    final startDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
    final endDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime.hour, endTime.minute);


    if (startDateTime.isAtSameMomentAs(endDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Start time and End time cannot be the same.")));
      return;
    }

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End time cannot be before Start time.")));
      return;
    }

    final record = CustodyRecordModel(
      id: editRecordId,
      caseId: caseId,
      childIds: selectedChildIds.toList(),
      startDate: selectedDate,
      startTime: startDateTime,
      endTime: endDateTime,
      isScheduled: isScheduled,
      location: _locationController.text.trim(),
      isFulfilled: isFulfilled,
      notes: _notesController.text.trim(),
      flagEntry: flagEntry,
      createdAt: editRecordId == null ? DateTime.now() : null,
      attachmentUrls: _existingAttachmentUrls,
    );

    if (editRecordId == null) {
      entryProvider.addCustodyRecord(context, caseId, record, _selectedFiles);
    } else {
      entryProvider.updateCustodyRecord(context, caseId, record, _selectedFiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer2 listens to both providers
    return Consumer2<CalendarProvider, NewEntryProvider>(
      builder: (context, calProvider, entryProvider, child) {
        bool showLoader = entryProvider.isLoading || _isFetching;
        final selectedCase = calProvider.selectedCase;

        return Scaffold(
          appBar: _buildAppBar(calProvider),
          body: showLoader
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChildSelector(selectedCase),
                const SizedBox(height: 20),
                _buildClickableField("Start Date", DateFormat('dd MMM yyyy').format(selectedDate), Icons.calendar_today, _pickDate),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _buildClickableField("Start Time", startTime.format(context), Icons.access_time, () => _pickTime(true))),
                  const SizedBox(width: 15),
                  Expanded(child: _buildClickableField("End Time", endTime.format(context), Icons.access_time, () => _pickTime(false))),
                ]),
                const SizedBox(height: 20),
                _buildSwitchTile("It is a scheduled custody date", isScheduled, (v) => setState(() => isScheduled = v)),
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
                _buildSwitchTile("Custody Fulfilled", isFulfilled, (v) => setState(() => isFulfilled = v)),
                const SizedBox(height: 15),
                CustomTextField(labelText: "Notes", hintText: "Enter Additional Details", maxLines: 3, controller: _notesController, node: FocusNode(), borderRadius: 8, backgroundColor: Colors.grey.shade200),
                const SizedBox(height: 20),

                const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // Display Existing Attachments from Firebase (Edit Mode)
                if (_existingAttachmentUrls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 8,
                      children: _existingAttachmentUrls.map((url) => _buildExistingFilePreview(url)).toList(),
                    ),
                  ),

                AttachmentPickerWidget(
                  onFilesChanged: (files) {
                    setState(() => _selectedFiles = files);
                  },
                ),
                const SizedBox(height: 20),
                _buildSwitchTile("Flag this entry", flagEntry, (v) => setState(() => flagEntry = v)),
                const SizedBox(height: 30),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    onPressed: selectedCase == null
                        ? null
                        : () => _submitForm(entryProvider, selectedCase.id),
                    child: Text(editRecordId == null ? "Save Record" : "Update Record", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
              ],
            ),
          ),
        );
      },
    );
  }


  AppBar _buildAppBar(CalendarProvider calProvider) {
    return AppBar(
      title: Text(editRecordId == null ? "New Custody" : "Edit Custody",style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child:Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child:  CustomDropDown<String>( // Note: Change <CaseModel> to <String>
              hint: "Select a Case",
              value: calProvider.selectedCase?.id, // Only pass the ID string
              items: calProvider.allCases.map((c) => DropdownMenuItem(
                value: c.id, // Value is the ID
                child: Text(c.caseNumber),
              )).toList(),
              onChanged: (String? selectedId) {
                // Find the full object based on the ID
                final selectedCase = calProvider.allCases.firstWhere((c) => c.id == selectedId);
                calProvider.setSelectedCase(selectedCase);
              },
            ),
          )
      ),
    );
  }

  Widget _buildChildSelector(CaseModel? selectedCase) {
    if (selectedCase == null) return const Text("Select a case first");
    return  Column(
      children: selectedCase.children.map((child)
    => Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.purple[50], child: const Icon(Icons.person, color: Colors.purple)),
            title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(selectedChildIds.contains(child.id) ?  Icons.radio_button_checked : Icons.radio_button_off, color: const Color(0xFF4A148C)),
            onTap: () => setState(() => selectedChildIds.contains(child.id) ? selectedChildIds.remove(child.id) : selectedChildIds.add(child.id)),
          ),
        )
      ).toList(),
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
  }  Widget _buildClickableField(String l, String v, IconData i, VoidCallback t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontWeight: FontWeight.w500)), const SizedBox(height: 8), InkWell(onTap: t, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Row(children: [Text(v), const Spacer(), Icon(i, size: 18, color: Colors.grey[700])])))]);
  Widget _buildSwitchTile(String t, bool v, Function(bool) c) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), Switch(value: v,activeTrackColor: const Color(0xFF4A148C),activeThumbColor: Colors.white, onChanged: c)]);
}