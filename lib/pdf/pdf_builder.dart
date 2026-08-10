import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/document.dart';
import '../models/settings.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';

class PdfBuilder {
  static final PdfColor _stampRed = PdfColor.fromInt(0xFFC62828);

  static Future<pw.Document> build(DocumentModel doc, BusinessSettings settings) async {
    final pdf = pw.Document();
    final brand = PdfColor.fromInt(settings.brandColor.toARGB32());
    final ink = PdfColor.fromInt(0xFF1F1F1D);
    final subtle = PdfColor.fromInt(0xFF8A8A85);
    final border = PdfColor.fromInt(0xFFE6E4DF);
    final panelBg = PdfColor.fromInt(0xFFF6F5F1);
    final isQuotation = doc.type == DocType.quotation;
    final showPaidStamp = doc.type == DocType.receipt && doc.status == DocStatus.paid;

    pw.MemoryImage? logo;
    final logoPath = settings.logoPath;
    if (logoPath != null) {
      final file = File(logoPath);
      if (await file.exists()) {
        logo = pw.MemoryImage(await file.readAsBytes());
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final content = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (isQuotation)
                ..._quotationHeader(doc, settings, logo, brand: brand, ink: ink, subtle: subtle, panelBg: panelBg)
              else
                ..._receiptHeader(doc, settings, logo, brand: brand, ink: ink, subtle: subtle, panelBg: panelBg),
              pw.SizedBox(height: 20),

              // ---- Items table ----
              pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(4.4),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(1.8),
                    3: pw.FlexColumnWidth(1.8),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: brand),
                      children: [
                        _headerCell('DESCRIPTION', align: pw.TextAlign.left),
                        _headerCell('QTY', align: pw.TextAlign.center),
                        _headerCell('UNIT PRICE', align: pw.TextAlign.right),
                        _headerCell('AMOUNT', align: pw.TextAlign.right),
                      ],
                    ),
                    for (int i = 0; i < doc.lines.length; i++)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : panelBg),
                        children: [
                          _bodyCell(doc.lines[i].description, ink, align: pw.TextAlign.left, bold: true),
                          _bodyCell(
                            doc.lines[i].quantity == doc.lines[i].quantity.roundToDouble()
                                ? doc.lines[i].quantity.toStringAsFixed(0)
                                : doc.lines[i].quantity.toString(),
                            ink,
                            align: pw.TextAlign.center,
                          ),
                          _bodyCell('${settings.currency} ${formatAmount(doc.lines[i].unitPrice)}', subtle,
                              align: pw.TextAlign.right),
                          _bodyCell('${settings.currency} ${formatAmount(doc.lines[i].amount)}', ink,
                              align: pw.TextAlign.right, bold: true),
                        ],
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // ---- Totals ----
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    width: 240,
                    child: pw.Column(
                      children: [
                        _totalRow('Subtotal', formatMoney(doc.subtotal, settings.currency), subtle),
                        pw.SizedBox(height: 5),
                        _totalRow(
                          doc.vatEnabled ? 'VAT ${(doc.vatRate * 100).toStringAsFixed(0)}%' : 'VAT (not charged)',
                          formatMoney(doc.vatAmount, settings.currency),
                          subtle,
                        ),
                        pw.SizedBox(height: 10),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: pw.BoxDecoration(color: brand, borderRadius: pw.BorderRadius.circular(6)),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                doc.status == DocStatus.paid ? 'PAID IN FULL' : 'TOTAL DUE',
                                style: pw.TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                    letterSpacing: 0.6),
                              ),
                              pw.Text(formatMoney(doc.total, settings.currency),
                                  style: pw.TextStyle(
                                      fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showPaidStamp) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: _paidStamp(),
                ),
                pw.SizedBox(height: 6),
              ] else
                pw.SizedBox(height: 26),

              // ---- Terms / thank you ----
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (settings.terms.trim().isNotEmpty)
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TERMS & CONDITIONS',
                              style: pw.TextStyle(fontSize: 8.5, color: subtle, letterSpacing: 1)),
                          pw.SizedBox(height: 4),
                          pw.Text(settings.terms, style: pw.TextStyle(fontSize: 9, color: subtle, lineSpacing: 1.4)),
                        ],
                      ),
                    ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Thank you for your business!',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontStyle: pw.FontStyle.italic,
                                color: brand,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(settings.businessName, style: pw.TextStyle(fontSize: 9, color: subtle)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: border),
              pw.Text(
                '${doc.number} · issued offline by ${settings.businessName} · page 1 of 1',
                style: pw.TextStyle(fontSize: 7.5, color: subtle),
              ),
            ],
          );

          return content;
        },
      ),
    );
    return pdf;
  }

  static pw.Widget _logoBox(pw.MemoryImage? logo, String businessName, PdfColor brand, {double size = 38}) {
    if (logo != null) {
      return pw.Container(
        width: size,
        height: size,
        alignment: pw.Alignment.center,
        child: pw.Image(logo, width: size, height: size, fit: pw.BoxFit.contain),
      );
    }
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(color: brand, borderRadius: pw.BorderRadius.circular(size * 0.24)),
      child: pw.Text(
        businessName.isNotEmpty ? businessName[0].toUpperCase() : 'J',
        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: size * 0.47),
      ),
    );
  }

  /// Centered, stacked-logo layout — mirrors the "construction quotation"
  /// reference the user supplied for quotations.
  static List<pw.Widget> _quotationHeader(
    DocumentModel doc,
    BusinessSettings settings,
    pw.MemoryImage? logo, {
    required PdfColor brand,
    required PdfColor ink,
    required PdfColor subtle,
    required PdfColor panelBg,
  }) {
    return [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _logoBox(logo, settings.businessName, brand, size: 80),
          pw.SizedBox(height: 12),
          pw.Text(settings.businessName,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 19, color: ink)),
          pw.Text(settings.tagline, style: pw.TextStyle(color: subtle, fontSize: 11.5)),
          pw.SizedBox(height: 5),
          pw.Text(settings.phone, style: pw.TextStyle(color: subtle, fontSize: 11)),
          pw.Text(settings.location, style: pw.TextStyle(color: subtle, fontSize: 11)),
        ],
      ),
      pw.SizedBox(height: 22),
      pw.Center(
        child: pw.Text(
          'QUOTATION',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 30, color: brand, letterSpacing: 3),
        ),
      ),
      pw.SizedBox(height: 14),
      pw.Container(height: 2.5, color: brand),
      pw.SizedBox(height: 18),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: panelBg, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TO', style: pw.TextStyle(fontSize: 8.5, color: subtle, letterSpacing: 1.2)),
                  pw.SizedBox(height: 3),
                  pw.Text(doc.clientName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: ink)),
                  pw.Text('${doc.clientPhone} · ${doc.clientLocation}',
                      style: pw.TextStyle(fontSize: 9.5, color: subtle)),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: panelBg, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _labelValue('QUOTATION NO.', doc.number, subtle, ink, align: pw.CrossAxisAlignment.start),
                  pw.SizedBox(height: 8),
                  _labelValue('DATE', formatDocDate(doc.date), subtle, ink, align: pw.CrossAxisAlignment.start),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// Horizontal logo/name lockup with the title top-right — mirrors the
  /// "Sempurna Inc" invoice reference the user supplied for receipts.
  static List<pw.Widget> _receiptHeader(
    DocumentModel doc,
    BusinessSettings settings,
    pw.MemoryImage? logo, {
    required PdfColor brand,
    required PdfColor ink,
    required PdfColor subtle,
    required PdfColor panelBg,
  }) {
    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _logoBox(logo, settings.businessName, brand, size: 52),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(settings.businessName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 17, color: ink)),
                  pw.Text(settings.tagline, style: pw.TextStyle(color: subtle, fontSize: 10.5)),
                  pw.SizedBox(height: 4),
                  pw.Text(settings.phone, style: pw.TextStyle(color: subtle, fontSize: 10)),
                  pw.Text(settings.location, style: pw.TextStyle(color: subtle, fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('RECEIPT',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 26, color: ink, letterSpacing: 1.5)),
              pw.SizedBox(height: 4),
              pw.Text('#${doc.number}', style: pw.TextStyle(color: subtle, fontSize: 9.5)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 20),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RECEIPT TO', style: pw.TextStyle(fontSize: 8.5, color: subtle, letterSpacing: 1.2)),
                pw.SizedBox(height: 3),
                pw.Text(doc.clientName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: ink)),
                pw.Text('${doc.clientPhone} · ${doc.clientLocation}',
                    style: pw.TextStyle(fontSize: 9.5, color: subtle)),
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: pw.BoxDecoration(
                color: panelBg,
                border: pw.Border(left: pw.BorderSide(color: brand, width: 4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _labelValue('RECEIPT NUMBER', doc.number, subtle, ink, align: pw.CrossAxisAlignment.start),
                  pw.SizedBox(height: 8),
                  _labelValue('DATE INFORMATION', formatDocDate(doc.date), subtle, ink,
                      align: pw.CrossAxisAlignment.start),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  static pw.Widget _paidStamp() {
    return pw.Transform.rotate(
      angle: -0.26,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _stampRed, width: 3),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _stampRed, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'PAID',
            style: pw.TextStyle(
              color: _stampRed,
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 5,
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _labelValue(String label, String value, PdfColor subtle, PdfColor ink,
      {required pw.CrossAxisAlignment align}) {
    return pw.Column(
      crossAxisAlignment: align,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 7.5, color: subtle, letterSpacing: 1)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: ink)),
      ],
    );
  }

  static pw.Widget _headerCell(String text, {required pw.TextAlign align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.8),
      ),
    );
  }

  static pw.Widget _bodyCell(String text, PdfColor color, {required pw.TextAlign align, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 10, color: color, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, PdfColor subtle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9.5, color: subtle)),
        pw.Text(value, style: pw.TextStyle(fontSize: 9.5, color: subtle)),
      ],
    );
  }
}
