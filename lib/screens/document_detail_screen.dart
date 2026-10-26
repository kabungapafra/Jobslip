import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../pdf/pdf_share.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/doc_summary.dart';
import '../widgets/doc_sheets.dart';
import '../widgets/status_badge.dart';
import 'document_editor_screen.dart';
import 'pdf_preview_screen.dart';

/// One document, and everything the user might do about it next. The action
/// list is built from the document's own state, so the screen always offers
/// the one obvious next step — chase it, settle it, or send it again.
class DocumentDetailScreen extends StatefulWidget {
  final String docId;

  /// Set when arriving from the draft preview's "Save & send": the share
  /// sheet opens itself once this screen is on top, so saving and sending
  /// stay one continuous motion instead of two separate errands.
  final bool openShareImmediately;

  const DocumentDetailScreen({super.key, required this.docId, this.openShareImmediately = false});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.openShareImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final doc = _appState.docById(widget.docId);
        if (doc != null) _share(doc);
      });
    }
  }

  AppState get _appState => context.read<AppState>();

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openDoc(String docId) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => DocumentDetailScreen(docId: docId)));
  }

  Future<void> _openPdf() async {
    final doc = _appState.docById(widget.docId);
    if (doc == null || !mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PdfPreviewScreen(docId: doc.id)));
  }

  // ---------------- actions ----------------

  Future<void> _share(DocumentModel doc) async {
    final appState = _appState;
    final settings = appState.settings;
    final message = shareMessage(
      doc,
      businessName: settings.businessName,
      currency: settings.currency,
    );

    final action = await showShareSheet(context, doc: doc, message: message);
    if (action == null || !mounted) return;

    setState(() => _busy = true);
    try {
      switch (action) {
        case ShareAction.send:
          await PdfShare.share(doc, settings, message: message);
          // Sending a draft quote is what makes it sent — the user should
          // not have to tell the app twice.
          if (doc.type == DocType.quotation && doc.status == DocStatus.draft) {
            await appState.setStatus(doc.id, DocStatus.sent);
          }
        case ShareAction.copyMessage:
          await Clipboard.setData(ClipboardData(text: message));
          _toast('Message copied');
        case ShareAction.print:
          await PdfShare.printDoc(doc, settings);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convert(DocumentModel quote) async {
    final appState = _appState;
    final dueDays = appState.settings.dueDefaultDays;
    final into = await showConvertSheet(
      context,
      quoteNumber: quote.number,
      nextInvoiceNumber: appState.previewNextNumber(DocType.invoice),
      nextReceiptNumber: appState.previewNextNumber(DocType.receipt),
      dueDays: dueDays,
      dueDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + dueDays),
    );
    if (into == null || !mounted) return;

    final created = await appState.convertQuote(quote.id, into: into);
    if (!mounted) return;
    _toast('${created.number} made from ${quote.number}');
    _openDoc(created.id);
  }

  Future<void> _recordPayment(DocumentModel invoice) async {
    final appState = _appState;
    final choice = await showPaymentSheet(
      context,
      invoice: invoice,
      currency: appState.settings.currency,
      nextReceiptNumber: appState.previewNextNumber(DocType.receipt),
      initialMethod: invoice.method,
    );
    if (choice == null || !mounted) return;

    final receipt = await appState.recordPayment(
      invoice.id,
      method: choice.method,
      alsoIssueReceipt: choice.issueReceipt,
    );
    if (!mounted) return;
    if (receipt != null) {
      _toast('Paid - receipt ${receipt.number} ready to send');
      _openDoc(receipt.id);
    } else {
      _toast('${invoice.number} marked paid');
    }
  }

  Future<void> _issueReceipt(DocumentModel invoice) async {
    final receipt = await _appState.issueReceipt(invoice.id);
    if (!mounted) return;
    _toast('${receipt.number} issued');
    _openDoc(receipt.id);
  }

  Future<void> _edit(DocumentModel doc) async {
    final wantsPdf = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => DocumentEditorScreen.edit(doc)));
    if (wantsPdf == true && mounted) await _openPdf();
  }

  Future<void> _duplicate(DocumentModel doc) async {
    _toast('Copied ${doc.number} - change what you need');
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DocumentEditorScreen.duplicate(doc)));
  }

  Future<void> _delete(DocumentModel doc) async {
    final confirmed = await showDeleteSheet(context, doc.number);
    if (!confirmed || !mounted) return;
    await _appState.deleteDocument(doc.id);
    if (!mounted) return;
    _toast('${doc.number} deleted');
    Navigator.of(context).pop();
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final doc = appState.docById(widget.docId);

    // Deleting from a sheet pops this screen, but a rebuild can still land
    // first — so a missing document renders as empty rather than throwing.
    if (doc == null) return const Scaffold(body: SizedBox.shrink());

    final currency = appState.settings.currency;
    final canEdit =
        !doc.isSettled &&
        !(doc.type == DocType.quotation &&
            (doc.status == DocStatus.invoiced || doc.status == DocStatus.receipted));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(Icons.arrow_back, size: 22),
                  ),
                  const Spacer(),
                  if (canEdit)
                    GestureDetector(
                      onTap: _busy ? null : () => _edit(doc),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Edit',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _busy ? null : () => _delete(doc),
                    behavior: HitTestBehavior.opaque,
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                children: [
                  _hero(doc, currency),
                  ..._links(doc, appState),
                  const SizedBox(height: 14),
                  ..._actions(doc),
                  const SizedBox(height: 18),
                  _itemsCard(doc, currency),
                  if (doc.notes.trim().isNotEmpty) _notesCard(doc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(DocumentModel doc, String currency) {
    final style = AppTheme.typeStyle(doc.type);
    final summary = DocSummary.of(doc);
    final contact = [
      doc.clientPhone,
      doc.clientLocation,
    ].where((s) => s.trim().isNotEmpty).join(' - ');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                style.word,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  color: style.fg,
                ),
              ),
              const Spacer(),
              StatusPill(doc: doc, onColour: true, fontSize: 11),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            doc.clientName,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const SizedBox(height: 3),
          Text(
            '${doc.number} - ${contact.isEmpty ? 'no contact saved' : contact}',
            style: AppTheme.mono(fontSize: 11.5, color: const Color(0xFF55554F)),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(amountCaption(doc), style: AppTheme.caption(color: style.fg, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(
                    formatMoney(doc.total, currency),
                    style: AppTheme.mono(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary.text,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: summary.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The paper trail: where this document came from and what came out of
  /// it. Tapping a link opens that document.
  List<Widget> _links(DocumentModel doc, AppState appState) {
    final entries = <({String label, String number})>[
      if (doc.fromNumber != null) (label: 'Made from', number: doc.fromNumber!),
      if (doc.invoiceNumber != null) (label: 'Invoice', number: doc.invoiceNumber!),
      if (doc.receiptNumber != null) (label: 'Receipt', number: doc.receiptNumber!),
    ];

    return [
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: GestureDetector(
            onTap: () {
              final target = appState.docByNumber(entry.number);
              if (target == null) {
                _toast('${entry.number} was deleted');
              } else {
                _openDoc(target.id);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(entry.label, style: const TextStyle(fontSize: 13, color: Color(0xFF55554F))),
                  const Spacer(),
                  Text(
                    '${entry.number}  >',
                    style: AppTheme.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _numberColour(entry.number),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  /// Colours a linked number by the type its prefix implies, so the link
  /// looks like the document it leads to even before you tap it.
  Color _numberColour(String number) {
    if (number.contains('-INV-')) return AppTheme.invoiceStyle.fg;
    if (number.contains('-R-')) return AppTheme.receiptStyle.fg;
    return AppTheme.quoteStyle.fg;
  }

  List<Widget> _actions(DocumentModel doc) {
    final accent = Theme.of(context).colorScheme.primary;
    final actions = <Widget>[];

    Widget button(String label, VoidCallback? onTap, _ActionKind kind) {
      final (bg, fg, borderColour) = switch (kind) {
        _ActionKind.primary => (accent, Colors.white, accent),
        _ActionKind.green => (AppTheme.success, Colors.white, AppTheme.success),
        _ActionKind.ghost => (Colors.white, AppTheme.subtleText, Colors.white),
        _ActionKind.secondary => (Colors.white, AppTheme.ink, AppTheme.strongBorder),
      };
      return Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: GestureDetector(
          onTap: _busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: borderColour),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
            ),
          ),
        ),
      );
    }

    switch (doc.type) {
      case DocType.quotation:
        if (doc.status == DocStatus.draft || doc.status == DocStatus.sent) {
          actions.add(button('Client said yes  >', () => _convert(doc), _ActionKind.primary));
        }
        actions.add(
          button(
            'Send to client',
            () => _share(doc),
            doc.status == DocStatus.draft ? _ActionKind.primary : _ActionKind.secondary,
          ),
        );
      case DocType.invoice:
        if (doc.status != DocStatus.paid) {
          actions.add(button('Record payment', () => _recordPayment(doc), _ActionKind.green));
          actions.add(
            button(
              doc.isOverdue() ? 'Send a reminder' : 'Send to client',
              () => _share(doc),
              _ActionKind.secondary,
            ),
          );
        } else {
          if (doc.receiptNumber == null) {
            actions.add(button('Issue receipt', () => _issueReceipt(doc), _ActionKind.green));
          }
          actions.add(button('Send to client', () => _share(doc), _ActionKind.secondary));
        }
      case DocType.receipt:
        actions.add(button('Send receipt to client', () => _share(doc), _ActionKind.primary));
    }

    actions.add(button('Preview PDF', _openPdf, _ActionKind.secondary));
    actions.add(button('Use again for another job', () => _duplicate(doc), _ActionKind.secondary));

    if (doc.type == DocType.invoice && doc.status == DocStatus.paid) {
      actions.add(
        button('Mark as unpaid (mistake)', () async {
          await _appState.markUnpaid(doc.id);
          _toast('${doc.number} back to unpaid');
        }, _ActionKind.ghost),
      );
    }
    if (doc.type == DocType.quotation && doc.status == DocStatus.draft) {
      actions.add(
        button('Mark as sent', () async {
          await _appState.setStatus(doc.id, DocStatus.sent);
        }, _ActionKind.ghost),
      );
    }

    return actions;
  }

  Widget _itemsCard(DocumentModel doc, String currency) {
    final vatPercent = (doc.vatRate * 100).toStringAsFixed(0);

    Widget totalRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: Color(0xFF55554F))),
          const Spacer(),
          Text(value, style: AppTheme.mono(fontSize: 13, color: const Color(0xFF55554F))),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final line in doc.lines)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          line.description,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_qty(line.quantity)} x ${formatMoney(line.unitPrice, currency)}',
                          style: AppTheme.mono(fontSize: 11, color: AppTheme.mutedText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatMoney(line.amount, currency),
                    style: AppTheme.mono(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 9),
          totalRow('Subtotal', formatMoney(doc.subtotal, currency)),
          totalRow(
            doc.vatEnabled ? 'VAT $vatPercent%' : 'VAT (not charged)',
            formatMoney(doc.vatAmount, currency),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _notesCard(DocumentModel doc) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JOB NOTES', style: AppTheme.caption(fontSize: 11)),
          const SizedBox(height: 5),
          Text(doc.notes, style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }

  static String _qty(double quantity) =>
      quantity == quantity.roundToDouble() ? quantity.toStringAsFixed(0) : quantity.toString();
}

enum _ActionKind { primary, secondary, green, ghost }
