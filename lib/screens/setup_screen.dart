import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_service.dart';
import '../models/settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/logo_picker.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _currencyNames = {
    'UGX': 'Ugandan Shilling',
    'KES': 'Kenyan Shilling',
    'TZS': 'Tanzanian Shilling',
    'USD': 'US Dollar',
  };

  late TextEditingController _nameCtrl;
  late TextEditingController _taglineCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _termsCtrl;
  bool _initialized = false;

  void _initFrom(BusinessSettings s) {
    if (_initialized) {
      _nameCtrl.dispose();
      _taglineCtrl.dispose();
      _phoneCtrl.dispose();
      _locationCtrl.dispose();
      _termsCtrl.dispose();
    }
    _nameCtrl = TextEditingController(text: s.businessName);
    _taglineCtrl = TextEditingController(text: s.tagline);
    _phoneCtrl = TextEditingController(text: s.phone);
    _locationCtrl = TextEditingController(text: s.location);
    _termsCtrl = TextEditingController(text: s.terms);
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _nameCtrl.dispose();
      _taglineCtrl.dispose();
      _phoneCtrl.dispose();
      _locationCtrl.dispose();
      _termsCtrl.dispose();
    }
    super.dispose();
  }

  void _push(AppState appState, BusinessSettings Function(BusinessSettings) mutate) {
    final updated = mutate(appState.settings.clone());
    appState.updateSettings(updated);
  }

  Future<void> _editNumbering(AppState appState) async {
    final quoteCtrl =
        TextEditingController(text: (appState.settings.quoteSeq + 1).toString());
    final receiptCtrl =
        TextEditingController(text: (appState.settings.receiptSeq + 1).toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit numbering'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set the number your next quotation and receipt should use.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.subtleText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quoteCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Next quotation number',
                prefixText: '${appState.settings.numberPrefix}-Q-',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: receiptCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Next receipt number',
                prefixText: '${appState.settings.numberPrefix}-R-',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      final nextQuote = int.tryParse(quoteCtrl.text.trim());
      final nextReceipt = int.tryParse(receiptCtrl.text.trim());
      _push(appState, (s) {
        if (nextQuote != null && nextQuote > 0) s.quoteSeq = nextQuote - 1;
        if (nextReceipt != null && nextReceipt > 0) s.receiptSeq = nextReceipt - 1;
        return s;
      });
    }
    quoteCtrl.dispose();
    receiptCtrl.dispose();
  }

  Future<void> _backupNow(AppState appState) async {
    final file = await appState.createBackupFile();
    if (!mounted) return;
    // Hand off to the share sheet — the user picks their own email app (or
    // anything else) from here. We never touch an email account ourselves.
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'JobSlip backup — ${DateTime.now().toIso8601String().split('T').first}',
      text: 'JobSlip backup for ${appState.settings.businessName.isEmpty ? 'your business' : appState.settings.businessName}. '
          'Keep this file safe — open it with JobSlip\'s "Restore from file" to bring your data back.',
    );
  }

  Future<void> _restoreFromFile(AppState appState) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
            'This replaces everything currently on this phone — all clients, quotations and receipts — with what\'s in the backup file. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await appState.restoreFromBackupFile(File(path));
      if (!mounted) return;
      setState(() => _initialized = false);
      appState.setTab(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored.')),
      );
    } on BackupParseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmClear(AppState appState) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all documents?'),
        content: const Text(
            'This removes every quotation and receipt from this phone. Clients stay saved. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await appState.clearAllDocuments();
      if (mounted) {
        appState.setTab(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!_initialized) _initFrom(appState.settings);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text('Your setup', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('This is what prints on every PDF.',
                style: TextStyle(color: AppTheme.subtleText, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BRANDING',
                      style: AppTheme.mono(fontSize: 11, color: AppTheme.subtleText, letterSpacing: 0.6)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LogoPicker(
                        logoPath: appState.settings.logoPath,
                        onChanged: (path) => _push(appState, (s) => s..logoPath = path),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameCtrl,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (v) => _push(appState, (s) => s..businessName = v),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _taglineCtrl,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (v) => _push(appState, (s) => s..tagline = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appState.settings.logoPath != null
                        ? 'Tap logo to replace · long-press to remove'
                        : 'Tap the square to add your logo',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.subtleText),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (v) => _push(appState, (s) => s..phone = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _locationCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (v) => _push(appState, (s) => s..location = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Brand colour', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('${kBrandColors[appState.settings.brandColorIndex].name} — used on buttons & the PDF header',
                      style: const TextStyle(color: AppTheme.subtleText, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (int i = 0; i < kBrandColors.length; i++) ...[
                        GestureDetector(
                          onTap: () => _push(appState, (s) => s..brandColorIndex = i),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: kBrandColors[i].color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: appState.settings.brandColorIndex == i
                                    ? AppTheme.ink
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: appState.settings.brandColorIndex == i
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: appState.settings.chargeVat,
                    onChanged: (v) => _push(appState, (s) => s..chargeVat = v),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    title: const Text('Charge VAT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Default: add 18% to new documents',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.subtleText)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Currency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text('${_currencyNames[appState.settings.currency] ?? appState.settings.currency}, no cents',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.subtleText)),
                    trailing: DropdownButton<String>(
                      value: appState.settings.currency,
                      underline: const SizedBox.shrink(),
                      items: const ['UGX', 'KES', 'TZS', 'USD']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppTheme.mono(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _push(appState, (s) => s..currency = v);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    onTap: () => _editNumbering(appState),
                    title: const Text('Numbering', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Separate runs for quotes & receipts · tap to edit',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.subtleText)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${appState.settings.numberPrefix}-Q-${(appState.settings.quoteSeq + 1).toString().padLeft(4, '0')} / '
                          '${appState.settings.numberPrefix}-R-${(appState.settings.receiptSeq + 1).toString().padLeft(4, '0')}',
                          style: AppTheme.mono(fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 18, color: AppTheme.subtleText),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TERMS ON EVERY DOCUMENT',
                      style: AppTheme.mono(fontSize: 11, color: AppTheme.subtleText, letterSpacing: 0.6)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _termsCtrl,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                    onChanged: (v) => _push(appState, (s) => s..terms = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BACKUP & RESTORE',
                      style: AppTheme.mono(fontSize: 11, color: AppTheme.subtleText, letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  const Text(
                    'Email yourself a backup file when you have signal. Restore it on this phone or a new one — no account needed.',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.subtleText),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _backupNow(appState),
                      child: const Text('Backup my data'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _restoreFromFile(appState),
                      child: const Text('Restore from file'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _confirmClear(appState),
                child: const Text('Clear all documents (see first-run)'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await appState.restoreSampleDocuments();
                  if (mounted) appState.setTab(0);
                },
                child: const Text('Restore sample documents'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Everything lives on this phone. No account, no subscription, no one reading your jobs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.subtleText, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
