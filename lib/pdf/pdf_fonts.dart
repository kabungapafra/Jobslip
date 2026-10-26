import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// The two typefaces the printed documents are set in, exactly as the design
/// specifies: Schibsted Grotesk for words, JetBrains Mono for every figure.
/// Both are OFL-licensed and bundled under `assets/fonts/pdf/`, so a PDF
/// renders identically on any phone with no network.
class PdfFonts {
  final pw.Font sans;
  final pw.Font sansSemiBold;
  final pw.Font sansBold;
  final pw.Font sansBlack;
  final pw.Font mono;
  final pw.Font monoBold;

  const PdfFonts({
    required this.sans,
    required this.sansSemiBold,
    required this.sansBold,
    required this.sansBlack,
    required this.mono,
    required this.monoBold,
  });

  static PdfFonts? _cached;

  /// Loads the bundled fonts once and reuses them for every document after.
  ///
  /// If the asset bundle cannot be read — which only happens outside a
  /// running app, such as in a plain unit test — the PDF's built-in faces
  /// are used instead, so a document still renders rather than failing.
  static Future<PdfFonts> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      Future<pw.Font> font(String name) async =>
          pw.Font.ttf(await rootBundle.load('assets/fonts/pdf/$name.ttf'));
      return _cached = PdfFonts(
        sans: await font('SchibstedGrotesk-Regular'),
        sansSemiBold: await font('SchibstedGrotesk-SemiBold'),
        sansBold: await font('SchibstedGrotesk-ExtraBold'),
        sansBlack: await font('SchibstedGrotesk-Black'),
        mono: await font('JetBrainsMono-Regular'),
        monoBold: await font('JetBrainsMono-Bold'),
      );
    } catch (_) {
      return standard();
    }
  }

  /// The PDF format's own built-in faces.
  static PdfFonts standard() => PdfFonts(
        sans: pw.Font.helvetica(),
        sansSemiBold: pw.Font.helveticaBold(),
        sansBold: pw.Font.helveticaBold(),
        sansBlack: pw.Font.helveticaBold(),
        mono: pw.Font.courier(),
        monoBold: pw.Font.courierBold(),
      );
}
