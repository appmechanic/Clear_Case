import 'package:flutter/material.dart';

class DeleteEntriesConfirmation extends StatelessWidget {
  final VoidCallback onConfirm;
  final String title;
  final String content;

  const DeleteEntriesConfirmation({
    super.key,
    required this.onConfirm,
    this.title = "Delete Entry",
    this.content = "Are you sure you want to delete this record? This action cannot be undone.",
  });

  static Future<bool?> show(BuildContext context, VoidCallback onConfirm) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DeleteEntriesConfirmation(onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm();
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text("Delete", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}