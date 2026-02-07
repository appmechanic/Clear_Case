import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewDisputeScreen extends StatefulWidget {
  static const routeName = '/new-dispute';
  const NewDisputeScreen({super.key});

  @override
  State<NewDisputeScreen> createState() => _NewDisputeScreenState();
}

class _NewDisputeScreenState extends State<NewDisputeScreen> {
  final _descController = TextEditingController();
  final _descNode = FocusNode();
  
  DateTime selectedDate = DateTime.now();
  String selectedCategory = "Child Support";
  String selectedParty = "Mother";
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text("New Dispute", style: TextStyle(color: Colors.black)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             _buildClickableField("Date", DateFormat('dd MMM yyyy').format(selectedDate), () async {
                final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2030));
                if(d!=null) setState(()=> selectedDate = d);
             }),
             const SizedBox(height: 15),
             _buildDropdown("Category", selectedCategory, ["Child Support", "Custody Time", "Communication"], (v) => setState(() => selectedCategory = v!)),
             const SizedBox(height: 15),
             
             CustomTextField(
              labelText: "Description",
              hintText: "Describe the dispute in detail.",
              maxLines: 3,
              controller: _descController,
              node: _descNode,
              borderRadius: 8,
              backgroundColor: Colors.grey.shade200,
            ),

             const SizedBox(height: 15),
             _buildDropdown("Related Party", selectedParty, ["Mother", "Father", "Grandparent"], (v) => setState(() => selectedParty = v!)),
             const SizedBox(height: 20),
             _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  Widget _buildClickableField(String label, String value, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 8),
        InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Row(children: [Text(value), const Spacer(), const Icon(Icons.calendar_today, size: 18)])))
    ]);
  }
  
  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, items: items.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: onChanged))),
    ]);
  }
  
  Widget _buildSaveButton() {
     return SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: () {}, child: const Text("Save Record", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))));
  }
}