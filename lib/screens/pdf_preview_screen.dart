import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../pdf/pdf_share.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/doc_summary.dart';

/// The finished document, exactly as the client will receive it. Shown on
/// paper grey so the page itself reads as a sheet rather than as another
/// app screen.
class PdfPreviewScreen extends StatefulWidget {
  final String docId;

  const PdfPreviewScreen({super.key, required this.docId});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _busy = false;
  Future<Uint8List>? _pending;

  @override
  void initState() {
    super.initState();
    // Built once, not on every rebuild: regenerating the PDF each time the
    // widget rebuilt made the preview flicker and reflow.
    final appState = context.read<AppState>();
    final doc = appState.docById(widget.docId);
    if (doc != null) _pending = PdfShare.bytes(doc, appState.settings);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final doc = appState.docById(widget.docId);
    if (doc == null) return const Scaffold(body: SizedBox.shrink());

    final settings = appState.settings;
    final pending = _pending;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDEA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(Icons.arrow_back, size: 22),
                  ),
                  Expanded(
                    child: Text(
                      '${doc.number}.pdf',
                      textAlign: TextAlign.center,
                      style: AppTheme.mono(fontSize: 12, color: const Color(0xFF55554F)),
                    ),
                  ),
                  const SizedBox(width: 22),
                ],
              ),
            ),
            Expanded(
              child: pending == null
                  ? const SizedBox.shrink()
                  : FutureBuilder<Uint8List>(
                      future: pending,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                "The PDF couldn't be built. Check the document has at "
                                'least one line of work.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.subtleText),
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: PdfPreview(
                            build: (format) async => snapshot.data!,
                            canChangeOrientation: false,
                            canChangePageFormat: false,
                            canDebug: false,
                            allowPrinting: false,
                            allowSharing: false,
                            useActions: false,
                            scrollViewDecoration: const BoxDecoration(color: Color(0xFFEDEDEA)),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => PdfShare.share(
                                doc,
                                settings,
                                message: shareMessage(
                                  doc,
                                  businessName: settings.businessName,
                                  currency: settings.currency,
                                ),
                              ),
                            ),
                      child: const Text('Send to client'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _run(() => PdfShare.printDoc(doc, settings)),
                      style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                      child: const Text('Print'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
