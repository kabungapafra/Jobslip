import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_service.dart';
import '../models/document.dart';
import '../models/settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/logo_picker.dart';
import '../widgets/pill.dart';

/// Everything the business is, in one scroll: the brand that prints on the
/// paperwork, how clients pay, the defaults new documents inherit, and the
/// backup that is the only copy of any of it.
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
  late TextEditingController _payDetailsCtrl;
  late TextEditingController _tinCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _preparedNameCtrl;
  late TextEditingController _preparedPhoneCtrl;
  late TextEditingController _momoCtrl;
  late TextEditingController _airtelCtrl;
  bool _initialized = false;

  /// Keeps a focused field clear of the keyboard with room to spare, so the
  /// field you just moved into is actually on screen.
  static const EdgeInsets _keyboardClearance = EdgeInsets.only(bottom: 120);

  void _initFrom(BusinessSettings s) {
    if (_initialized) _disposeControllers();
    _nameCtrl = TextEditingController(text: s.businessName);
    _taglineCtrl = TextEditingController(text: s.tagline);
    _phoneCtrl = TextEditingController(text: s.phone);
    _locationCtrl = TextEditingController(text: s.location);
    _termsCtrl = TextEditingController(text: s.terms);
    _payDetailsCtrl = TextEditingController(text: s.payDetails);
    _tinCtrl = TextEditingController(text: s.tin);
    _emailCtrl = TextEditingController(text: s.businessEmail);
    _preparedNameCtrl = TextEditingController(text: s.preparedName);
    _preparedPhoneCtrl = TextEditingController(text: s.preparedPhone);
    _momoCtrl = TextEditingController(text: s.momoCode);
    _airtelCtrl = TextEditingController(text: s.airtelCode);
    _initialized = true;
  }

  void _disposeControllers() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _termsCtrl.dispose();
    _payDetailsCtrl.dispose();
    _tinCtrl.dispose();
    _emailCtrl.dispose();
    _preparedNameCtrl.dispose();
    _preparedPhoneCtrl.dispose();
    _momoCtrl.dispose();
    _airtelCtrl.dispose();
  }

  @override
  void dispose() {
    if (_initialized) _disposeControllers();
    super.dispose();
  }

  void _push(AppState appState, BusinessSettings Function(BusinessSettings) mutate) {
    appState.updateSettings(mutate(appState.settings.clone()));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------- actions ----------------

  Future<void> _editNumbering(AppState appState) async {
    final controllers = {
      for (final type in DocType.values)
        type: TextEditingController(text: appState.previewNextNumber(type).split('-').last),
    };

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit numbering'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set the number each type should use next. Numbers already issued '
              'are not affected.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.subtleText),
            ),
            const SizedBox(height: 16),
            for (final type in DocType.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[type],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Next ${AppTheme.typeStyle(type).short.toLowerCase()} number',
                    prefixText: appState
                        .previewNextNumber(type)
                        .replaceFirst(RegExp(r'[0-9]+$'), ''),
                  ),
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

    if (save == true) {
      final next = {
        for (final type in DocType.values) type: int.tryParse(controllers[type]!.text.trim()),
      };
      _push(appState, (s) {
        final q = next[DocType.quotation];
        final i = next[DocType.invoice];
        final r = next[DocType.receipt];
        // Stored as "last used", so the next one minted is this number.
        if (q != null && q > 0) s.quoteSeq = q - 1;
        if (i != null && i > 0) s.invoiceSeq = i - 1;
        if (r != null && r > 0) s.receiptSeq = r - 1;
        return s;
      });
    }
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  Future<void> _backupNow(AppState appState) async {
    final file = await appState.createBackupFile();
    if (!mounted) return;
    final name = appState.settings.businessName.trim();
    // Hand off to the share sheet — the user picks their own WhatsApp or
    // email from there. The app never touches an account itself.
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'JobSlip backup - ${formatDocDate(DateTime.now())}',
      text:
          'JobSlip backup for ${name.isEmpty ? 'your business' : name}. '
          'Keep this file safe — open it with "Restore" in Setup to bring '
          'everything back.',
    );
  }

  Future<void> _restoreFromFile(AppState appState) async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
          'This replaces everything currently on this phone — all clients, '
          'quotes, invoices and receipts — with what is in the backup file. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await appState.restoreFromBackupFile(File(path));
      if (!mounted) return;
      setState(() => _initialized = false);
      appState.goToTab(AppTab.home);
      _toast('${appState.documents.length} documents restored');
    } on BackupParseException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  Future<void> _confirmClear(AppState appState) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all documents?'),
        content: const Text(
          'This removes every quote, invoice and receipt from this phone. '
          'Clients stay saved. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await appState.clearAllDocuments();
      if (!mounted) return;
      appState.goToTab(AppTab.home);
      _toast('All documents cleared');
    }
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!_initialized) _initFrom(appState.settings);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.arrow_back, size: 22),
                    ),
                  ),
                  const Text('Setup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _brandCard(appState),
                  const SizedBox(height: 14),
                  _payDetailsCard(appState),
                  const SizedBox(height: 14),
                  _defaultsCard(appState),
                  const SizedBox(height: 14),
                  _termsCard(appState),
                  const SizedBox(height: 14),
                  _backupCard(appState),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _softButton('Clear all (first-run)', () => _confirmClear(appState)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _softButton('Load samples', () async {
                          await appState.restoreSampleDocuments();
                          if (!mounted) return;
                          setState(() => _initialized = false);
                          appState.goToTab(AppTab.home);
                          _toast('Sample documents loaded');
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Everything stays on this phone. No account, no subscription, '
                    'no one else reading your jobs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _softButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.subtleText,
          ),
        ),
      ),
    );
  }

  Widget _boxedField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    TextStyle? style,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      scrollPadding: _keyboardClearance,
      style: style ?? const TextStyle(fontSize: 13),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.all(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }

  Widget _multilineField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    int minLines = 3,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines + 4,
      scrollPadding: _keyboardClearance,
      style: const TextStyle(fontSize: 13.5, height: 1.5),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }

  Widget _brandCard(AppState appState) {
    final settings = appState.settings;
    return _card(
      children: [
        Text('YOUR BRAND', style: AppTheme.caption()),
        const SizedBox(height: 13),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LogoPicker(
              logoPath: settings.logoPath,
              onChanged: (path) => _push(appState, (s) => s..logoPath = path),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    scrollPadding: _keyboardClearance,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(hintText: 'Business name', isDense: true),
                    onChanged: (v) => _push(appState, (s) => s..businessName = v),
                  ),
                  TextField(
                    controller: _taglineCtrl,
                    textInputAction: TextInputAction.next,
                    scrollPadding: _keyboardClearance,
                    style: const TextStyle(fontSize: 13, color: AppTheme.bodyText),
                    decoration: const InputDecoration(hintText: 'What you do', isDense: true),
                    onChanged: (v) => _push(appState, (s) => s..tagline = v),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    settings.logoPath != null
                        ? 'Tap the logo to replace it, hold to remove'
                        : 'Tap the square to add your logo',
                    style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: _boxedField(
                controller: _phoneCtrl,
                hint: 'Phone',
                keyboardType: TextInputType.phone,
                style: AppTheme.mono(fontSize: 12.5),
                onChanged: (v) => _push(appState, (s) => s..phone = v),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _boxedField(
                controller: _locationCtrl,
                hint: 'Town',
                onChanged: (v) => _push(appState, (s) => s..location = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('ON EVERY PDF', style: AppTheme.caption()),
        const SizedBox(height: 11),
        _boxedField(
          controller: _emailCtrl,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => _push(appState, (s) => s..businessEmail = v),
        ),
        const SizedBox(height: 9),
        _boxedField(
          controller: _tinCtrl,
          hint: 'TIN (optional)',
          style: AppTheme.mono(fontSize: 12.5),
          onChanged: (v) => _push(appState, (s) => s..tin = v),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _boxedField(
                controller: _preparedNameCtrl,
                hint: 'Prepared by',
                onChanged: (v) => _push(appState, (s) => s..preparedName = v),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _boxedField(
                controller: _preparedPhoneCtrl,
                hint: 'Their phone',
                keyboardType: TextInputType.phone,
                style: AppTheme.mono(fontSize: 12.5),
                onChanged: (v) => _push(appState, (s) => s..preparedPhone = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Anything left blank is simply left off the page.',
          style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Brand colour',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${kBrandColors[settings.brandColorIndex].name} - buttons, tables & PDF accents',
                    style: const TextStyle(fontSize: 12, color: AppTheme.subtleText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              children: [
                for (int i = 0; i < kBrandColors.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: GestureDetector(
                      onTap: () => _push(appState, (s) => s..brandColorIndex = i),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: kBrandColors[i].color,
                          shape: BoxShape.circle,
                          // A white gap then the colour again, so the selected
                          // swatch reads as ringed rather than outlined.
                          boxShadow: settings.brandColorIndex == i
                              ? [
                                  const BoxShadow(color: Colors.white, spreadRadius: 2),
                                  BoxShadow(color: kBrandColors[i].color, spreadRadius: 4),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// The two mobile-money merchant codes print as tiles on every unpaid
  /// document, which is what clients actually pay into; bank details are
  /// the fallback for the ones who don't use mobile money.
  Widget _payDetailsCard(AppState appState) {
    Widget codeField({
      required String label,
      required Color background,
      required Color foreground,
      required TextEditingController controller,
      required ValueChanged<String> onChanged,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: foreground),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  scrollPadding: _keyboardClearance,
                  style: AppTheme.mono(fontSize: 12.5),
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    hintText: 'Merchant code',
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _card(
      children: [
        Text('HOW CLIENTS PAY YOU', style: AppTheme.caption()),
        const SizedBox(height: 4),
        const Text(
          'Printed on every unpaid document.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.subtleText),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            codeField(
              label: 'MoMo',
              background: const Color(0xFFFFCB05),
              foreground: const Color(0xFF0B3B5C),
              controller: _momoCtrl,
              onChanged: (v) => _push(appState, (s) => s..momoCode = v),
            ),
            const SizedBox(width: 9),
            codeField(
              label: 'airtel',
              background: const Color(0xFFE40000),
              foreground: Colors.white,
              controller: _airtelCtrl,
              onChanged: (v) => _push(appState, (s) => s..airtelCode = v),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _multilineField(
          controller: _payDetailsCtrl,
          hint: 'Bank details (optional)',
          minLines: 2,
          onChanged: (v) => _push(appState, (s) => s..payDetails = v),
        ),
      ],
    );
  }

  Widget _defaultsCard(AppState appState) {
    final settings = appState.settings;
    final vatPercent = (settings.vatRate * 100).toStringAsFixed(0);

    Widget divided(Widget child, {bool last = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.hairline)),
            ),
      child: child,
    );

    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      children: [
        divided(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add VAT by default',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      settings.chargeVat
                          ? 'New documents add $vatPercent% VAT'
                          : 'Off - tick it per job when needed',
                      style: const TextStyle(fontSize: 12, color: AppTheme.subtleText),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.chargeVat,
                activeThumbColor: Colors.white,
                activeTrackColor: Theme.of(context).colorScheme.primary,
                onChanged: (v) => _push(appState, (s) => s..chargeVat = v),
              ),
            ],
          ),
        ),
        divided(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invoices due after',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  for (final days in const [7, 14, 30])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: SelectablePill(
                        label: '$days days',
                        selected: settings.dueDefaultDays == days,
                        onTap: () => _push(appState, (s) => s..dueDefaultDays = days),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        divided(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Currency',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${_currencyNames[settings.currency] ?? settings.currency}, no cents',
                      style: const TextStyle(fontSize: 12, color: AppTheme.subtleText),
                    ),
                  ],
                ),
              ),
              DropdownButton<String>(
                value: settings.currency,
                underline: const SizedBox.shrink(),
                items: _currencyNames.keys
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: AppTheme.mono(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) _push(appState, (s) => s..currency = v);
                },
              ),
            ],
          ),
        ),
        divided(
          GestureDetector(
            onTap: () => _editNumbering(appState),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Next numbers',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, size: 18, color: AppTheme.mutedText),
                  ],
                ),
                const SizedBox(height: 8),
                for (final type in DocType.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Text(
                          '${AppTheme.typeStyle(type).short}s',
                          style: AppTheme.mono(fontSize: 12.5, color: AppTheme.typeStyle(type).fg),
                        ),
                        const Spacer(),
                        Text(
                          appState.previewNextNumber(type),
                          style: AppTheme.mono(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          last: true,
        ),
      ],
    );
  }

  Widget _termsCard(AppState appState) {
    return _card(
      children: [
        Text('TERMS', style: AppTheme.caption()),
        const SizedBox(height: 4),
        const Text(
          'Printed at the foot of every document.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.subtleText),
        ),
        const SizedBox(height: 10),
        _multilineField(
          controller: _termsCtrl,
          hint: 'Deposit, validity, warranty...',
          minLines: 4,
          onChanged: (v) => _push(appState, (s) => s..terms = v),
        ),
      ],
    );
  }

  Widget _backupCard(AppState appState) {
    final count = appState.documents.length;
    final last = appState.settings.lastBackupAt;

    return _card(
      children: [
        Text('BACKUP', style: AppTheme.caption()),
        const SizedBox(height: 7),
        Text(
          '$count ${count == 1 ? 'document' : 'documents'} on this phone. '
          'Lose the phone, lose the history — send a backup to yourself.',
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF55554F)),
        ),
        const SizedBox(height: 7),
        Text(
          last == null ? 'Never backed up' : 'Last backup ${formatBackupStamp(last)}',
          style: AppTheme.mono(fontSize: 11.5, color: AppTheme.mutedText),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _backupNow(appState),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Back up now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: GestureDetector(
                onTap: () => _restoreFromFile(appState),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.strongBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Restore',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
