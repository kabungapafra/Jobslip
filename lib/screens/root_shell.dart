import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'clients_list_screen.dart';
import 'documents_list_screen.dart';
import 'home_screen.dart';

/// The five destinations, in the order money moves through the business:
/// the overview, what you quoted, what you are owed, what you collected,
/// and who it all belongs to.
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  static const _screens = [
    HomeScreen(),
    DocumentsListScreen(type: DocType.quotation),
    DocumentsListScreen(type: DocType.invoice),
    DocumentsListScreen(type: DocType.receipt),
    ClientsListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final overdueCount = appState.overdueInvoices.length;

    return Scaffold(
      body: IndexedStack(index: appState.tabIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: appState.tabIndex,
        onDestinationSelected: appState.setTab,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.chipBackground,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.request_quote_outlined), label: 'Quotes'),
          NavigationDestination(
            // The badge is the whole point of this tab: an overdue invoice
            // should be visible from anywhere in the app.
            icon: Badge(
              isLabelVisible: overdueCount > 0,
              backgroundColor: AppTheme.danger,
              label: Text('$overdueCount'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            label: 'Invoices',
          ),
          const NavigationDestination(icon: Icon(Icons.verified_outlined), label: 'Receipts'),
          const NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clients'),
        ],
      ),
    );
  }
}
