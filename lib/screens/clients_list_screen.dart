import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../models/document.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import 'document_editor_screen.dart';

/// The client book, ordered around one question: does this person owe me
/// anything? Tapping someone starts the invoice, which is the thing you
/// almost always came here to do.
class ClientsListScreen extends StatelessWidget {
  const ClientsListScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context, Client c) async {
    final docCount = context.read<AppState>().docCountFor(c.id);
    final docsWarning = docCount == 0
        ? ''
        : ' This also deletes $docCount ${docCount == 1 ? 'document' : 'documents'} you made for them.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove client?'),
        content: Text(
          '${c.name} will be removed from your client list.$docsWarning This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currency = appState.settings.currency;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Text(
              'Clients',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.9),
            ),
            const SizedBox(height: 4),
            Text(
              appState.clients.isEmpty
                  ? 'Nobody saved yet. New clients are added while writing a document.'
                  : 'Tap someone to bill them. Swipe a row left to remove them.',
              style: const TextStyle(fontSize: 13.5, color: AppTheme.subtleText),
            ),
            const SizedBox(height: 16),
            for (final c in appState.clients)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _clientRow(context, appState, c, currency),
              ),
          ],
        ),
      ),
    );
  }

  Widget _clientRow(BuildContext context, AppState appState, Client c, String currency) {
    final owed = appState.outstandingFor(c.id);
    final hasOverdue = appState.hasOverdueFor(c.id);
    final owes = owed > 0;

    final (String caption, Color captionColour) = owes
        ? hasOverdue
              ? ('OVERDUE', AppTheme.danger)
              : ('OWES', AppTheme.unpaidStatus.fg)
        : ('ALL PAID', AppTheme.success);

    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, c),
      onDismissed: (_) => context.read<AppState>().deleteClient(c.id),
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentEditorScreen.create(type: DocType.invoice, clientId: c.id),
          ),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE7E7E4)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.chipBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  c.initials,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF55554F),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.phone.trim().isEmpty ? 'no number' : c.phone,
                      style: AppTheme.mono(fontSize: 11, color: AppTheme.mutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caption,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: captionColour,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    owes ? formatMoney(owed, currency) : '-',
                    style: AppTheme.mono(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
