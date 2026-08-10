import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'clients_list_screen.dart';
import 'documents_list_screen.dart';
import 'setup_screen.dart';

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  static const _screens = [
    DocumentsListScreen(),
    ClientsListScreen(),
    SetupScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: IndexedStack(index: appState.tabIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: appState.tabIndex,
        onDestinationSelected: appState.setTab,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.chipBackground,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Documents'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Setup'),
        ],
      ),
    );
  }
}
