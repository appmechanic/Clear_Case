import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewBreachScreen extends StatefulWidget {
  static const routeName = '/new-breach';
  const NewBreachScreen({super.key});

  @override
  State<NewBreachScreen> createState() => _NewBreachScreenState();
}

class _NewBreachScreenState extends State<NewBreachScreen> {
  final _descController = TextEditingController();
  final _proofController = TextEditingController();
  final _descNode = FocusNode();
  final _proofNode = FocusNode();
  
  DateTime selectedDate = DateTime.now();
  String selectedType = "Late for pickup/handover";
  String selectedParty = "Mother";
  String severity = "Serious";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text("New Breach of Orders", style: TextStyle(color: Colors.black)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             _buildClickableField("Date", DateFormat('dd MMM yyyy').format(selectedDate), () async {
                 final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2030));
                 if(d!=null) setState(()=> selectedDate = d);
             }),
             const SizedBox(height: 15),
             _buildDropdown("Breach Type", selectedType, ["Late for pickup/handover", "Missed Visit", "Unauthorized Travel"], (v) => setState(() => selectedType = v!)),
             const SizedBox(height: 15),
             
             Align(alignment: Alignment.centerLeft, child: Text("Severity", style: TextStyle(fontWeight: FontWeight.w500))),
             const SizedBox(height: 8),
             Row(
               children: [
                 _buildChip("Serious", Colors.blue),
                 const SizedBox(width: 10),
                 _buildChip("Moderate", Colors.purple),
                 const SizedBox(width: 10),
                 _buildChip("Minor", Colors.purple),
               ],
             ),
             const SizedBox(height: 15),
             
             CustomTextField(
              labelText: "Description",
              hintText: "Describe the breach...",
              maxLines: 3,
              controller: _descController,
              node: _descNode,
              nextNode: _proofNode,
              borderRadius: 8,
              backgroundColor: Colors.grey.shade200,
            ),
             const SizedBox(height: 15),
             _buildDropdown("Related Party", selectedParty, ["Mother", "Father"], (v) => setState(() => selectedParty = v!)),
             const SizedBox(height: 15),
             
             CustomTextField(
              labelText: "Evidence/Proof (Optional)",
              hintText: "Summarize evidence...",
              maxLines: 3,
              controller: _proofController,
              node: _proofNode,
              borderRadius: 8,
              backgroundColor: Colors.grey.shade200,
            ),
             
             const SizedBox(height: 20),
             _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    bool isSelected = severity == label;
    return GestureDetector(
      onTap: () => setState(() => severity = label),
      child: Chip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.blue[900] : Colors.black)),
        backgroundColor: isSelected ? Colors.blue[100] : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey)),
      ),
    );
  }
  
  // Reuse _buildClickableField, _buildDropdown, _buildSaveButton from previous classes
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