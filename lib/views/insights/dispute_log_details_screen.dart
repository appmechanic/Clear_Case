import 'package:clearcase/views/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

class DisputeDetailsScreen extends StatefulWidget {
  static const routeName = '/dispute-details';
  const DisputeDetailsScreen({super.key});

  @override
  State<DisputeDetailsScreen> createState() => _DisputeDetailsScreenState();
}

class _DisputeDetailsScreenState extends State<DisputeDetailsScreen> {
  // --- State ---
  bool isClosed = false; 
  int? _selectedLogIndex; // If null, show list. If set, show detail view.

  // Mock Data
  final List<Map<String, String>> logs = [
    {
      "title": "Initial Dispute",
      "date": "12 Jan 2015  12:56 PM",
      "desc": "On August 2nd, 2025, the co-parent failed to return our daughter Emma from the scheduled weekend visit as agreed upon in our custody arrangement. The pickup was scheduled for 6:00 PM at the designated location on Maple Street. \n\nMultiple attempts to contact the co-parent via phone and text message between 6:15 PM and 8:30 PM went unanswered. This violation of the custody schedule caused significant distress..."
    },
    {
      "title": "New evidence",
      "date": "13 Jan 2015  10:00 AM",
      "desc": "Video evidence submitted showing the arrival time was significantly delayed..."
    },
    {
      "title": "Updated log",
      "date": "14 Jan 2015  09:30 AM",
      "desc": "Reply received from party stating traffic conditions caused the delay..."
    },
  ];

  // --- Logic ---
  
  void _handleBack() {
    if (_selectedLogIndex != null) {
      setState(() => _selectedLogIndex = null); // Go back to list
    } else {
      Navigator.pop(context); // Exit screen
    }
  }

  void _nextLog() {
    if (_selectedLogIndex != null && _selectedLogIndex! < logs.length - 1) {
      setState(() => _selectedLogIndex = _selectedLogIndex! + 1);
    }
  }

  void _prevLog() {
    if (_selectedLogIndex != null && _selectedLogIndex! > 0) {
      setState(() => _selectedLogIndex = _selectedLogIndex! - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle Android Hardware Back Button
    return PopScope(
      canPop: _selectedLogIndex == null,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text("Dispute Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _handleBack,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header (Always Visible)
                    _buildHeader(),
                    const SizedBox(height: 20),

                    // Toggle Content: List vs Detail
                    if (_selectedLogIndex == null) 
                      _buildListView() 
                    else 
                      _buildDetailView(),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFFF5F5F5),
              child: _selectedLogIndex == null 
                  ? (isClosed ? _buildReopenButton() : _buildListActionButtons()) 
                  : _buildDetailNavButtons(),
            )
          ],
        ),
      ),
    );
  }

  // --- Views ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Dec 25", style: TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text("Communication", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isClosed ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)
          ),
          child: Text(
            isClosed ? "Closed" : "In Progress",
            style: TextStyle(color: isClosed ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        )
      ],
    );
  }

  Widget _buildListView() {
    return Column(
      children: logs.asMap().entries.map((entry) {
        int idx = entry.key;
        Map<String, String> log = entry.value;
        return GestureDetector(
          onTap: () => setState(() => _selectedLogIndex = idx),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(log['date']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                if (!isClosed)
                  Row(
                    children: [
                      const Icon(Icons.edit, size: 20),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: () => _showDeleteDialog(idx),
                        child: const Icon(Icons.delete, color: Colors.red, size: 20),
                      ),
                    ],
                  )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailView() {
    final log = logs[_selectedLogIndex!];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(log['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (!isClosed)
                Row(children: [
                  const Icon(Icons.edit, size: 20), 
                  const SizedBox(width: 15), 
                  GestureDetector(
                    onTap: () {
                      _showDeleteDialog(_selectedLogIndex!);
                      setState(() => _selectedLogIndex = null); // Go back to list after delete prompt
                    },
                    child: const Icon(Icons.delete, color: Colors.red, size: 20)
                  )
                ]),
            ],
          ),
          const SizedBox(height: 5),
          Text(log['date']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Related Party", style: TextStyle(fontWeight: FontWeight.w600)),
              Text("Father", style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            log['desc']!,
            style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // --- Buttons ---

  Widget _buildListActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
            onPressed: _showNewLogDialog,
            child: const Text("Add New Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
            onPressed: _showCloseDisputeDialog,
            child: const Text("Close Dispute", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildReopenButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
        onPressed: () => setState(() => isClosed = false),
        child: const Text("Reopen Dispute", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildDetailNavButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedLogIndex! > 0 ? const Color(0xFF8E24AA) : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
            ),
            onPressed: _prevLog,
            child: const Text("Previous", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedLogIndex! < logs.length - 1 ? const Color(0xFF4A148C) : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
            ),
            onPressed: _nextLog,
            child: const Text("Next", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // --- Dialogs ---

  void _showNewLogDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("New log", style: TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close, size: 20), onPressed: ()=>Navigator.pop(ctx))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(labelText: "Log Title", hintText: "Enter Log Title", controller: TextEditingController(), node: FocusNode()),
            const SizedBox(height: 10),
            CustomTextField(labelText: "Description", hintText: "Describe the Dispute.", maxLines: 3, controller: TextEditingController(), node: FocusNode()),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border.all(color: Colors.purple.withOpacity(0.3)), borderRadius: BorderRadius.circular(8), color: Colors.purple.withOpacity(0.05)),
              child: Column(children: const [Icon(Icons.upload_file, color: Colors.purple), SizedBox(height: 5), Text("Upload Images or docs", style: TextStyle(fontSize: 12, color: Colors.purple))]),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            onPressed: () {
              // Add mock log
              setState(() => logs.add({"title": "New Log Entry", "date": "Just Now", "desc": "User added description..."}));
              Navigator.pop(ctx);
            },
            child: const Text("Add log", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCloseDisputeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Close Dispute", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to Close this dispute?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
            onPressed: () {
              setState(() => isClosed = true);
              Navigator.pop(ctx);
            },
            child: const Text("Close", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete log", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete this entry?\n${logs[index]['title']}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
            onPressed: () {
              setState(() => logs.removeAt(index));
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}