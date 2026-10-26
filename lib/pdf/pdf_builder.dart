import 'dart:io';
import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/document.dart';
import '../models/settings.dart';
import '../theme/app_theme.dart';
import '../utils/amount_words.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import '../utils/doc_summary.dart';
import 'pdf_fonts.dart';

/// Renders a document exactly as the design draws its printed page: the
/// letterhead, the work itemised with units and rates, the total spelled out
/// in words, and how to pay. Quotations, invoices and receipts share one
/// layout — only the wording and the reference rows differ.
///
/// Every size below is the design's own px value passed through [_px]. The
/// design lays the page out on a 390px card with 14px side padding — a
/// ~362px column — and A4 at 34pt margins gives 527pt, so one design px is
/// 527 / 362 ≈ 1.456pt. Writing sizes this way keeps each one checkable
/// against the design's markup instead of tuned by eye.
///
/// Laid out as a MultiPage so a long job flows onto as many sheets as it
/// needs: the column header repeats, and the summary tail is kept atomic so
/// the totals and terms never split from each other.
class PdfBuilder {
  static const double _scale = 527 / 362;
  static double _px(double designPx) => designPx * _scale;

  static PdfColor _c(int argb) => PdfColor.fromInt(argb);

  /// The design's `color-mix(accent N%, white)`: [amount] of the brand
  /// colour, the rest white.
  static PdfColor _mix(PdfColor base, double amount) => PdfColor(
        base.red + (1 - base.red) * (1 - amount),
        base.green + (1 - base.green) * (1 - amount),
        base.blue + (1 - base.blue) * (1 - amount),
      );

  // The design's text colours, by hex.
  static final PdfColor _ink = _c(0xFF141414);
  static final PdfColor _body = _c(0xFF44443F);
  static final PdfColor _rowInk = _c(0xFF2D2D29);
  static final PdfColor _vat = _c(0xFF55554F);
  static final PdfColor _muted = _c(0xFF6B6B66);
  static final PdfColor _red = _c(0xFFB3261E);
  static final PdfColor _wordsBg = _c(0xFFECECEA);
  static final PdfColor _cellRule = _c(0xFFECECEA);
  static final PdfColor _stampGreen = _c(AppTheme.stamp.toARGB32());
  static final PdfColor _momoYellow = _c(0xFFFFCB05);
  static final PdfColor _momoInk = _c(0xFF0B3B5C);
  static final PdfColor _airtelRed = _c(0xFFE40000);

  static late PdfFonts _fonts;

  /// A text style in the design's terms: a px size, a CSS weight, and
  /// whether it is set in the mono face. Letter spacing is given in em, as
  /// the design writes it.
  static pw.TextStyle _t(
    double designPx, {
    int weight = 400,
    bool mono = false,
    PdfColor? color,
    double letterSpacingEm = 0,
    double lineHeight = 1.2,
  }) {
    final size = _px(designPx);
    final pw.Font font;
    if (mono) {
      font = weight >= 600 ? _fonts.monoBold : _fonts.mono;
    } else if (weight >= 900) {
      font = _fonts.sansBlack;
    } else if (weight >= 700) {
      font = _fonts.sansBold;
    } else if (weight >= 600) {
      font = _fonts.sansSemiBold;
    } else {
      font = _fonts.sans;
    }
    return pw.TextStyle(
      font: font,
      fontBold: font,
      fontSize: size,
      color: color ?? _ink,
      letterSpacing: letterSpacingEm * size,
      lineSpacing: math.max(0, (lineHeight - 1.2) * size),
    );
  }

  static Future<pw.Document> build(DocumentModel doc, BusinessSettings settings) async {
    _fonts = await PdfFonts.load();

    final accent = _c(settings.brandColor.toARGB32());

    pw.MemoryImage? logo;
    final logoPath = settings.logoPath;
    if (logoPath != null) {
      final file = File(logoPath);
      if (await file.exists()) {
        logo = pw.MemoryImage(await file.readAsBytes());
      }
    }

    final payBox = payBoxFor(doc, settings.payDetails);
    final notes = doc.notes.trim();
    final terms = settings.terms.trim();
    final word = AppTheme.typeStyle(doc.type).word;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        maxPages: 200,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.fromLTRB(34, _px(18), 34, _px(12)),
          theme: pw.ThemeData.withFont(base: _fonts.sans, bold: _fonts.sansBold),
          buildBackground: (context) => _watermark(settings, accent),
        ),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Padding(
                padding: pw.EdgeInsets.only(bottom: _px(8)),
                child: pw.Text('$word ${doc.number} (continued)',
                    style: _t(6.5, color: _muted, mono: true)),
              ),
        footer: (context) => _footer(doc, settings, accent, context),
        build: (context) => [
          _letterhead(settings, logo, accent),
          pw.SizedBox(height: _px(14)),
          _recipientAndReference(doc, settings, accent, word),
          pw.SizedBox(height: _px(14)),
          _itemsTable(doc, accent),
          pw.Container(height: _px(9), color: _mix(accent, 0.22)),
          pw.Inseparable(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: _px(9)),
                _stampAndTotals(doc, settings, accent),
                pw.SizedBox(height: _px(14)),
                _termsAndWords(doc, settings, accent, terms),
                if (notes.isNotEmpty) ...[
                  pw.SizedBox(height: _px(10)),
                  pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Notes: ', style: _t(6.5, weight: 800)),
                      pw.TextSpan(
                        text: notes,
                        style: _t(6.5, color: _body, lineHeight: 1.5),
                      ),
                    ]),
                  ),
                ],
                pw.SizedBox(height: _px(14)),
                _payAndPreparedBy(settings, accent, payBox),
              ],
            ),
          ),
        ],
      ),
    );
    return pdf;
  }

  /// The business initial, 300px and 4.5% strong, centred across and 46%
  /// down the sheet, as the design places it. The faintness is mixed into
  /// the colour rather than applied as an Opacity: the pdf package draws an
  /// Opacity as a transparency group, which printed as solid grey blocks.
  static pw.Widget _watermark(BusinessSettings settings, PdfColor accent) {
    final name = settings.businessName.trim();
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Align(
        alignment: const pw.Alignment(0, -0.08),
        child: pw.Text(
          name.isEmpty ? 'J' : name[0].toUpperCase(),
          style: _t(300, weight: 900, color: _mix(accent, 0.045), lineHeight: 1),
        ),
      ),
    );
  }

  /// Logo and trading name, then the three-column contact row.
  static pw.Widget _letterhead(
    BusinessSettings settings,
    pw.MemoryImage? logo,
    PdfColor accent,
  ) {
    final name = settings.businessName.trim();
    final initial = name.isEmpty ? 'J' : name[0].toUpperCase();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            logo != null
                ? pw.SizedBox(
                    width: _px(46),
                    height: _px(46),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  )
                : pw.Container(
                    width: _px(46),
                    height: _px(46),
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: accent,
                      borderRadius: pw.BorderRadius.circular(_px(6)),
                    ),
                    child: pw.Text(initial,
                        style: _t(24, weight: 900, color: PdfColors.white)),
                  ),
            pw.SizedBox(width: _px(10)),
            pw.Expanded(
              child: pw.Text(
                name.isEmpty ? 'YOUR BUSINESS' : name.toUpperCase(),
                style: _t(16,
                    weight: 900, color: accent, letterSpacingEm: 0.07, lineHeight: 1.1),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: _px(8)),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _contactCell(accent, _Mark.pin, [settings.location], flex: 115),
            pw.SizedBox(width: _px(6)),
            _contactCell(accent, _Mark.square, [settings.phone, settings.preparedPhone],
                flex: 100, mono: true),
            pw.SizedBox(width: _px(6)),
            _contactCell(accent, _Mark.ring, [settings.businessEmail, settings.tagline],
                flex: 120),
          ],
        ),
      ],
    );
  }

  /// One contact column: a 9px brand mark, then its lines at 6.5px.
  static pw.Widget _contactCell(
    PdfColor accent,
    _Mark mark,
    List<String> lines, {
    required int flex,
    bool mono = false,
  }) {
    final shown = lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    return pw.Expanded(
      flex: flex,
      child: shown.isEmpty
          ? pw.SizedBox.shrink()
          : pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: _px(1)),
                  child: _markShape(mark, accent),
                ),
                pw.SizedBox(width: _px(4)),
                pw.Expanded(
                  child: pw.Text(
                    shown.join('\n'),
                    style: _t(6.5, color: _body, mono: mono, lineHeight: 1.45),
                  ),
                ),
              ],
            ),
    );
  }

  /// The three marks the design uses in place of icons: a map pin (a square
  /// rounded on three corners, turned 45°), a rounded square, and a ring.
  static pw.Widget _markShape(_Mark mark, PdfColor accent) {
    final size = _px(9);
    switch (mark) {
      case _Mark.pin:
        final r = pw.Radius.circular(size / 2);
        return pw.SizedBox(
          width: size,
          height: size,
          child: pw.Transform.rotate(
            angle: math.pi / 4,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius:
                    pw.BorderRadius.only(topLeft: r, topRight: r, bottomRight: r),
              ),
            ),
          ),
        );
      case _Mark.square:
        return pw.Container(
          width: size,
          height: size,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(_px(2)),
          ),
        );
      case _Mark.ring:
        return pw.Container(
          width: size,
          height: size,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: accent, width: _px(2)),
          ),
        );
    }
  }

  /// Who it is for, with the trailing rule beneath, on the left; the
  /// document word and its reference grid on the right.
  static pw.Widget _recipientAndReference(
    DocumentModel doc,
    BusinessSettings settings,
    PdfColor accent,
    String word,
  ) {
    final contact = [doc.clientPhone, doc.clientLocation]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Padding(
            padding: pw.EdgeInsets.only(top: _px(20)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.RichText(
                  text: pw.TextSpan(children: [
                    pw.TextSpan(
                        text: '${recipientLabel(doc.type)} ', style: _t(9, color: _red)),
                    pw.TextSpan(text: doc.clientName, style: _t(9, weight: 800)),
                  ]),
                ),
                if (contact.isNotEmpty) ...[
                  pw.SizedBox(height: _px(2)),
                  pw.Text(contact, style: _t(6.5, mono: true, color: _muted)),
                ],
                pw.SizedBox(height: _px(7)),
                _recipientFlourish(accent),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: _px(10)),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(word, style: _t(11, weight: 900, letterSpacingEm: 0.02)),
            pw.SizedBox(height: _px(5)),
            // grid-template-columns: auto auto, values right-aligned so
            // they all end on one edge.
            pw.Table(
              columnWidths: const {
                0: pw.IntrinsicColumnWidth(),
                1: pw.IntrinsicColumnWidth(),
              },
              children: [
                for (final row in pdfMetaRows(doc, settings))
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.only(bottom: _px(3)),
                        child: pw.Text(row.key, style: _t(7.5, color: _body)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.only(left: _px(10), bottom: _px(3)),
                        child: pw.Text(
                          row.value,
                          textAlign: pw.TextAlign.right,
                          style: _t(7.5, weight: 700, mono: true, color: _red),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// The rule under the recipient, 82% of the column wide, in the design's
  /// four segments: a long line, a 4px dot, an 18px stub turned 20° and
  /// dropped 3px, then a shorter line dropped 6px — so it trails away.
  static pw.Widget _recipientFlourish(PdfColor accent) {
    pw.Widget line() => pw.Container(height: _px(1), color: accent);

    return pw.Row(
      children: [
        pw.Expanded(
          flex: 82,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(flex: 10, child: line()),
              _dot(accent),
              pw.Transform.translate(
                offset: PdfPoint(0, -_px(3)),
                child: pw.Transform.rotate(
                  angle: -20 * math.pi / 180,
                  child: pw.SizedBox(width: _px(18), child: line()),
                ),
              ),
              pw.Expanded(
                flex: 6,
                child: pw.Transform.translate(
                  offset: PdfPoint(0, -_px(6)),
                  child: line(),
                ),
              ),
            ],
          ),
        ),
        pw.Spacer(flex: 18),
      ],
    );
  }

  static pw.Widget _dot(PdfColor accent) => pw.Container(
        width: _px(4),
        height: _px(4),
        decoration: pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle),
      );

  /// The items table: 16px · 1fr · 22px · 30px · 44px · 52px columns, the
  /// header tinted 22% of brand, each row ruled at 30%.
  static pw.Widget _itemsTable(DocumentModel doc, PdfColor accent) {
    final rowRule = _mix(accent, 0.30);

    pw.Widget th(String text, {pw.TextAlign align = pw.TextAlign.left, bool divider = false}) {
      return pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: _px(3), vertical: _px(5)),
        decoration: divider
            ? pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: PdfColors.white, width: _px(1))))
            : null,
        child: pw.Text(text, textAlign: align, style: _t(6.8, weight: 800)),
      );
    }

    pw.Widget td(
      String text, {
      pw.TextAlign align = pw.TextAlign.left,
      int weight = 400,
      bool mono = false,
      bool divider = false,
    }) {
      return pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: _px(3), vertical: _px(4)),
        decoration: divider
            ? pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: _cellRule, width: _px(1))))
            : null,
        child: pw.Text(text,
            textAlign: align, style: _t(6.5, weight: weight, mono: mono, color: _rowInk)),
      );
    }

    return pw.Table(
      columnWidths: {
        // 16px in the design, where CSS lets "No." overflow its cell; the
        // PDF wraps instead, so the column gets just enough to hold it.
        0: pw.FixedColumnWidth(_px(20)),
        1: const pw.FlexColumnWidth(1),
        2: pw.FixedColumnWidth(_px(22)),
        3: pw.FixedColumnWidth(_px(30)),
        4: pw.FixedColumnWidth(_px(44)),
        5: pw.FixedColumnWidth(_px(52)),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: _mix(accent, 0.22)),
          children: [
            th('No.'),
            th('Description'),
            th('QTY', align: pw.TextAlign.center),
            th('Units', divider: true),
            th('Rate', divider: true),
            th('Amount', align: pw.TextAlign.right),
          ],
        ),
        for (int i = 0; i < doc.lines.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: rowRule, width: _px(1))),
            ),
            children: [
              td('${i + 1}'),
              td(doc.lines[i].description.toUpperCase()),
              td(_qty(doc.lines[i].quantity), align: pw.TextAlign.center, weight: 700),
              td(unitOf(doc.lines[i]), divider: true),
              td(formatAmount(doc.lines[i].unitPrice),
                  weight: 700, mono: true, divider: true),
              td(formatAmount(doc.lines[i].amount), align: pw.TextAlign.right, mono: true),
            ],
          ),
      ],
    );
  }

  /// The left 40% holds the PAID stamp when there is one; the totals grid —
  /// label · currency · amount, three auto columns — sits on the right.
  static pw.Widget _stampAndTotals(
    DocumentModel doc,
    BusinessSettings settings,
    PdfColor accent,
  ) {
    final currency = settings.currency;
    pw.Widget cell(String text, pw.TextStyle style, {bool right = false, bool gap = false}) =>
        pw.Padding(
          padding: pw.EdgeInsets.only(left: gap ? _px(12) : 0, bottom: _px(3)),
          child: pw.Text(text,
              textAlign: right ? pw.TextAlign.right : pw.TextAlign.left, style: style),
        );

    final vatLabel =
        doc.vatEnabled ? 'VAT ${(doc.vatRate * 100).toStringAsFixed(0)}%' : 'VAT';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: doc.isSettled
              ? pw.Padding(
                  padding: pw.EdgeInsets.only(left: _px(4)),
                  child: _paidStamp(doc),
                )
              : pw.SizedBox.shrink(),
        ),
        pw.Table(
          columnWidths: const {
            0: pw.IntrinsicColumnWidth(),
            1: pw.IntrinsicColumnWidth(),
            2: pw.IntrinsicColumnWidth(),
          },
          children: [
            pw.TableRow(children: [
              cell('SUB TOTAL', _t(7.5, weight: 800)),
              cell(currency, _t(7.5, weight: 800), gap: true),
              cell(formatAmount(doc.subtotal), _t(7.5, weight: 800, mono: true),
                  right: true, gap: true),
            ]),
            pw.TableRow(children: [
              cell(vatLabel, _t(7.5, weight: 600, color: _vat)),
              cell(currency, _t(7.5, weight: 600, color: _vat), gap: true),
              cell(formatAmount(doc.vatAmount), _t(7.5, weight: 600, mono: true, color: _vat),
                  right: true, gap: true),
            ]),
            pw.TableRow(
              verticalAlignment: pw.TableCellVerticalAlignment.bottom,
              children: [
                cell(pdfTotalWord(doc), _t(7.5, weight: 800)),
                cell(currency, _t(7.5, weight: 800), gap: true),
                cell(formatAmount(doc.total), _t(9, weight: 800, mono: true, color: accent),
                    right: true, gap: true),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Terms in the left 42% behind a 2.5px brand rule; the total spelled out
  /// in a grey box on the right.
  static pw.Widget _termsAndWords(
    DocumentModel doc,
    BusinessSettings settings,
    PdfColor accent,
    String terms,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 42,
          child: pw.Container(
            padding: pw.EdgeInsets.only(left: _px(6)),
            decoration: pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: accent, width: _px(2.5))),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('Terms and Conditions', style: _t(7.5, weight: 800)),
                if (terms.isNotEmpty) ...[
                  pw.SizedBox(height: _px(2)),
                  pw.Text(terms, style: _t(6.5, color: _body, lineHeight: 1.5)),
                ],
              ],
            ),
          ),
        ),
        pw.SizedBox(width: _px(10)),
        pw.Expanded(
          flex: 58,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.only(top: _px(7)),
                child: pw.Text('Amount in words:', style: _t(7, weight: 800, color: _body)),
              ),
              pw.SizedBox(width: _px(6)),
              pw.Expanded(
                child: pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: _px(7), vertical: _px(6)),
                  decoration: pw.BoxDecoration(
                    color: _wordsBg,
                    borderRadius: pw.BorderRadius.circular(_px(4)),
                  ),
                  child: pw.Text(
                    amountInWords(doc.total, settings.currency),
                    style: _t(7.5, color: _rowInk, lineHeight: 1.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Mobile money on the left — both provider tiles, their USSD codes and
  /// merchant numbers, then the bank details and reference — and who
  /// prepared it on the right, aligned to the bottom.
  static pw.Widget _payAndPreparedBy(
    BusinessSettings settings,
    PdfColor accent,
    ({String title, String body})? payBox,
  ) {
    final preparedName = settings.preparedName.trim();
    final preparedPhone = settings.preparedPhone.trim();
    final business = settings.businessName.trim();

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        payBox == null
            ? pw.SizedBox.shrink()
            : pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(payBox.title, style: _t(8, weight: 800)),
                  pw.SizedBox(height: _px(6)),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _moneyTile('MoMo', '(*165*3#)', settings.momoCode.trim(),
                          background: _momoYellow, foreground: _momoInk, labelPx: 8),
                      pw.SizedBox(width: _px(10)),
                      _moneyTile('airtel', '(*185*9#)', settings.airtelCode.trim(),
                          background: _airtelRed, foreground: PdfColors.white, labelPx: 7.5),
                    ],
                  ),
                  pw.SizedBox(height: _px(5)),
                  pw.SizedBox(
                    width: _px(150),
                    child: pw.Text(payBox.body,
                        style: _t(6.5, color: _body, lineHeight: 1.5)),
                  ),
                ],
              ),
        pw.SizedBox(width: _px(10)),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text('PREPARED BY', style: _t(8, weight: 900, color: accent)),
            if (preparedName.isNotEmpty) ...[
              pw.SizedBox(height: _px(3)),
              pw.Text(
                preparedPhone.isEmpty ? preparedName : '$preparedName ($preparedPhone)',
                style: _t(6.5, weight: 700),
              ),
            ],
            pw.SizedBox(height: _px(1)),
            pw.Text('For ${business.isEmpty ? 'this business' : business}',
                style: _t(6.5, color: _body)),
          ],
        ),
      ],
    );
  }

  /// One provider: the 34px tile, the USSD code to dial, the merchant code.
  static pw.Widget _moneyTile(
    String label,
    String ussd,
    String code, {
    required PdfColor background,
    required PdfColor foreground,
    required double labelPx,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: _px(34),
          height: _px(34),
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: background,
            borderRadius: pw.BorderRadius.circular(_px(4)),
          ),
          child: pw.Text(label, style: _t(labelPx, weight: 900, color: foreground)),
        ),
        pw.SizedBox(height: _px(3)),
        pw.Text(ussd, style: _t(6, mono: true, color: _body)),
        if (code.isNotEmpty) ...[
          pw.SizedBox(height: _px(3)),
          pw.Text(code, style: _t(6.5, weight: 700, mono: true)),
        ],
      ],
    );
  }

  /// The footer rule from 52% across — dot, line, dot, then a half-length
  /// line lifted 4px — over the issued-by line and the page count.
  static pw.Widget _footer(
    DocumentModel doc,
    BusinessSettings settings,
    PdfColor accent,
    pw.Context context,
  ) {
    final business = settings.businessName.trim();
    final pages = 'page ${context.pageNumber} of ${context.pagesCount}';

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            pw.Spacer(flex: 52),
            pw.Expanded(
              flex: 48,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _dot(accent),
                  pw.Expanded(flex: 10, child: pw.Container(height: _px(1), color: accent)),
                  _dot(accent),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Transform.translate(
                      offset: PdfPoint(0, _px(4)),
                      child: pw.Container(height: _px(1), color: accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: _px(5)),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${doc.number} · issued by ${business.isEmpty ? 'this business' : business} · $pages',
              style: _t(6.5, mono: true, color: _muted),
            ),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: _t(6.5, weight: 700)),
          ],
        ),
      ],
    );
  }

  /// The PAID mark: a 3px green border, turned 11° anticlockwise, with the
  /// date the money arrived beneath the word.
  static pw.Widget _paidStamp(DocumentModel doc) {
    final stamped = doc.type == DocType.invoice ? (doc.paidOn ?? doc.date) : doc.date;
    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Transform.rotate(
        angle: 11 * math.pi / 180,
        child: pw.Container(
          padding: pw.EdgeInsets.fromLTRB(_px(11), _px(5), _px(11), _px(6)),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _stampGreen, width: _px(3)),
            borderRadius: pw.BorderRadius.circular(_px(4)),
          ),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('PAID',
                  style: _t(20,
                      weight: 900, color: _stampGreen, letterSpacingEm: 0.16, lineHeight: 1)),
              pw.SizedBox(height: _px(2)),
              pw.Text(formatDocDate(stamped),
                  style: _t(6, mono: true, color: _stampGreen, letterSpacingEm: 0.1)),
            ],
          ),
        ),
      ),
    );
  }

  static String _qty(double quantity) =>
      quantity == quantity.roundToDouble() ? quantity.toStringAsFixed(0) : quantity.toString();
}

/// The three marks the contact row uses in place of icons.
enum _Mark { pin, square, ring }
