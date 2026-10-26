import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import '../widgets/document_row.dart';
import '../widgets/pill.dart';
import 'document_detail_screen.dart';
import 'document_editor_screen.dart';

/// A filter offered on a list, with the test that decides what it shows.
class _Filter {
  final String key;
  final String label;
  final bool Function(DocumentModel) matches;
  const _Filter(this.key, this.label, this.matches);
}

/// One list per document type, rather than one list of everything: the
/// question "who still owes me?" is a different question from "what did I
/// quote?", and each list leads with the number that answers its own.
class DocumentsListScreen extends StatefulWidget {
  final DocType type;

  const DocumentsListScreen({super.key, required this.type});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  String _query = '';
  late String _filterKey;

  List<_Filter> get _filters {
    switch (widget.type) {
      case DocType.quotation:
        return [
          _Filter('open', 'Open', (d) => d.status == DocStatus.draft || d.status == DocStatus.sent),
          _Filter(
            'won',
            'Won',
            (d) => d.status == DocStatus.invoiced || d.status == DocStatus.receipted,
          ),
          _Filter('all', 'All', (_) => true),
        ];
      case DocType.invoice:
        return [
          _Filter('unpaid', 'Unpaid', (d) => d.status != DocStatus.paid),
          _Filter('overdue', 'Overdue', (d) => d.isOverdue()),
          _Filter('paid', 'Paid', (d) => d.status == DocStatus.paid),
          _Filter('all', 'All', (_) => true),
        ];
      case DocType.receipt:
        return [
          _Filter('all', 'All', (_) => true),
          _Filter('month', 'This month', (d) {
            final now = DateTime.now();
            return d.date.year == now.year && d.date.month == now.month;
          }),
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    // Each list opens on the filter that matches why you came: unpaid
    // invoices, quotes still waiting, every receipt.
    _filterKey = switch (widget.type) {
      DocType.quotation => 'open',
      DocType.invoice => 'unpaid',
      DocType.receipt => 'all',
    };
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currency = appState.settings.currency;
    final style = AppTheme.typeStyle(widget.type);
    final filters = _filters;
    final active = filters.firstWhere((f) => f.key == _filterKey, orElse: () => filters.first);

    final ofType = appState.ofType(widget.type);
    final query = _query.trim().toLowerCase();
    final matching = ofType
        .where(active.matches)
        .where(
          (d) =>
              query.isEmpty ||
              d.clientName.toLowerCase().contains(query) ||
              d.number.toLowerCase().contains(query),
        );
    final rows = _sortRows(appState, matching.toList());

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => DocumentEditorScreen.create(type: widget.type))),
        backgroundColor: style.fg,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'New ${style.short.toLowerCase()}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${style.short}s',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.9,
                      color: style.fg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _statCard(appState, style, currency),
                  const SizedBox(height: 12),
                  _searchField(),
                  const SizedBox(height: 11),
                  _filterChips(filters, active, ofType, style),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? _empty(ofType.isEmpty, style)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => DocumentRow(
                        doc: rows[i],
                        currency: currency,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DocumentDetailScreen(docId: rows[i].id),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Newest first everywhere, except a list of money owed: there the
  /// question is who to chase, so the most overdue comes first and anything
  /// without a due date falls to the end.
  List<DocumentModel> _sortRows(AppState appState, List<DocumentModel> rows) {
    final chasing =
        widget.type == DocType.invoice && (_filterKey == 'unpaid' || _filterKey == 'overdue');
    if (!chasing) return appState.sorted(rows);

    rows.sort((a, b) {
      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue == null && bDue == null) return b.date.compareTo(a.date);
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    });
    return rows;
  }

  /// The headline number for this type: what is owed, what is still out for
  /// a decision, or what came in this month.
  Widget _statCard(AppState appState, DocTypeStyle style, String currency) {
    final (String label, String value, String sub, Color subColour) = switch (widget.type) {
      DocType.invoice => () {
        final unpaid = appState.unpaidInvoices;
        final overdue = appState.overdueInvoices;
        return (
          'UNPAID',
          formatMoney(AppState.sumOf(unpaid), currency),
          overdue.isEmpty
              ? 'Nothing overdue'
              : '${overdue.length} overdue - ${formatMoney(AppState.sumOf(overdue), currency)}',
          overdue.isEmpty ? const Color(0xFF55554F) : AppTheme.danger,
        );
      }(),
      DocType.quotation => () {
        final open = appState.openQuotes;
        return (
          'WAITING ON A YES',
          formatMoney(AppState.sumOf(open), currency),
          '${open.length} open ${open.length == 1 ? 'quote' : 'quotes'}',
          const Color(0xFF55554F),
        );
      }(),
      DocType.receipt => () {
        final month = appState.receiptsIn(DateTime.now());
        return (
          'RECEIVED IN ${formatMonthCode(DateTime.now()).toUpperCase()}',
          formatMoney(AppState.sumOf(month), currency),
          '${month.length} ${month.length == 1 ? 'receipt' : 'receipts'} this month',
          const Color(0xFF55554F),
        );
      }(),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTheme.caption(color: style.fg)),
                const SizedBox(height: 4),
                Text(value, style: AppTheme.mono(fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              sub,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: subColour),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppTheme.faintText),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14.5),
              decoration: const InputDecoration(
                hintText: 'Search client or number',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Each chip carries its own count, so the user can see where the work is
  /// without tapping through every filter.
  Widget _filterChips(
    List<_Filter> filters,
    _Filter active,
    List<DocumentModel> ofType,
    DocTypeStyle style,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: SelectablePill(
                label: '${f.label} - ${ofType.where(f.matches).length}',
                selected: f.key == active.key,
                accent: style.fg,
                onTap: () => setState(() => _filterKey = f.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(bool noneAtAll, DocTypeStyle style) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Text(
          noneAtAll
              ? 'No ${style.short.toLowerCase()}s yet. Tap + to write the first one.'
              : 'Nothing matches here.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.subtleText),
        ),
      ),
    );
  }
}
