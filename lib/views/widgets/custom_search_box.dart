import 'package:flutter/material.dart';

class CustomSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController controller; // Make required for clear logic
  final VoidCallback? onClear;

  const CustomSearchBar({
    super.key,
    this.hintText = "Search",
    this.onChanged,
    required this.controller,
    this.onClear,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final bool hasText = value.text.isNotEmpty;

        return TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            // Prefix is empty now per your logic change
            prefixIcon: !hasText ? const Icon(Icons.search, color: Colors.grey) : null,
            suffixIcon: hasText
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                  onPressed: () {
                    widget.controller.clear();
                    if (widget.onClear != null) widget.onClear!();
                  },
                ),

              ],
            )
                : null,
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
          ),
        );
      },
    );
  }
}