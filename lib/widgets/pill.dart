import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A tappable pill used for every one-of-many choice in the app: list
/// filters, credit periods, payment methods. Selected means filled in the
/// accent colour it was given; unselected is the neutral chip fill.
class SelectablePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Fill used when selected. Defaults to ink, which is what the design
  /// uses wherever a choice has no type colour of its own.
  final Color? accent;

  /// Stretch to fill the space a Row gives it, for evenly divided rows of
  /// chips such as the due-date picker.
  final bool expand;

  const SelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final fill = accent ?? AppTheme.ink;
    final pill = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: expand ? 4 : 13, vertical: 8),
        alignment: expand ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected ? fill : AppTheme.chipBackground,
          borderRadius: BorderRadius.circular(expand ? 12 : 999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF55554F),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: pill) : pill;
  }
}

/// A square tick box, used for "add VAT" and "also issue a receipt".
class TickBox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final String label;
  final Color accent;
  final double size;

  const TickBox({
    super.key,
    required this.checked,
    required this.onTap,
    required this.label,
    required this.accent,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: checked ? accent : Colors.white,
              border: Border.all(color: checked ? accent : AppTheme.faintText, width: 1.5),
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
            child: checked ? Icon(Icons.check, size: size * 0.65, color: Colors.white) : null,
          ),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF55554F))),
        ],
      ),
    );
  }
}
