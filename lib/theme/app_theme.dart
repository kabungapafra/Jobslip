import 'package:flutter/material.dart';

import '../models/document.dart';

/// Per-type identity: the words a document is called by, the code used in
/// its number, and the colour pair it is drawn in. Quotes are slate,
/// invoices indigo, receipts green — the same three pairs carry from the
/// list rows through the detail hero to the PDF's accent bar, so a glance
/// at any screen says which of the three you are looking at.
class DocTypeStyle {
  /// Formal name, as it reads on the document itself ("Quotation").
  final String name;

  /// Short name for buttons, titles and tabs ("Quote").
  final String short;

  /// All-caps word printed large on the PDF ("QUOTATION").
  final String word;

  /// All-caps tag on a compact list row ("QUOTE").
  final String tag;

  /// Segment used in the document number ("Q", "INV", "R").
  final String code;

  final Color fg;
  final Color bg;

  const DocTypeStyle({
    required this.name,
    required this.short,
    required this.word,
    required this.tag,
    required this.code,
    required this.fg,
    required this.bg,
  });
}

/// A status pill: the word, its text colour and its fill.
class StatusStyle {
  final String label;
  final Color fg;
  final Color bg;
  const StatusStyle(this.label, this.fg, this.bg);
}

class AppTheme {
  // ---------------- Neutrals ----------------

  static const Color ink = Color(0xFF141414);
  static const Color bodyText = Color(0xFF44443F);
  static const Color subtleText = Color(0xFF6B6B66);

  /// One step lighter than [subtleText] — section captions and metadata
  /// that should recede behind the body copy.
  static const Color mutedText = Color(0xFF8F8F88);
  static const Color faintText = Color(0xFFA3A39C);

  static const Color border = Color(0xFFE4E4E0);
  static const Color strongBorder = Color(0xFFDCDCD7);

  /// Softer than [border] — row separators inside an already-bordered card,
  /// where a full-strength line would read as a second frame.
  static const Color hairline = Color(0xFFF0F0ED);
  static const Color background = Color(0xFFFFFFFF);
  static const Color chipBackground = Color(0xFFF3F3F0);

  /// Fill for inset blocks: totals panels, notes, the share message.
  static const Color panel = Color(0xFFF7F7F5);

  // ---------------- Semantics ----------------

  static const Color danger = Color(0xFFB3261E);
  static const Color success = Color(0xFF1D7347);

  /// Slightly lighter than [success] so the rotated PAID stamp reads as ink
  /// on paper rather than as a solid UI element.
  static const Color stamp = Color(0xFF2E7D4F);

  // ---------------- Document types ----------------

  static const DocTypeStyle quoteStyle = DocTypeStyle(
    name: 'Quotation',
    short: 'Quote',
    word: 'QUOTATION',
    tag: 'QUOTE',
    code: 'Q',
    fg: Color(0xFF3B4656),
    bg: Color(0xFFEDF0F4),
  );

  static const DocTypeStyle invoiceStyle = DocTypeStyle(
    name: 'Invoice',
    short: 'Invoice',
    word: 'INVOICE',
    tag: 'INVOICE',
    code: 'INV',
    fg: Color(0xFF3A43B8),
    bg: Color(0xFFEBEDFB),
  );

  static const DocTypeStyle receiptStyle = DocTypeStyle(
    name: 'Receipt',
    short: 'Receipt',
    word: 'RECEIPT',
    tag: 'RECEIPT',
    code: 'R',
    fg: Color(0xFF1D7347),
    bg: Color(0xFFE4F2EA),
  );

  static DocTypeStyle typeStyle(DocType type) {
    switch (type) {
      case DocType.quotation:
        return quoteStyle;
      case DocType.invoice:
        return invoiceStyle;
      case DocType.receipt:
        return receiptStyle;
    }
  }

  // ---------------- Statuses ----------------

  static const StatusStyle paidStatus = StatusStyle('PAID', Color(0xFF1D7347), Color(0xFFE4F2EA));
  static const StatusStyle overdueStatus = StatusStyle(
    'OVERDUE',
    Color(0xFFB3261E),
    Color(0xFFFBE8E6),
  );
  static const StatusStyle unpaidStatus = StatusStyle(
    'UNPAID',
    Color(0xFF94600A),
    Color(0xFFFBF0DA),
  );
  static const StatusStyle draftStatus = StatusStyle('DRAFT', Color(0xFF6B6B66), Color(0xFFF1F1EF));
  static const StatusStyle sentStatus = StatusStyle('SENT', Color(0xFF3B4656), Color(0xFFEDF0F4));
  static const StatusStyle invoicedStatus = StatusStyle(
    'INVOICED',
    Color(0xFF3A43B8),
    Color(0xFFEBEDFB),
  );

  /// The single place that turns type + status + due date into a pill.
  /// Overdue is decided here rather than stored, so an invoice tips over by
  /// itself the day after it was due.
  static StatusStyle statusStyle(DocumentModel doc, [DateTime? now]) {
    switch (doc.type) {
      case DocType.receipt:
        return paidStatus;
      case DocType.invoice:
        if (doc.status == DocStatus.paid) return paidStatus;
        return doc.isOverdue(now) ? overdueStatus : unpaidStatus;
      case DocType.quotation:
        switch (doc.status) {
          case DocStatus.sent:
            return sentStatus;
          case DocStatus.invoiced:
            return invoicedStatus;
          case DocStatus.receipted:
          case DocStatus.paid:
            return paidStatus;
          default:
            return draftStatus;
        }
    }
  }

  // ---------------- ThemeData ----------------

  static ThemeData build(Color brandColor) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandColor,
        primary: brandColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: strongBorder),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const UnderlineInputBorder(borderSide: BorderSide(color: hairline)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: hairline)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: brandColor, width: 2)),
        hintStyle: const TextStyle(color: mutedText),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      dividerTheme: const DividerThemeData(color: hairline, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );
  }

  /// The design sets small labels, document numbers, dates and money
  /// amounts in a monospaced face while headings and names stay in the
  /// sans-serif — this mirrors that mixed treatment. No font file is
  /// bundled for it: the platform's own monospace is used, which keeps the
  /// app offline and the APK small.
  static TextStyle mono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['RobotoMono', 'Courier'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// The all-caps section caption used above every block of content.
  static TextStyle caption({Color color = mutedText, double fontSize = 11.5}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
      color: color,
    );
  }
}
