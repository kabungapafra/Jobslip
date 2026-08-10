import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/document_card.dart';
import 'document_detail_screen.dart';
import 'who_is_this_for_screen.dart';

enum _Filter { all, quotations, receipts }

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currency = appState.settings.currency;

    var docs = appState.documents;
    if (_filter == _Filter.quotations) {
      docs = docs.where((d) => d.type == DocType.quotation).toList();
    } else if (_filter == _Filter.receipts) {
      docs = docs.where((d) => d.type == DocType.receipt).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      docs = docs
          .where((d) => d.clientName.toLowerCase().contains(q) || d.number.toLowerCase().contains(q))
          .toList();
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.settings.businessName.isNotEmpty
                                  ? appState.settings.businessName.toUpperCase()
                                  : 'JOBSLIP',
                              style: AppTheme.mono(
                                  fontSize: 11, color: AppTheme.subtleText, letterSpacing: 1.5),
                            ),
                            const Text('JobSlip',
                                style: TextStyle(
                                    fontFamily: 'ArchivoBlack',
                                    fontSize: 24,
                                    height: 1.1,
                                    letterSpacing: 0.2)),
                          ],
                        ),
                      ),
                      _brandAvatar(appState),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search client or number',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.subtleText),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      _chip('All', _Filter.all),
                      const SizedBox(width: 8),
                      _chip('Quotations', _Filter.quotations),
                      const SizedBox(width: 8),
                      _chip('Receipts', _Filter.receipts),
                    ],
                  ),
                ),
                if (appState.documents.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${appState.documents.length} DOCUMENTS',
                            style: AppTheme.mono(
                                fontSize: 11, color: AppTheme.subtleText, letterSpacing: 0.6)),
                        Text('awaiting ${formatMoney(appState.awaitingTotal, currency)}',
                            style: AppTheme.mono(fontSize: 11, color: AppTheme.subtleText)),
                      ],
                    ),
                  ),
                Expanded(
                  child: appState.documents.isEmpty
                      ? _emptyState(context)
                      : docs.isEmpty
                          ? Center(
                              child: Text('No matches',
                                  style: TextStyle(color: AppTheme.subtleText)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                              itemCount: docs.length,
                              itemBuilder: (context, i) => DocumentCard(
                                doc: docs[i],
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DocumentDetailScreen(docId: docs[i].id),
                                  ),
                                ),
                              ),
                            ),
                ),
              ],
            ),
            if (appState.documents.isNotEmpty)
              Positioned(
                right: 20,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WhoIsThisForScreen()),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.chipBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.description_outlined, color: AppTheme.subtleText),
            ),
            const SizedBox(height: 16),
            const Text('No paperwork yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Finished a CCTV install or a repair? Write the quote here, send the PDF, get paid. Works with no network.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.subtleText, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WhoIsThisForScreen()),
              ),
              child: const Text('Write your first quotation'),
            ),
            if (context.watch<AppState>().settings.businessName.trim().isEmpty) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.read<AppState>().setTab(2),
                child: const Text('Add your business details first'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _brandAvatar(AppState appState) {
    final logoPath = appState.settings.logoPath;
    final hasLogo = logoPath != null && File(logoPath).existsSync();

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hasLogo ? null : AppTheme.chipBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: hasLogo
          ? Image.file(File(logoPath), fit: BoxFit.contain, width: 40, height: 40)
          : Text(
              appState.settings.businessName.isNotEmpty
                  ? appState.settings.businessName
                      .trim()
                      .split(RegExp(r'\s+'))
                      .map((w) => w.isNotEmpty ? w[0] : '')
                      .take(2)
                      .join()
                      .toUpperCase()
                  : 'J',
              style: AppTheme.mono(fontWeight: FontWeight.w700, fontSize: 13),
            ),
    );
  }

  Widget _chip(String label, _Filter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: AppTheme.chipBackground,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.subtleText,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
