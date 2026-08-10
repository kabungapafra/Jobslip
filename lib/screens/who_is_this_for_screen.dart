import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../models/document.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import 'line_items_editor_screen.dart';
import 'pdf_preview_screen.dart';

class WhoIsThisForScreen extends StatefulWidget {
  final Client? presetClient;

  const WhoIsThisForScreen({super.key, this.presetClient});

  @override
  State<WhoIsThisForScreen> createState() => _WhoIsThisForScreenState();
}

class _WhoIsThisForScreenState extends State<WhoIsThisForScreen> {
  DocType _type = DocType.quotation;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    if (widget.presetClient != null) {
      _applyClient(widget.presetClient!);
    }
  }

  void _applyClient(Client c) {
    _nameCtrl.text = c.name;
    _phoneCtrl.text = c.phone;
    _locationCtrl.text = c.location;
    _selectedClientId = c.id;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final appState = context.read<AppState>();
    final client = appState.findOrCreateClient(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
    );

    final number = appState.previewNextNumber(_type);
    final result = await Navigator.of(context).push<LineItemsResult>(
      MaterialPageRoute(
        builder: (_) => LineItemsEditorScreen(
          title: client.name,
          subtitleLabel: 'Will be numbered $number',
          initialLines: const [],
          initialVatEnabled: appState.settings.chargeVat,
          isReceipt: _type == DocType.receipt,
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.lines.isEmpty) return;

    final doc = await appState.createDocument(
      type: _type,
      client: client,
      lines: result.lines,
      vatEnabled: result.vatEnabled,
      paid: result.paid,
    );

    if (!mounted) return;
    if (result.makePdf) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PdfPreviewScreen(doc: doc)),
      );
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final canContinue = _nameCtrl.text.trim().isNotEmpty;
    final number = appState.previewNextNumber(_type);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STEP 1 OF 2',
                          style: AppTheme.mono(
                              fontSize: 11, color: AppTheme.subtleText, letterSpacing: 1)),
                      const Text('Who is this for?',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.chipBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _typeSegment('Quotation', DocType.quotation),
                    _typeSegment('Receipt', DocType.receipt),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Will be numbered $number',
                    style: AppTheme.mono(fontSize: 11.5, color: AppTheme.subtleText)),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEW CLIENT',
                            style: AppTheme.mono(
                                fontSize: 11, color: AppTheme.subtleText, letterSpacing: 0.6)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          decoration: const InputDecoration(hintText: 'Name or business'),
                          onChanged: (_) => setState(() => _selectedClientId = null),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(hintText: 'WhatsApp number'),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationCtrl,
                          decoration: const InputDecoration(hintText: 'Site / location'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('OR PICK A REGULAR',
                            style: AppTheme.mono(
                                fontSize: 10.5, color: AppTheme.subtleText, letterSpacing: 0.6)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final c in appState.clients) _clientTile(c),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canContinue ? _continue : null,
                    child: Text(canContinue ? 'Add the work →' : 'Enter a client to continue'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeSegment(String label, DocType type) {
    final selected = _type == type;
    final brand = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? brand : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [BoxShadow(color: brand.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: selected ? Colors.white : AppTheme.subtleText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _clientTile(Client c) {
    final selected = _selectedClientId == c.id;
    return InkWell(
      onTap: () => setState(() => _applyClient(c)),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFBF1E4) : null,
          border: Border.all(color: selected ? const Color(0xFFE3C48C) : AppTheme.border),
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
                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('${c.phone} · ${c.location}',
                      style: AppTheme.mono(fontSize: 11.5, color: AppTheme.subtleText)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 18),
          ],
        ),
      ),
    );
  }
}
