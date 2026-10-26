import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:digiflect_quotes/models/client.dart';
import 'package:digiflect_quotes/models/document.dart';
import 'package:digiflect_quotes/models/line_item.dart';
import 'package:digiflect_quotes/models/settings.dart';
import 'package:digiflect_quotes/state/app_state.dart';
import 'package:digiflect_quotes/theme/app_theme.dart';

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = await Directory.systemTemp.createTemp('jobslip_lifecycle');
    return dir.path;
  }
}

DateTime _daysAgo(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days);
}

DocumentModel _invoice({
  required DocStatus status,
  required DateTime due,
  String number = 'DIG-INV-0001',
  String id = 'i1',
}) => DocumentModel(
  id: id,
  type: DocType.invoice,
  status: status,
  number: number,
  date: _daysAgo(20),
  clientId: 'c1',
  clientName: 'Nakawa Hardware',
  clientPhone: '+256 701 445 902',
  clientLocation: 'Nakawa',
  lines: [LineItem(id: 'l1', description: 'Call-out', quantity: 1, unitPrice: 100000)],
  vatEnabled: false,
  vatRate: 0.18,
  dueDays: 14,
  dueDate: due,
);

Future<AppState> _loadedState() async {
  final appState = AppState();
  await appState.load();
  await appState.updateSettings(appState.settings.clone()..businessName = 'Digiflect Tech');
  return appState;
}

List<LineItem> _lines() => [
  LineItem(id: 'x', description: 'Camera, installed', quantity: 2, unitPrice: 185000),
];

void main() {
  PathProviderPlatform.instance = _FakePathProvider();

  group('overdue is derived, never stored', () {
    test('an unpaid invoice past its due date is overdue', () {
      final doc = _invoice(status: DocStatus.unpaid, due: _daysAgo(9));
      expect(doc.isOverdue(), isTrue);
      expect(doc.daysPastDue(), 9);
      expect(AppTheme.statusStyle(doc).label, 'OVERDUE');
    });

    test('an invoice due today is not yet overdue', () {
      final doc = _invoice(status: DocStatus.unpaid, due: _daysAgo(0));
      expect(doc.isOverdue(), isFalse);
      expect(doc.daysPastDue(), 0);
      expect(AppTheme.statusStyle(doc).label, 'UNPAID');
    });

    test('a paid invoice is never overdue, however late it was', () {
      final doc = _invoice(status: DocStatus.paid, due: _daysAgo(60));
      expect(doc.isOverdue(), isFalse);
      expect(doc.isSettled, isTrue);
      expect(AppTheme.statusStyle(doc).label, 'PAID');
    });

    test('only unpaid invoices count as money owed', () {
      expect(_invoice(status: DocStatus.unpaid, due: _daysAgo(1)).isOutstanding, isTrue);
      expect(_invoice(status: DocStatus.paid, due: _daysAgo(1)).isOutstanding, isFalse);
    });
  });

  group('v1 documents still load', () {
    test('a document written before invoices existed keeps its data', () {
      // Exactly the keys v1 wrote - no notes, due date, method or links.
      final v1 = {
        'id': 'd-0042',
        'type': 'quotation',
        'status': 'sent',
        'number': 'DGF-Q-0042',
        'date': '2026-08-02T00:00:00.000',
        'clientId': 'c-brightstar',
        'clientName': 'Bright Star Academy',
        'clientPhone': '+256 772 118 340',
        'clientLocation': 'Kireka',
        'lines': [
          {'id': 'l1', 'description': 'Dome camera', 'quantity': 6, 'unitPrice': 185000},
        ],
        'vatEnabled': true,
        'vatRate': 0.18,
      };

      final doc = DocumentModel.fromJson(v1);
      expect(doc.number, 'DGF-Q-0042');
      expect(doc.type, DocType.quotation);
      expect(doc.total, closeTo(185000 * 6 * 1.18, 0.01));
      expect(doc.notes, isEmpty);
      expect(doc.dueDate, isNull);
      expect(doc.invoiceNumber, isNull);
      expect(doc.isOverdue(), isFalse);
    });

    test('settings written before v2 pick up sane defaults', () {
      final v1 = {
        'businessName': 'Digiflect',
        'tagline': 'CCTV',
        'phone': '+256 772 000 000',
        'location': 'Kampala',
        'brandColorIndex': 0,
        'chargeVat': true,
        'vatRate': 0.18,
        'currency': 'UGX',
        'quoteSeq': 42,
        'receiptSeq': 18,
        'terms': 'Valid 14 days',
      };

      final settings = BusinessSettings.fromJson(v1);
      expect(settings.quoteSeq, 42);
      expect(settings.invoiceSeq, 0);
      expect(settings.payDetails, isEmpty);
      expect(settings.dueDefaultDays, 14);
      expect(settings.lastBackupAt, isNull);
    });
  });

  group('numbering', () {
    test('each type runs its own sequence with its own code', () async {
      final appState = await _loadedState();
      final client = appState.findOrCreateClient(name: 'Mrs. Achieng', phone: '', location: '');

      final quote = await appState.createDocument(
        type: DocType.quotation,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );
      final invoice = await appState.createDocument(
        type: DocType.invoice,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );
      final receipt = await appState.createDocument(
        type: DocType.receipt,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );

      expect(quote.number, 'DIG-Q-0001');
      expect(invoice.number, 'DIG-INV-0001');
      expect(receipt.number, 'DIG-R-0001');
      expect(appState.previewNextNumber(DocType.invoice), 'DIG-INV-0002');
    });

    test('a deleted number is not reissued', () async {
      final appState = await _loadedState();
      final client = appState.findOrCreateClient(name: 'Gulu Road Lodge', phone: '', location: '');
      final first = await appState.createDocument(
        type: DocType.quotation,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );

      await appState.deleteDocument(first.id);
      final second = await appState.createDocument(
        type: DocType.quotation,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );

      expect(first.number, 'DIG-Q-0001');
      expect(second.number, 'DIG-Q-0002');
    });
  });

  group('the client said yes', () {
    test('converting a quote to an invoice links both ways', () async {
      final appState = await _loadedState();
      final client = appState.findOrCreateClient(name: 'Nakawa Hardware', phone: '', location: '');
      final quote = await appState.createDocument(
        type: DocType.quotation,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );

      final invoice = await appState.convertQuote(quote.id, into: DocType.invoice);

      expect(invoice.type, DocType.invoice);
      expect(invoice.status, DocStatus.unpaid);
      expect(invoice.fromNumber, quote.number);
      expect(invoice.dueDate, isNotNull);
      expect(quote.status, DocStatus.invoiced);
      expect(quote.invoiceNumber, invoice.number);
      // The lines are copied, not shared, so editing one cannot alter the other.
      expect(invoice.lines.first.id, isNot(quote.lines.first.id));
      expect(invoice.total, quote.total);
    });

    test('converting straight to a receipt marks the quote receipted', () async {
      final appState = await _loadedState();
      final client = appState.findOrCreateClient(name: 'Mrs. Achieng', phone: '', location: '');
      final quote = await appState.createDocument(
        type: DocType.quotation,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );

      final receipt = await appState.convertQuote(
        quote.id,
        into: DocType.receipt,
        method: 'MTN MoMo',
      );

      expect(receipt.type, DocType.receipt);
      expect(receipt.method, 'MTN MoMo');
      expect(receipt.isSettled, isTrue);
      expect(quote.status, DocStatus.receipted);
      expect(quote.receiptNumber, receipt.number);
    });
  });

  group('recording a payment', () {
    test('settles the invoice and issues the matching receipt', () async {
      final appState = await _loadedState();
      final client = appState.findOrCreateClient(name: 'Gulu Road Lodge', phone: '', location: '');
      final invoice = await appState.createDocument(
        type: DocType.invoice,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );

      final receipt = await appState.recordPayment(invoice.id, method: 'Bank');

      expect(receipt, isNotNull);
      expect(invoice.status, DocStatus.paid);
      expect(invoice.paidOn, isNotNull);
      expect(invoice.method, 'Bank');
      expect(invoice.receiptNumber, receipt!.number);
      expect(receipt.fromNumber, invoice.number);
      expect(appState.owedTotal, 0);
    });

    test('can settle without a receipt when the client does not want one', () async {
      final appState = await _loadedState();
      final client = appState.findOrCreateClient(name: 'Nakawa Hardware', phone: '', location: '');
      final invoice = await appState.createDocument(
        type: DocType.invoice,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );

      final receipt = await appState.recordPayment(
        invoice.id,
        method: 'Cash',
        alsoIssueReceipt: false,
      );

      expect(receipt, isNull);
      expect(invoice.status, DocStatus.paid);
      expect(invoice.receiptNumber, isNull);
      expect(appState.ofType(DocType.receipt), isEmpty);
    });

    test('marking it unpaid again undoes the payment', () async {
      final appState = await _loadedState();
      final client = appState.findOrCreateClient(name: 'Nakawa Hardware', phone: '', location: '');
      final invoice = await appState.createDocument(
        type: DocType.invoice,
        client: client,
        lines: _lines(),
        vatEnabled: false,
      );
      await appState.recordPayment(invoice.id, method: 'Cash', alsoIssueReceipt: false);

      await appState.markUnpaid(invoice.id);

      expect(invoice.status, DocStatus.unpaid);
      expect(invoice.paidOn, isNull);
      expect(invoice.method, isNull);
      expect(appState.owedTotal, invoice.total);
    });
  });

  group('the books', () {
    test('owed, overdue and collected add up the right documents', () async {
      final appState = await _loadedState();
      final nakawa = Client(id: 'c1', name: 'Nakawa Hardware', phone: '', location: '');
      appState.clients = [nakawa];
      appState.documents = [
        _invoice(status: DocStatus.unpaid, due: _daysAgo(9), number: 'DIG-INV-0001'),
        _invoice(status: DocStatus.unpaid, due: _daysAgo(-5), number: 'DIG-INV-0002', id: 'i2'),
      ];

      expect(appState.unpaidInvoices, hasLength(2));
      expect(appState.overdueInvoices, hasLength(1));
      expect(appState.owedTotal, 200000);
      expect(appState.overdueTotal, 100000);
      // A client with anything late is flagged as overdue, not merely owing.
      expect(appState.outstandingFor('c1'), 200000);
      expect(appState.hasOverdueFor('c1'), isTrue);
    });

    test('what needs a nudge puts the late ones first', () async {
      final appState = await _loadedState();
      final late = _invoice(status: DocStatus.unpaid, due: _daysAgo(20), number: 'DIG-INV-0001');
      final soon = _invoice(
        status: DocStatus.unpaid,
        due: _daysAgo(-3),
        number: 'DIG-INV-0002',
        id: 'i2',
      );
      appState.documents = [soon, late];

      final attention = appState.attentionList();
      expect(attention.first.number, 'DIG-INV-0001');
    });
  });
}
