import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../pdf/pdf_builder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class PdfPreviewScreen extends StatefulWidget {
  final DocumentModel doc;

  const PdfPreviewScreen({super.key, required this.doc});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _busy = false;

  Future<Uint8List> _bytes(BuildContext context) async {
    final settings = context.read<AppState>().settings;
    final pdf = await PdfBuilder.build(widget.doc, settings);
    return pdf.save();
  }

  Future<void> _sendToClient() async {
    setState(() => _busy = true);
    try {
      final bytes = await _bytes(context);
      await Printing.sharePdf(bytes: bytes, filename: '${widget.doc.number}.pdf');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      final bytes = await _bytes(context);
      // Opens the system print dialog — works with any printer the phone
      // has a driver/service for (USB, Bluetooth or Wi-Fi thermal
      // receipt printers included), fully offline, no network involved.
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: '${widget.doc.number}.pdf',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232320),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  ),
                  Expanded(
                    child: Text(
                      '${widget.doc.number}.pdf',
                      textAlign: TextAlign.center,
                      style: AppTheme.mono(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: _bytes(context),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: PdfPreview(
                        build: (format) async => snapshot.data!,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        allowPrinting: false,
                        allowSharing: false,
                        useActions: false,
                        scrollViewDecoration: const BoxDecoration(color: Color(0xFF232320)),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _sendToClient,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text('Send to client'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _print,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
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
