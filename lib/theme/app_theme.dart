import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF1C1C1A);
  static const Color subtleText = Color(0xFF8A8A85);
  static const Color border = Color(0xFFE6E4DF);
  static const Color background = Color(0xFFFFFFFF);
  static const Color chipBackground = Color(0xFFF3F2ED);
  static const Color draftBadgeBg = Color(0xFFEDEBE5);
  static const Color draftBadgeFg = Color(0xFF6B6A63);
  static const Color sentBadgeBg = Color(0xFFFBE7CE);
  static const Color sentBadgeFg = Color(0xFF9A6520);
  static const Color paidBadgeBg = Color(0xFFDCEEE3);
  static const Color paidBadgeFg = Color(0xFF2C7A4B);

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
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const UnderlineInputBorder(borderSide: BorderSide(color: border)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: border)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: brandColor, width: 2)),
        hintStyle: const TextStyle(color: subtleText),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }

  /// The prototype sets small labels, doc numbers and money amounts in a
  /// monospaced face while headings/names stay in the default sans-serif —
  /// this mirrors that mixed treatment.
  static TextStyle mono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['RobotoMono', 'Courier'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ink,
      letterSpacing: letterSpacing,
    );
  }

  static Color badgeBg(String status) {
    switch (status) {
      case 'sent':
        return sentBadgeBg;
      case 'paid':
        return paidBadgeBg;
      default:
        return draftBadgeBg;
    }
  }

  static Color badgeFg(String status) {
    switch (status) {
      case 'sent':
        return sentBadgeFg;
      case 'paid':
        return paidBadgeFg;
      default:
        return draftBadgeFg;
    }
  }
}
