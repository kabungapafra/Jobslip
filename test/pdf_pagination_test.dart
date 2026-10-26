import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/src/pdf/obj/object_stream.dart';
import 'package:digiflect_quotes/models/document.dart';
import 'package:digiflect_quotes/models/line_item.dart';
import 'package:digiflect_quotes/models/settings.dart';
import 'package:digiflect_quotes/pdf/pdf_builder.dart';

BusinessSettings _settings({String terms = 'Payment due within 14 days of invoice date.'}) =>
    BusinessSettings(
      businessName: 'Test Works',
      tagline: 'We build things',
      phone: '+265 999 000 111',
      location: 'Blantyre, Malawi',
      brandColorIndex: 0,
      chargeVat: true,
      vatRate: 0.165,
      currency: 'MWK',
      quoteSeq: 1,
      receiptSeq: 1,
      terms: terms,
      payDetails: 'Mobile money 0999 000 111',
    );

DocumentModel _doc(
  DocType type,
  int lineCount, {
  DocStatus status = DocStatus.sent,
  String? desc,
}) => DocumentModel(
  id: 'd1',
  type: type,
  status: status,
  number: 'TW-Q0001',
  date: DateTime(2026, 8, 31),
  clientId: 'c1',
  clientName: 'Acme Construction Ltd',
  clientPhone: '+265 888 111 222',
  clientLocation: 'Lilongwe',
  lines: [
    for (int i = 0; i < lineCount; i++)
      LineItem(
        id: 'l$i',
        description: desc ?? 'Item${i + 1} supply and install materials',
        quantity: 2,
        unitPrice: 15000,
      ),
  ],
  vatEnabled: true,
  vatRate: 0.165,
);

/// dart_pdf writes show-text as `[(word)]TJ`, so that is what we harvest.
/// Words within a line are emitted as separate runs, which is why assertions
/// below look for single distinctive tokens rather than whole sentences.
final _tj = RegExp(r'\(((?:\\.|[^\\()])*)\)');
final _tjOp = RegExp(r'\[((?:\((?:\\.|[^\\()])*\)|[^\[\]])*)\]\s*TJ');

String _pageText(dynamic page) {
  final raw = StringBuffer();
  for (final c in page.contents) {
    if (c is PdfObjectStream) raw.write(String.fromCharCodes(c.buf.output()));
  }
  final out = StringBuffer();
  for (final m in _tjOp.allMatches(raw.toString())) {
    for (final w in _tj.allMatches(m.group(1)!)) {
      out.write(w.group(1));
      out.write(' ');
    }
  }
  return out.toString();
}

Future<List<String>> _pageTexts(DocumentModel doc, BusinessSettings settings) async {
  final pdf = await PdfBuilder.build(doc, settings);
  await pdf.save();
  return [for (final p in pdf.document.pdfPageList.pages) _pageText(p)];
}

/// Everything on a page except the per-page furniture: the footer, and the
/// "(continued)" line the templates print on sheets after the first.
String _body(String pageText) => pageText
    .replaceAll(RegExp(r'Page \d+ of \d+ ?'), '')
    .replaceAll(RegExp(r'(QUOTATION|INVOICE|RECEIPT) \S+ \(continued\) ?'), '');

/// All three types now share one letterhead, so they all word their totals
/// the same way. Kept as a function so a future divergence has one home.
String _totalsAnchor(DocType type) => 'SUB TOTAL';

void main() {
  // Guards the extractor itself. The previous version of this suite matched
  // `(text) Tj`, an operator dart_pdf never emits, so every assertion below it
  // ran against an empty string and passed no matter how the PDF looked.
  test('page text extraction actually returns text', () async {
    final texts = await _pageTexts(_doc(DocType.quotation, 3), _settings());
    expect(texts, hasLength(1));
    expect(texts.first, contains('ITEM1'));
    expect(texts.first, contains('SUB TOTAL'));
    expect(texts.first, contains('QUOTATION'));
  });

  group('no page is left without substantive content', () {
    for (final type in DocType.values) {
      for (final count in [0, 1, 8, 9, 13, 14, 15, 20, 32, 33, 40, 56, 57, 80, 81, 150]) {
        test('${type.name} with $count items', () async {
          final texts = await _pageTexts(_doc(type, count), _settings());
          for (var i = 0; i < texts.length; i++) {
            final body = _body(texts[i]);
            expect(
              body.contains('SUPPLY') || body.contains(_totalsAnchor(type)),
              isTrue,
              reason:
                  '${type.name}/$count: page ${i + 1} of ${texts.length} carries neither a '
                  'line item nor the totals block — it would print as a near-blank sheet. '
                  'Content: "${body.substring(0, body.length.clamp(0, 120))}"',
            );
          }
        });
      }
    }

    for (final count in [0, 1, 13, 14, 15, 37, 38, 39, 61, 62, 85, 86]) {
      test('paid receipt with $count items', () async {
        final texts = await _pageTexts(
          _doc(DocType.receipt, count, status: DocStatus.paid),
          _settings(),
        );
        for (var i = 0; i < texts.length; i++) {
          final body = _body(texts[i]);
          expect(
            body.contains('SUPPLY') || body.contains(_totalsAnchor(DocType.receipt)),
            isTrue,
            reason: 'paid/$count: page ${i + 1} of ${texts.length} is near-blank',
          );
        }
      });
    }

    test('quotation with no terms configured', () async {
      for (final count in [32, 56, 60]) {
        final texts = await _pageTexts(_doc(DocType.quotation, count), _settings(terms: ''));
        for (var i = 0; i < texts.length; i++) {
          final body = _body(texts[i]);
          expect(
            body.contains('SUPPLY') || body.contains('SUB TOTAL'),
            isTrue,
            reason: 'no-terms/$count: page ${i + 1} of ${texts.length} is near-blank',
          );
        }
      }
    });

    test('descriptions long enough to wrap across several lines', () async {
      final long =
          'Supply deliver and install premium reinforced concrete blocks including all '
              'labour scaffolding curing and site cleanup as agreed in the site meeting ' *
          4;
      for (final type in DocType.values) {
        for (final count in [1, 3, 8, 20]) {
          final texts = await _pageTexts(_doc(type, count, desc: long), _settings());
          for (var i = 0; i < texts.length; i++) {
            final body = _body(texts[i]);
            expect(
              body.contains('SUPPLY') || body.contains('SUB TOTAL'),
              isTrue,
              reason: 'long/${type.name}/$count: page ${i + 1} of ${texts.length} is near-blank',
            );
          }
        }
      }
    });
  });

  group('content survives pagination', () {
    for (final type in DocType.values) {
      for (final count in [1, 15, 40, 120]) {
        test('${type.name} with $count items renders every item exactly once', () async {
          final all = (await _pageTexts(_doc(type, count), _settings())).join(' ');
          for (var i = 1; i <= count; i++) {
            expect(
              RegExp('\\bITEM$i\\b').allMatches(all),
              hasLength(1),
              reason: 'Item$i should appear exactly once across all pages',
            );
          }
        });
      }
    }

    test('the summary block is never duplicated or split', () async {
      for (final type in DocType.values) {
        for (final count in [1, 9, 14, 32, 40, 56, 80]) {
          final texts = await _pageTexts(_doc(type, count), _settings());
          final all = texts.join(' ');
          final anchor = _totalsAnchor(type);
          expect(anchor.allMatches(all), hasLength(1), reason: '${type.name}/$count');
          expect(
            'Terms and Conditions'.allMatches(all),
            hasLength(1),
            reason: '${type.name}/$count',
          );

          // Totals and the terms that close the document must land on the
          // SAME page: that is the guarantee Inseparable buys us.
          final totalsPage = texts.indexWhere((t) => t.contains(anchor));
          final termsPage = texts.indexWhere((t) => t.contains('Terms and Conditions'));
          expect(
            totalsPage,
            equals(termsPage),
            reason:
                '${type.name}/$count: totals on page ${totalsPage + 1} but terms on '
                'page ${termsPage + 1} — the summary tail was split across a page break',
          );
        }
      }
    });

    test('the repeated table header appears on every page the table spans', () async {
      final texts = await _pageTexts(_doc(DocType.quotation, 80), _settings());
      for (var i = 0; i < texts.length; i++) {
        if (texts[i].contains('SUPPLY')) {
          expect(
            texts[i],
            contains('Description'),
            reason: 'page ${i + 1} has items but no column header',
          );
        }
      }
    });
  });

  group('what each type actually prints', () {
    test('an unpaid invoice carries the payment details and no PAID stamp', () async {
      final doc = _doc(DocType.invoice, 3, status: DocStatus.unpaid);
      doc.dueDays = 14;
      doc.dueDate = doc.date.add(const Duration(days: 14));
      final all = (await _pageTexts(doc, _settings())).join(' ');

      expect(all, contains('INVOICE'));
      expect(all, contains('Mobile Money Details'));
      expect(all, contains('Reference'), reason: 'an unpaid document says what to quote');
      expect(all, contains('Issue Date'));
      expect(all, contains('Due Date'));
      expect(all, isNot(contains('PAID')));
    });

    test('a paid invoice carries the PAID stamp instead of payment details', () async {
      final doc = _doc(DocType.invoice, 3, status: DocStatus.paid);
      doc.paidOn = DateTime(2026, 9, 1);
      doc.method = 'MTN MoMo';
      final all = (await _pageTexts(doc, _settings())).join(' ');

      expect(all, contains('PAID'));
      expect(
        all,
        isNot(contains('Mobile Money Details')),
        reason: 'a settled invoice should not ask to be paid again',
      );
    });

    test('a receipt reads as money received', () async {
      final doc = _doc(DocType.receipt, 2, status: DocStatus.paid);
      doc.method = 'Cash';
      final all = (await _pageTexts(doc, _settings())).join(' ');

      expect(all, contains('RECEIPT'));
      expect(all, contains('RECEIVED'));
      expect(all, contains('PAID'));
      expect(all, contains('Received From'));
    });

    test('a quotation states how long it is good for', () async {
      final all = (await _pageTexts(_doc(DocType.quotation, 2), _settings())).join(' ');

      expect(all, contains('QUOTATION'));
      expect(all, contains('Valid'));
      expect(all, isNot(contains('PAID')));
    });

    test('job notes reach the page as the job description', () async {
      final quote = _doc(DocType.quotation, 2);
      quote.notes = 'Scaffolding excluded from this price.';
      final quoteText = (await _pageTexts(quote, _settings())).join(' ');

      expect(quoteText, contains('Notes'));
      expect(quoteText, contains('Scaffolding'));

      // The invoice layout carries the same text under its own heading.
      final invoice = _doc(DocType.invoice, 2, status: DocStatus.unpaid);
      invoice.notes = 'Scaffolding excluded from this price.';
      final invoiceText = (await _pageTexts(invoice, _settings())).join(' ');

      expect(invoiceText, contains('Notes'));
      expect(invoiceText, contains('Scaffolding'));
    });

    test('the amount is spelled out on an invoice', () async {
      final doc = _doc(DocType.invoice, 1, status: DocStatus.unpaid);
      final all = (await _pageTexts(doc, _settings())).join(' ');

      // 2 x 15,000 = 30,000 plus 16.5% VAT = 34,950.
      expect(all, contains('Amount in words'));
      expect(all, contains('Thirty-Four Thousand'));
      expect(all, contains('Only'));
    });
  });

  test('a very large document still paginates rather than overflowing', () async {
    final texts = await _pageTexts(_doc(DocType.quotation, 300), _settings());
    // The exact count belongs to the template, not to the guarantee. What
    // matters is that 300 items spread over many sheets instead of being
    // silently clipped to one.
    expect(texts.length, greaterThan(5));
    final all = texts.join(' ');
    expect(all, contains('ITEM1'));
    expect(all, contains('ITEM300'));
  });
}
