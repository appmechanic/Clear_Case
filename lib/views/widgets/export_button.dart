import 'package:flutter/material.dart';

class ExportButton extends StatelessWidget {
  final VoidCallback onTap; // பயனர் கிளிக் செய்வதைக் கையாள

  const ExportButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // கிளிக் செய்யும் வசதி
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min, // பட்டன் அளவைச் சுருக்க
          children: [
            Text(
              "Export",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 5),
            Icon(Icons.upload, color: Colors.blue, size: 16),
          ],
        ),
      ),
    );
  }
}