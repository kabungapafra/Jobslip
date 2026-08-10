import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/line_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';

const _uuid = Uuid();

class LineItemsResult {
  final List<LineItem> lines;
  final bool vatEnabled;
  final bool makePdf;
  final bool paid;

  LineItemsResult({
    required this.lines,
    required this.vatEnabled,
    required this.makePdf,
    this.paid = false,
  });
}

/// Shared line-item editor used both by "new document" (step 2) and by
/// "Edit lines" on an existing document, so the two flows always agree on
/// interaction and layout.
class LineItemsEditorScreen extends StatefulWidget {
  final String title;
  final String subtitleLabel;
  final List<LineItem> initialLines;
  final bool initialVatEnabled;
  final bool isReceipt;
  final bool initialPaid;

  const LineItemsEditorScreen({
    super.key,
    required this.title,
    required this.subtitleLabel,
    required this.initialLines,
    required this.initialVatEnabled,
    this.isReceipt = false,
    this.initialPaid = false,
  });

  @override
  State<LineItemsEditorScreen> createState() => _LineItemsEditorScreenState();
}

class _LineItemsEditorScreenState extends State<LineItemsEditorScreen> {
  late List<LineItem> _lines;
  late bool _vatEnabled;
  late bool _paid;
  final Map<String, TextEditingController> _descControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void initState() {
    super.initState();
    _lines = widget.initialLines.isEmpty
        ? [LineItem(id: _uuid.v4(), description: '', quantity: 1, unitPrice: 0)]
        : widget.initialLines
            .map((l) => LineItem(id: l.id, description: l.description, quantity: l.quantity, unitPrice: l.unitPrice))
            .toList();
    _vatEnabled = widget.initialVatEnabled;
    _paid = widget.initialPaid;
    for (final l in _lines) {
      _descControllers[l.id] = TextEditingController(text: l.description);
      _priceControllers[l.id] = TextEditingController(text: l.unitPrice == 0 ? '' : l.unitPrice.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    for (final c in _descControllers.values) {
      c.dispose();
    }
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.amount);
  double get _vatRate => context.read<AppState>().settings.vatRate;
  double get _vatAmount => _vatEnabled ? _subtotal * _vatRate : 0.0;
  double get _total => _subtotal + _vatAmount;

  void _addLine() {
    setState(() {
      final line = LineItem(id: _uuid.v4(), description: '', quantity: 1, unitPrice: 0);
      _lines.add(line);
      _descControllers[line.id] = TextEditingController();
      _priceControllers[line.id] = TextEditingController();
    });
  }

  void _removeLine(String id) {
    setState(() {
      _lines.removeWhere((l) => l.id == id);
      _descControllers.remove(id)?.dispose();
      _priceControllers.remove(id)?.dispose();
    });
  }

  List<LineItem> _cleanedLines() =>
      _lines.where((l) => l.description.trim().isNotEmpty || l.unitPrice > 0).toList();

  void _save({required bool makePdf}) {
    final cleaned = _cleanedLines();
    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line with a description or price first.')),
      );
      return;
    }
    Navigator.of(context).pop(
      LineItemsResult(lines: cleaned, vatEnabled: _vatEnabled, makePdf: makePdf, paid: _paid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AppState>().settings.currency;
    final vatPercent = (_vatRate * 100).toStringAsFixed(0);

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.subtitleLabel,
                            style: AppTheme.mono(fontSize: 11.5, color: AppTheme.subtleText)),
                        Text(widget.title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  for (final line in _lines) _buildLineCard(line, currency),
                  OutlinedButton(
                    onPressed: _addLine,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.border, style: BorderStyle.solid),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('+ Add a line',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                  ),
                  if (widget.isReceipt) ...[
                    const SizedBox(height: 16),
                    _paidToggle(),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.ink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _totalsRow('Subtotal', formatMoney(_subtotal, currency)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _vatEnabled = !_vatEnabled),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _vatEnabled
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.white24,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: _vatEnabled
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('VAT $vatPercent%',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                            Text(formatMoney(_vatAmount, currency),
                                style: AppTheme.mono(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TOTAL',
                                style: AppTheme.mono(
                                    color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                            Text(formatMoney(_total, currency),
                                style: AppTheme.mono(
                                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _save(makePdf: false),
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _save(makePdf: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                        child: const Text('Save & make PDF'),
                      ),
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

  Widget _paidToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.chipBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _paidSegment('Not paid yet', selected: !_paid, onTap: () => setState(() => _paid = false)),
          _paidSegment('Paid', selected: _paid, onTap: () => setState(() => _paid = true), accent: true),
        ],
      ),
    );
  }

  Widget _paidSegment(String label, {required bool selected, required VoidCallback onTap, bool accent = false}) {
    final color = accent ? const Color(0xFF2C7A4B) : AppTheme.ink;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? (accent ? color.withValues(alpha: 0.12) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected && accent ? Border.all(color: color, width: 1.4) : null,
            boxShadow: selected && !accent
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (accent) ...[
                Icon(Icons.check_circle, size: 16, color: selected ? color : AppTheme.subtleText),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: selected ? color : AppTheme.subtleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalsRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: AppTheme.mono(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _buildLineCard(LineItem line, String currency) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _descControllers[line.id],
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'What did you do or supply?',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => line.description = v),
                ),
              ),
              if (_lines.length > 1)
                InkWell(
                  onTap: () => _removeLine(line.id),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18, color: AppTheme.subtleText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stepperButton(Icons.remove, () {
                if (line.quantity > 1) setState(() => line.quantity -= 1);
              }),
              SizedBox(
                width: 30,
                child: Text(
                  line.quantity == line.quantity.roundToDouble()
                      ? line.quantity.toStringAsFixed(0)
                      : line.quantity.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _stepperButton(Icons.add, () => setState(() => line.quantity += 1)),
              const SizedBox(width: 8),
              Text('×', style: TextStyle(color: AppTheme.subtleText)),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _priceControllers[line.id],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTheme.mono(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '0',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (v) => setState(() => line.unitPrice = double.tryParse(v) ?? 0),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(currency, style: AppTheme.mono(fontSize: 10, color: AppTheme.subtleText)),
                  Text(formatAmount(line.amount),
                      style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.chipBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
