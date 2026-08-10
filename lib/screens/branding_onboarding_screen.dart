import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/logo_picker.dart';

/// Shown once, on a fresh install, before the dashboard. Lets a real user
/// put their own business on every PDF from their very first document
/// instead of finding out later that Setup exists. "Skip for now" is a
/// first-class option — nothing here is required, and it's all editable
/// again later in Setup.
class BrandingOnboardingScreen extends StatefulWidget {
  const BrandingOnboardingScreen({super.key});

  @override
  State<BrandingOnboardingScreen> createState() => _BrandingOnboardingScreenState();
}

class _BrandingOnboardingScreenState extends State<BrandingOnboardingScreen> {
  static const _currencyNames = {
    'UGX': 'Ugandan Shilling',
    'KES': 'Kenyan Shilling',
    'TZS': 'Tanzanian Shilling',
    'USD': 'US Dollar',
  };

  late BusinessSettings _draft;
  late TextEditingController _nameCtrl;
  late TextEditingController _taglineCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _termsCtrl;

  @override
  void initState() {
    super.initState();
    _draft = context.read<AppState>().settings.clone();
    _nameCtrl = TextEditingController(text: _draft.businessName);
    _taglineCtrl = TextEditingController(text: _draft.tagline);
    _phoneCtrl = TextEditingController(text: _draft.phone);
    _locationCtrl = TextEditingController(text: _draft.location);
    _termsCtrl = TextEditingController(text: _draft.terms);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  void _finish() {
    context.read<AppState>().completeOnboarding(_draft);
  }

  Future<void> _editNumbering() async {
    final quoteCtrl = TextEditingController(text: (_draft.quoteSeq + 1).toString());
    final receiptCtrl = TextEditingController(text: (_draft.receiptSeq + 1).toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit numbering'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set the number your first quotation and receipt should use.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.subtleText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quoteCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Next quotation number', prefixText: '${_draft.numberPrefix}-Q-'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: receiptCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Next receipt number', prefixText: '${_draft.numberPrefix}-R-'),
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
      setState(() {
        if (nextQuote != null && nextQuote > 0) _draft.quoteSeq = nextQuote - 1;
        if (nextReceipt != null && nextReceipt > 0) _draft.receiptSeq = nextReceipt - 1;
      });
    }
    quoteCtrl.dispose();
    receiptCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                children: [
                  Text('WELCOME TO',
                      style: AppTheme.mono(fontSize: 11, color: AppTheme.subtleText, letterSpacing: 1.5)),
                  const Text('JobSlip',
                      style: TextStyle(fontFamily: 'ArchivoBlack', fontSize: 28, height: 1.1)),
                  const SizedBox(height: 10),
                  const Text(
                    "Let's put your business on your paperwork. This prints on every quotation and receipt — you can change any of it later in Setup.",
                    style: TextStyle(fontSize: 13.5, color: AppTheme.subtleText, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LogoPicker(
                              logoPath: _draft.logoPath,
                              onChanged: (path) => setState(() => _draft.logoPath = path),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _nameCtrl,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Business or trading name',
                                    ),
                                    onChanged: (v) => _draft.businessName = v,
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _taglineCtrl,
                                    style: const TextStyle(fontSize: 12.5),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'What you do (e.g. CCTV · Networking)',
                                    ),
                                    onChanged: (v) => _draft.tagline = v,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(isDense: true, hintText: 'Phone'),
                                onChanged: (v) => _draft.phone = v,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _locationCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(isDense: true, hintText: 'Location'),
                                onChanged: (v) => _draft.location = v,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Brand colour', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (int i = 0; i < kBrandColors.length; i++) ...[
                              GestureDetector(
                                onTap: () => setState(() => _draft.brandColorIndex = i),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: kBrandColors[i].color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _draft.brandColorIndex == i ? AppTheme.ink : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: _draft.brandColorIndex == i
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
                          value: _draft.chargeVat,
                          onChanged: (v) => setState(() => _draft.chargeVat = v),
                          activeThumbColor: kBrandColors[_draft.brandColorIndex].color,
                          title: const Text('Charge VAT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: const Text('Default: add 18% to new documents',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.subtleText)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Currency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text('${_currencyNames[_draft.currency] ?? _draft.currency}, no cents',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.subtleText)),
                          trailing: DropdownButton<String>(
                            value: _draft.currency,
                            underline: const SizedBox.shrink(),
                            items: const ['UGX', 'KES', 'TZS', 'USD']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppTheme.mono(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _draft.currency = v);
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          onTap: _editNumbering,
                          title: const Text('Numbering', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: const Text('Separate runs for quotes & receipts · tap to edit',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.subtleText)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_draft.numberPrefix}-Q-${(_draft.quoteSeq + 1).toString().padLeft(4, '0')} / '
                                '${_draft.numberPrefix}-R-${(_draft.receiptSeq + 1).toString().padLeft(4, '0')}',
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
                            hintText: 'e.g. Quotation valid 14 days. 50% deposit before work starts.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                          onChanged: (v) => _draft.terms = v,
                        ),
                      ],
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _finish,
                        child: const Text('Get started'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Skip for now'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
