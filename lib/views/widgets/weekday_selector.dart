import 'package:flutter/material.dart';

/// A row of 7 circular day chips (S M T W T F S) for picking one or more
/// weekdays. Values use Dart's [DateTime.weekday] convention:
/// Monday = 1 ... Sunday = 7.
class WeekdaySelector extends StatelessWidget {
  /// Currently selected weekdays (DateTime.weekday ints).
  final Set<int> selectedDays;

  /// Called with the tapped weekday int to toggle its selection.
  final ValueChanged<int> onToggle;

  const WeekdaySelector({
    super.key,
    required this.selectedDays,
    required this.onToggle,
  });

  // Display order starts on Sunday: (label, DateTime.weekday value)
  static const List<MapEntry<String, int>> _days = [
    MapEntry('S', DateTime.sunday),
    MapEntry('M', DateTime.monday),
    MapEntry('T', DateTime.tuesday),
    MapEntry('W', DateTime.wednesday),
    MapEntry('T', DateTime.thursday),
    MapEntry('F', DateTime.friday),
    MapEntry('S', DateTime.saturday),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _days.map((day) {
        final bool isSelected = selectedDays.contains(day.value);
        return GestureDetector(
          onTap: () => onToggle(day.value),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF4A148C) : const Color(0xFFE1F5FE),
              border: Border.all(color: const Color(0xFF4A148C), width: 1),
            ),
            child: Text(
              day.key,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4A148C),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
