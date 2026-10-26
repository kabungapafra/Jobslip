import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import '../widgets/brand_mark.dart';
import '../widgets/document_row.dart';
import '../widgets/status_badge.dart';
import 'document_detail_screen.dart';
import 'document_editor_screen.dart';
import 'setup_screen.dart';

/// The first thing the user sees: what they are owed, the three things they
/// might write next, who needs chasing, and what they did last.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, DocumentModel doc) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DocumentDetailScreen(docId: doc.id)));
  }

  void _write(BuildContext context, DocType type) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DocumentEditorScreen.create(type: type)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final currency = settings.currency;
    final attention = appState.attentionList();
    final recent = appState.sorted(appState.documents).take(5).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _header(context, appState),
            if (appState.storeUnreadable) _recoveryBanner(context, appState),
            const SizedBox(height: 18),
            _owedCard(context, appState),
            const SizedBox(height: 12),
            _newDocumentTiles(context),
            if (appState.documents.isEmpty) _emptyState(context, appState),
            if (attention.isNotEmpty) ...[
              const SectionCaption('NEEDS A NUDGE', padding: EdgeInsets.fromLTRB(2, 24, 2, 10)),
              for (final doc in attention)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DocumentRow(
                    doc: doc,
                    currency: currency,
                    withAccentBar: true,
                    onTap: () => _open(context, doc),
                  ),
                ),
            ],
            if (recent.isNotEmpty) ...[
              const SectionCaption('LATEST', padding: EdgeInsets.fromLTRB(2, 24, 2, 4)),
              for (final doc in recent)
                CompactDocumentRow(doc: doc, currency: currency, onTap: () => _open(context, doc)),
            ],
          ],
        ),
      ),
    );
  }

  /// Shown only when the saved file could not be read. The app deliberately
  /// stops writing in that state, so the user has to be told why nothing is
  /// sticking — and pointed at the backup that can bring it all back.
  Widget _recoveryBanner(BuildContext context, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE8E6),
        border: Border.all(color: AppTheme.danger),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your saved work couldn't be opened",
            style: AppTheme.caption(color: AppTheme.danger, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nothing new is being saved right now, so the old file stays exactly '
            'as it is. Restore your most recent backup from Setup to get your '
            'documents back.',
            style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.bodyText),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Text(
                'Restore a backup',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppState appState) {
    final settings = appState.settings;
    return Row(
      children: [
        BrandMark(logoPath: settings.logoPath, businessName: settings.businessName),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.businessName.trim().isEmpty ? 'JobSlip' : settings.businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
              Text(
                formatDayLabel(DateTime.now()),
                style: const TextStyle(fontSize: 12, color: AppTheme.subtleText),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen())),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Setup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  /// The one number that matters: what is owed. Overdue and collected sit
  /// inside it as the two ways that number moves.
  Widget _owedCard(BuildContext context, AppState appState) {
    final currency = appState.settings.currency;
    final unpaid = appState.unpaidInvoices;
    final overdue = appState.overdueInvoices;

    Widget tile({
      required String label,
      required Color labelColor,
      required String value,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF262624),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: labelColor),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTheme.mono(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(color: AppTheme.ink, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OWED TO YOU',
            style: AppTheme.caption(color: const Color(0xFFA3A39C), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(appState.owedTotal, currency),
            style: AppTheme.mono(fontSize: 31, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 3),
          Text(
            unpaid.isEmpty
                ? 'Nobody owes you - nice.'
                : '${unpaid.length} unpaid ${unpaid.length == 1 ? 'invoice' : 'invoices'}',
            style: const TextStyle(fontSize: 13, color: Color(0xFFC9C9C3)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              tile(
                label: 'OVERDUE',
                labelColor: const Color(0xFFFF8F84),
                value: formatMoney(appState.overdueTotal, currency),
                onTap: () => appState.goToTab(AppTab.invoices),
              ),
              const SizedBox(width: 10),
              tile(
                label: 'COLLECTED IN ${formatMonthCode(DateTime.now())}',
                labelColor: const Color(0xFF7FD6A6),
                value: formatMoney(appState.collectedThisMonth, currency),
                onTap: () => appState.goToTab(AppTab.receipts),
              ),
            ],
          ),
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${overdue.length} ${overdue.length == 1 ? 'invoice is' : 'invoices are'} past due',
              style: const TextStyle(fontSize: 12, color: Color(0xFFFF8F84)),
            ),
          ],
        ],
      ),
    );
  }

  /// Three doors in, named for the moment the user is standing in rather
  /// than for the document they produce.
  Widget _newDocumentTiles(BuildContext context) {
    Widget tile(DocType type, String sub) {
      final style = AppTheme.typeStyle(type);
      return Expanded(
        child: GestureDetector(
          onTap: () => _write(context, type),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: style.fg,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  style.short,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: style.fg),
                ),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11, color: style.fg.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ),
      );
    }

    // IntrinsicHeight so the three tiles share one height: inside a
    // ListView the cross axis is unbounded, and `stretch` alone would ask
    // the row to be infinitely tall.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile(DocType.quotation, 'Price a job'),
          const SizedBox(width: 9),
          tile(DocType.invoice, 'Bill, pay later'),
          const SizedBox(width: 9),
          tile(DocType.receipt, 'Paid on the spot'),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, AppState appState) {
    final needsBranding =
        appState.settings.businessName.trim().isEmpty ||
        appState.settings.payDetails.trim().isEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 26),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.strongBorder, width: 1.5, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Text(
            'Nothing here yet',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            "Pick one above. A quote before the job, an invoice when they'll pay "
            'later, a receipt when cash is in your hand.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.subtleText),
          ),
          if (needsBranding) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SetupScreen())),
              child: Text(
                'Add your logo & payment details first',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
