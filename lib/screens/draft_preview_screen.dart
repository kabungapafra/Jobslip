import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/document.dart';
import '../models/settings.dart';
import '../pdf/pdf_share.dart';
import '../theme/app_theme.dart';

/// What the user decided while looking at the draft.
enum DraftPreviewResult { keepEditing, save, saveAndSend }

/// Shows the document exactly as it will print, *before* it is saved and
/// before a number is spent on it. The point is that nobody has to commit a
/// quote to find out it reads wrong — you look, go back and fix it, or you
/// save it and send it from here.
class DraftPreviewScreen extends StatefulWidget {
  final DocumentModel draft;
  final BusinessSettings settings;

  const DraftPreviewScreen({super.key, required this.draft, required this.settings});

  @override
  State<DraftPreviewScreen> createState() => _DraftPreviewScreenState();
}

class _DraftPreviewScreenState extends State<DraftPreviewScreen> {
  late final Future<Uint8List> _pending;

  @override
  void initState() {
    super.initState();
    _pending = PdfShare.bytes(widget.draft, widget.settings);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDEA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(DraftPreviewResult.keepEditing),
                    behavior: HitTestBehavior.opaque,
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Keep editing',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'NOT SAVED YET',
                      style: AppTheme.caption(color: AppTheme.subtleText, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: _pending,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          "The preview couldn't be built. Go back and check the "
                          'lines have a description and a price.',
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
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(DraftPreviewResult.save),
                      style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(DraftPreviewResult.saveAndSend),
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                      child: const Text('Save & send'),
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
