import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/initials_avatar.dart';
import 'who_is_this_for_screen.dart';

class ClientsListScreen extends StatelessWidget {
  const ClientsListScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context, Client c) async {
    final docCount = context.read<AppState>().docCountFor(c.id);
    final docsWarning = docCount == 0
        ? ''
        : ' This also deletes $docCount ${docCount == 1 ? 'document' : 'documents'} you made for them from your dashboard.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove client?'),
        content: Text('${c.name} will be removed from your client list.$docsWarning This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('Clients', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                appState.clients.isEmpty
                    ? '0 saved on this phone'
                    : '${appState.clients.length} saved on this phone · swipe left to remove',
                style: const TextStyle(color: AppTheme.subtleText, fontSize: 13),
              ),
            ),
            Expanded(
              child: appState.clients.isEmpty
                  ? Center(
                      child: Text('No clients yet', style: TextStyle(color: AppTheme.subtleText)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: appState.clients.length,
                      itemBuilder: (context, i) {
                        final c = appState.clients[i];
                        final count = appState.docCountFor(c.id);
                        final total = appState.totalFor(c.id);
                        return Dismissible(
                          key: ValueKey(c.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(context, c),
                          onDismissed: (_) => context.read<AppState>().deleteClient(c.id),
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WhoIsThisForScreen(presetClient: c),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.border),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  InitialsAvatar(initials: c.initials),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                        Text('${c.phone} · ${c.location}',
                                            style: AppTheme.mono(fontSize: 11.5, color: AppTheme.subtleText)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('$count docs',
                                          style: AppTheme.mono(fontSize: 11, color: AppTheme.subtleText)),
                                      Text(formatMoney(total, currency),
                                          style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
