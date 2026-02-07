import 'package:flutter/material.dart';

class CustodyDetailsScreen extends StatelessWidget {
  static const routeName = '/custody-details';
  const CustodyDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Custody Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top Card (Header Info)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
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
                  Row(
                    children: [
                      _buildTag("Emma", Colors.blue),
                      const SizedBox(width: 8),
                      _buildTag("All Day", Colors.orange),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 15),

            // Main Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("School Pickup", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Row(
                        children: const [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 15),
                          Icon(Icons.delete, color: Colors.red, size: 20),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("12 Jan 2015   12:56 PM", style: TextStyle(color: Colors.black87, fontSize: 13)),
                  const SizedBox(height: 15),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Related Party", style: TextStyle(fontWeight: FontWeight.w600)),
                      Text("Father", style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  const Text(
                    "Regular weekday pickup after school activities and sports practice.",
                    style: TextStyle(color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  
                  // Attachment Thumbnails (Mock Red Squares)
                  Row(
                    children: [
                      _buildThumbnail(),
                      const SizedBox(width: 10),
                      _buildThumbnail(),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
    );
  }
}