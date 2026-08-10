import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import 'status_badge.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;

  const DocumentCard({super.key, required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AppState>().settings.currency;
    final isQuotation = doc.type == DocType.quotation;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TypeTag(label: isQuotation ? 'QUOTATION' : 'RECEIPT'),
                StatusBadge(label: doc.status.name.toUpperCase(), statusKey: doc.status.name),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              doc.clientName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${doc.number} · ${formatDocDate(doc.date)} · ${doc.lines.length} lines',
              style: AppTheme.mono(fontSize: 11.5, color: AppTheme.subtleText),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatMoney(doc.total, currency),
                style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
