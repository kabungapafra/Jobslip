import 'package:flutter/material.dart';

import '../models/document.dart';
import '../theme/app_theme.dart';

/// The rounded status word on a document — DRAFT, SENT, UNPAID, OVERDUE,
/// PAID. Reads its colours from [AppTheme.statusStyle], so the type and the
/// due date decide the wording in one place.
class StatusPill extends StatelessWidget {
  final DocumentModel doc;
  final double fontSize;

  /// Pills on a coloured hero card sit on white instead of their own tint,
  /// which would disappear into the card behind them.
  final bool onColour;

  const StatusPill({super.key, required this.doc, this.fontSize = 10.5, this.onColour = false});

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.statusStyle(doc);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onColour ? Colors.white : style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: style.fg,
        ),
      ),
    );
  }
}

/// The fixed-width type tag down the left of a compact row: QUOTE,
/// INVOICE, RECEIPT.
class TypeTag extends StatelessWidget {
  final DocType type;
  final double width;

  const TypeTag({super.key, required this.type, this.width = 66});

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.typeStyle(type);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(7)),
      child: Text(
        style.tag,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: style.fg,
        ),
      ),
    );
  }
}

/// An all-caps caption above a block of content.
class SectionCaption extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const SectionCaption(this.text, {super.key, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text, style: AppTheme.caption()),
    );
  }
}
