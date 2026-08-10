import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../pdf/pdf_builder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import '../widgets/status_badge.dart';
import 'line_items_editor_screen.dart';
import 'pdf_preview_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String docId;

  const DocumentDetailScreen({super.key, required this.docId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _sharing = false;

  Future<void> _quickShare(DocumentModel doc, AppState appState) async {
    setState(() => _sharing = true);
    try {
      final pdf = await PdfBuilder.build(doc, appState.settings);
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: '${doc.number}.pdf');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _editLines(DocumentModel doc, AppState appState) async {
    final result = await Navigator.of(context).push<LineItemsResult>(
      MaterialPageRoute(
        builder: (_) => LineItemsEditorScreen(
          title: doc.clientName,
          subtitleLabel: doc.number,
          initialLines: doc.lines,
          initialVatEnabled: doc.vatEnabled,
          isReceipt: doc.type == DocType.receipt,
          initialPaid: doc.status == DocStatus.paid,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await appState.updateLines(doc.id, result.lines, result.vatEnabled);
    if (doc.type == DocType.receipt) {
      await appState.setStatus(doc.id, result.paid ? DocStatus.paid : DocStatus.draft);
    }
    if (!mounted) return;
    if (result.makePdf) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PdfPreviewScreen(doc: doc)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final doc = appState.documents.firstWhere((d) => d.id == widget.docId);
    final currency = appState.settings.currency;
    final isQuotation = doc.type == DocType.quotation;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _sharing ? null : () => _quickShare(doc, appState),
                    child: const Text('Share'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  TypeTag(label: isQuotation ? 'QUOTATION' : 'RECEIPT'),
                  const SizedBox(height: 10),
                  Text('${doc.number} · ${formatDocDate(doc.date)}',
                      style: AppTheme.mono(fontSize: 11.5, color: AppTheme.subtleText)),
                  const SizedBox(height: 4),
                  Text(doc.clientName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${doc.clientPhone} · ${doc.clientLocation}',
                      style: AppTheme.mono(fontSize: 12, color: AppTheme.subtleText)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        for (final line in doc.lines) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(line.description,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                      Text(
                                        '${line.quantity == line.quantity.roundToDouble() ? line.quantity.toStringAsFixed(0) : line.quantity} × $currency ${formatAmount(line.unitPrice)}',
                                        style: AppTheme.mono(fontSize: 11, color: AppTheme.subtleText),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(formatMoney(line.amount, currency),
                                    style: AppTheme.mono(fontWeight: FontWeight.w700, fontSize: 13)),
                              ],
                            ),
                          ),
                          const Divider(),
                        ],
                        const SizedBox(height: 4),
                        _row('Subtotal', formatMoney(doc.subtotal, currency)),
                        const SizedBox(height: 6),
                        _row(
                          doc.vatEnabled ? 'VAT ${(doc.vatRate * 100).toStringAsFixed(0)}%' : 'VAT (not charged)',
                          formatMoney(doc.vatAmount, currency),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: AppTheme.ink, thickness: 1.2, height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              doc.status == DocStatus.paid ? 'PAID IN FULL' : 'TOTAL DUE',
                              style: AppTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                            Text(formatMoney(doc.total, currency),
                                style: AppTheme.mono(fontSize: 19, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PdfPreviewScreen(doc: doc)),
                      ),
                      child: const Text('Preview the PDF'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._statusActions(doc, appState),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () => _editLines(doc, appState),
                      child: const Text('Edit lines'),
                    ),
                  ),
                  if (appState.settings.terms.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      appState.settings.terms,
                      style: AppTheme.mono(fontSize: 11, color: AppTheme.subtleText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.subtleText, fontSize: 13)),
        Text(value, style: AppTheme.mono(fontSize: 13, color: AppTheme.subtleText)),
      ],
    );
  }

  List<Widget> _statusActions(DocumentModel doc, AppState appState) {
    Widget outlined(String label, VoidCallback onTap, {bool accent = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onTap,
            style: accent
                ? OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  )
                : null,
            child: Text(label),
          ),
        ),
      );
    }

    if (doc.status == DocStatus.paid) {
      return [outlined('Paid — back to draft', () => appState.setStatus(doc.id, DocStatus.draft))];
    }

    if (doc.type == DocType.receipt) {
      // draft receipt
      return [outlined('Mark as paid', () => appState.setStatus(doc.id, DocStatus.paid))];
    }

    // quotation, draft or sent
    final widgets = <Widget>[];
    if (doc.status == DocStatus.draft) {
      widgets.add(outlined('Mark as sent', () => appState.setStatus(doc.id, DocStatus.sent)));
    } else {
      widgets.add(outlined('Mark as paid', () => appState.setStatus(doc.id, DocStatus.paid)));
    }
    widgets.add(outlined('Job paid → turn into a receipt', () async {
      final receipt = await appState.convertToReceipt(doc.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DocumentDetailScreen(docId: receipt.id)),
      );
    }, accent: true));
    return widgets;
  }
}
