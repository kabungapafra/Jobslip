import 'package:flutter/material.dart';

import '../models/document.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/doc_summary.dart';
import 'status_badge.dart';

/// The bordered row that carries a document in a list: its number, its
/// status, who it is for, the sentence that says where it stands, and the
/// amount. Used by the three list screens and by "needs a nudge" on home.
class DocumentRow extends StatelessWidget {
  final DocumentModel doc;
  final String currency;
  final VoidCallback onTap;

  /// Adds a colour bar down the left and tints the number in the type's
  /// colour. Used on home, where rows of mixed types sit together and need
  /// to be told apart at a glance.
  final bool withAccentBar;

  const DocumentRow({
    super.key,
    required this.doc,
    required this.currency,
    required this.onTap,
    this.withAccentBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = AppTheme.typeStyle(doc.type);
    final summary = DocSummary.of(doc);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE7E7E4)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (withAccentBar) ...[
                Container(
                  width: 6,
                  decoration: BoxDecoration(color: type.fg, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          doc.number,
                          style: AppTheme.mono(
                            fontSize: 11.5,
                            color: withAccentBar ? type.fg : AppTheme.mutedText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(doc: doc),
                        if (!withAccentBar) const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                doc.clientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                summary.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: summary.color),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          formatMoney(doc.total, currency),
                          style: AppTheme.mono(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tighter, borderless row used for "latest" on the home screen: a
/// type tag, the client, the amount, and the status as plain coloured text.
class CompactDocumentRow extends StatelessWidget {
  final DocumentModel doc;
  final String currency;
  final VoidCallback onTap;

  const CompactDocumentRow({
    super.key,
    required this.doc,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = AppTheme.statusStyle(doc);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.hairline)),
        ),
        child: Row(
          children: [
            TypeTag(type: doc.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doc.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(doc.number, style: AppTheme.mono(fontSize: 11, color: AppTheme.mutedText)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatMoney(doc.total, currency),
                  style: AppTheme.mono(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: status.fg,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
