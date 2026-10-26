import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/client.dart';
import '../models/document.dart';
import '../models/line_item.dart';
import '../models/settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import '../widgets/pill.dart';
import 'document_detail_screen.dart';
import 'draft_preview_screen.dart';

const _uuid = Uuid();

/// Groups a money field's digits as they are typed: 185000 -> 185,000.
/// The underlying value is always re-read from the digits, so the grouping
/// is purely what the user sees.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final grouped = formatAmount(int.parse(digits));
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}

/// Writes one document, whichever of the three it is. The same screen
/// covers a new document, an edit of an existing one, and "use again for
/// another job", because they are the same form with different starting
/// contents — and keeping them one screen means the three can never drift
/// apart in behaviour.
class DocumentEditorScreen extends StatefulWidget {
  /// The document being edited, or null when writing a new one.
  final DocumentModel? existing;

  /// Type the editor opens on. Ignored when [existing] is set.
  final DocType initialType;

  /// Pre-selected client, used when starting from the clients list.
  final String? initialClientId;

  /// Lines and notes copied from another document, for "use again".
  final DocumentModel? copyFrom;

  const DocumentEditorScreen._({
    this.existing,
    this.initialType = DocType.quotation,
    this.initialClientId,
    this.copyFrom,
  });

  factory DocumentEditorScreen.create({required DocType type, String? clientId}) =>
      DocumentEditorScreen._(initialType: type, initialClientId: clientId);

  factory DocumentEditorScreen.edit(DocumentModel doc) => DocumentEditorScreen._(existing: doc);

  factory DocumentEditorScreen.duplicate(DocumentModel source) => DocumentEditorScreen._(
    initialType: source.type,
    initialClientId: source.clientId,
    copyFrom: source,
  );

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late DocType _type;
  late List<LineItem> _lines;
  late bool _vatEnabled;
  late String _notes;
  late int _dueDays;
  late String _method;

  /// Null means "writing a new client" rather than picking a saved one.
  String? _clientId;
  bool _newClientMode = false;

  final _notesCtrl = TextEditingController();
  final _ncNameCtrl = TextEditingController();
  final _ncPhoneCtrl = TextEditingController();
  final _ncPlaceCtrl = TextEditingController();
  final Map<String, TextEditingController> _descCtrls = {};
  final Map<String, TextEditingController> _priceCtrls = {};

  /// Units on an invoice or receipt, a grouping category on a quotation -
  /// the printed templates give each its own column.
  final Map<String, TextEditingController> _unitCtrls = {};
  final Map<String, TextEditingController> _categoryCtrls = {};

  bool get _isNew => widget.existing == null;

  /// How much room to keep below a focused field when the view scrolls to
  /// it. The default only clears the keyboard; the bottom bar sits above
  /// that, so without this the field you just tapped hides behind it.
  static const EdgeInsets _keyboardClearance = EdgeInsets.only(bottom: 150);

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final existing = widget.existing;
    final source = existing ?? widget.copyFrom;

    _type = existing?.type ?? widget.initialType;
    _vatEnabled = source?.vatEnabled ?? appState.settings.chargeVat;
    _notes = source?.notes ?? '';
    _dueDays = existing?.dueDays ?? appState.settings.dueDefaultDays;
    _method = existing?.method ?? source?.method ?? kPaymentMethods.first;
    _notesCtrl.text = _notes;

    _clientId = existing?.clientId ?? widget.initialClientId;
    if (_clientId != null && appState.clientById(_clientId!) == null) {
      // The client was deleted since; fall back to asking again.
      _clientId = null;
    }
    _newClientMode = _clientId == null && appState.clients.isEmpty;

    _lines = (source?.lines ?? const <LineItem>[])
        .map(
          (l) => LineItem(
            id: _uuid.v4(),
            description: l.description,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
          ),
        )
        .toList();
    if (_lines.isEmpty) _lines.add(_blankLine());
    for (final l in _lines) {
      _registerControllers(l);
    }
  }

  LineItem _blankLine() => LineItem(id: _uuid.v4(), description: '', quantity: 1, unitPrice: 0);

  void _registerControllers(LineItem line) {
    _descCtrls[line.id] = TextEditingController(text: line.description);
    _priceCtrls[line.id] = TextEditingController(
      text: line.unitPrice == 0 ? '' : formatAmount(line.unitPrice),
    );
    _unitCtrls[line.id] = TextEditingController(text: line.unit);
    _categoryCtrls[line.id] = TextEditingController(text: line.category);
  }

  void _disposeControllers(String lineId) {
    _descCtrls.remove(lineId)?.dispose();
    _priceCtrls.remove(lineId)?.dispose();
    _unitCtrls.remove(lineId)?.dispose();
    _categoryCtrls.remove(lineId)?.dispose();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _ncNameCtrl.dispose();
    _ncPhoneCtrl.dispose();
    _ncPlaceCtrl.dispose();
    for (final map in [_descCtrls, _priceCtrls, _unitCtrls, _categoryCtrls]) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.amount);
  double get _vatRate => context.read<AppState>().settings.vatRate;
  double get _vatAmount => _vatEnabled ? _subtotal * _vatRate : 0.0;
  double get _total => _subtotal + _vatAmount;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<LineItem> _usableLines() => _lines
      .where((l) => l.description.trim().isNotEmpty || l.unitPrice > 0)
      .map(
        (l) => LineItem(
          id: l.id,
          description: l.description.trim(),
          quantity: l.quantity,
          unitPrice: l.unitPrice,
        ),
      )
      .toList();

  /// The validation both previewing and saving need. [persistClient]
  /// decides whether a newly typed client is actually written to the client
  /// book — a preview must not leave one behind if the user backs out.
  ({Client client, List<LineItem> lines})? _collect({required bool persistClient}) {
    final appState = context.read<AppState>();

    Client? client;
    if (_newClientMode) {
      final name = _ncNameCtrl.text.trim();
      if (name.isEmpty) {
        _toast('Add the client name first');
        return null;
      }
      client = persistClient
          ? appState.findOrCreateClient(
              name: name,
              phone: _ncPhoneCtrl.text.trim(),
              location: _ncPlaceCtrl.text.trim(),
            )
          : Client(
              id: 'preview',
              name: name,
              phone: _ncPhoneCtrl.text.trim(),
              location: _ncPlaceCtrl.text.trim(),
            );
    } else {
      final id = _clientId;
      client = id == null ? null : appState.clientById(id);
      if (client == null) {
        _toast('Pick who this is for');
        return null;
      }
    }

    final lines = _usableLines();
    if (lines.isEmpty) {
      _toast('Add at least one line of work');
      return null;
    }
    return (client: client, lines: lines);
  }

  /// A throwaway document that renders exactly like the real one will, so
  /// the preview is not an approximation. It is never stored, and it does
  /// not consume the number it displays.
  DocumentModel _draftDocument(Client client, List<LineItem> lines) {
    final appState = context.read<AppState>();
    final existing = widget.existing;
    final issued = existing?.date ?? DateTime.now();

    return DocumentModel(
      id: existing?.id ?? 'draft',
      type: _type,
      status:
          existing?.status ??
          switch (_type) {
            DocType.quotation => DocStatus.draft,
            DocType.invoice => DocStatus.unpaid,
            DocType.receipt => DocStatus.paid,
          },
      number: existing?.number ?? appState.previewNextNumber(_type),
      date: issued,
      clientId: client.id,
      clientName: client.name,
      clientPhone: client.phone,
      clientLocation: client.location,
      lines: lines,
      vatEnabled: _vatEnabled,
      vatRate: appState.settings.vatRate,
      notes: _notesCtrl.text.trim(),
      dueDays: _type == DocType.invoice ? _dueDays : null,
      dueDate: _type == DocType.invoice ? _addDays(issued, _dueDays) : null,
      paidOn: _type == DocType.receipt ? issued : existing?.paidOn,
      method: _type == DocType.receipt ? _method : existing?.method,
      fromNumber: existing?.fromNumber,
      invoiceNumber: existing?.invoiceNumber,
      receiptNumber: existing?.receiptNumber,
    );
  }

  /// Look at it before committing to it. Nothing is written, no number is
  /// spent, and the client book is untouched until the user says save.
  Future<void> _preview() async {
    final collected = _collect(persistClient: false);
    if (collected == null) return;

    final settings = context.read<AppState>().settings;
    final draft = _draftDocument(collected.client, collected.lines);

    final result = await Navigator.of(context).push<DraftPreviewResult>(
      MaterialPageRoute(
        builder: (_) => DraftPreviewScreen(draft: draft, settings: settings),
      ),
    );
    if (!mounted || result == null || result == DraftPreviewResult.keepEditing) return;
    await _save(thenSend: result == DraftPreviewResult.saveAndSend);
  }

  Future<void> _save({bool thenSend = false}) async {
    final appState = context.read<AppState>();
    final collected = _collect(persistClient: true);
    if (collected == null) return;

    final existing = widget.existing;
    if (existing != null) {
      await appState.updateDocument(
        existing.id,
        client: collected.client,
        lines: collected.lines,
        vatEnabled: _vatEnabled,
        notes: _notesCtrl.text.trim(),
        dueDays: existing.type == DocType.invoice ? _dueDays : null,
        method: existing.type == DocType.receipt ? _method : null,
      );
      if (!mounted) return;
      _toast('${existing.number} updated');
      Navigator.of(context).pop(thenSend);
      return;
    }

    final doc = await appState.createDocument(
      type: _type,
      client: collected.client,
      lines: collected.lines,
      vatEnabled: _vatEnabled,
      notes: _notesCtrl.text.trim(),
      dueDays: _type == DocType.invoice ? _dueDays : null,
      method: _type == DocType.receipt ? _method : null,
    );
    if (!mounted) return;
    _toast('${doc.number} saved on this phone');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(docId: doc.id, openShareImmediately: thenSend),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currency = appState.settings.currency;
    final style = AppTheme.typeStyle(_type);
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(style, appState),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  if (_isNew) _typeSegments(),
                  Text('CLIENT', style: AppTheme.caption()),
                  const SizedBox(height: 9),
                  _clientChips(appState, style),
                  if (_newClientMode) _newClientCard(),
                  if (_type == DocType.invoice) _dueSection(),
                  if (_type == DocType.receipt) _methodSection(),
                  const SizedBox(height: 22),
                  Text('THE WORK', style: AppTheme.caption()),
                  const SizedBox(height: 9),
                  for (final line in _lines) _lineCard(line, currency),
                  _addLineButton(accent),
                  const SizedBox(height: 22),
                  _notesSection(),
                  const SizedBox(height: 16),
                  _totalsPanel(currency, accent),
                ],
              ),
            ),
            _bottomBar(currency, accent),
          ],
        ),
      ),
    );
  }

  Widget _header(DocTypeStyle style, AppState appState) {
    final existing = widget.existing;
    final numberLine = existing != null
        ? existing.number
        : 'Will be ${appState.previewNextNumber(_type)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.close, size: 24, color: Color(0xFF55554F)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_isNew ? 'New' : 'Edit'} ${style.short.toLowerCase()}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: style.fg),
                ),
                Text(numberLine, style: AppTheme.mono(fontSize: 11.5, color: AppTheme.mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Only offered while the document is new: changing the type of an issued
  /// document would strand its number in the wrong sequence.
  Widget _typeSegments() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.chipBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final type in DocType.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _type = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _type == type ? AppTheme.typeStyle(type).fg : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    AppTheme.typeStyle(type).short,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: _type == type ? Colors.white : AppTheme.subtleText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _clientChips(AppState appState, DocTypeStyle style) {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 7),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? style.bg : Colors.white,
              border: Border.all(color: selected ? style.fg : AppTheme.border, width: 1.5),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? style.fg : AppTheme.bodyText,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('+ New client', _newClientMode, () {
            setState(() {
              _newClientMode = true;
              _clientId = null;
            });
          }),
          for (final c in appState.clients)
            chip(c.name, !_newClientMode && _clientId == c.id, () {
              setState(() {
                _newClientMode = false;
                _clientId = c.id;
              });
            }),
        ],
      ),
    );
  }

  Widget _newClientCard() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TextField(
            controller: _ncNameCtrl,
            textInputAction: TextInputAction.next,
            scrollPadding: _keyboardClearance,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(hintText: 'Client or business name'),
          ),
          TextField(
            controller: _ncPhoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            scrollPadding: _keyboardClearance,
            style: AppTheme.mono(fontSize: 13.5),
            decoration: const InputDecoration(hintText: 'WhatsApp number'),
          ),
          TextField(
            controller: _ncPlaceCtrl,
            textInputAction: TextInputAction.next,
            scrollPadding: _keyboardClearance,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(hintText: 'Site / location'),
          ),
        ],
      ),
    );
  }

  Widget _dueSection() {
    final due = _addDays(DateTime.now(), _dueDays);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('PAYMENT DUE', style: AppTheme.caption()),
            const Spacer(),
            Text(
              _dueDays == 0 ? 'On receipt' : 'Due ${formatDocDate(due)}',
              style: AppTheme.mono(fontSize: 12, color: AppTheme.invoiceStyle.fg),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            for (int i = 0; i < kDueDayOptions.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              SelectablePill(
                label: kDueDayOptions[i] == 0 ? 'On receipt' : '${kDueDayOptions[i]} days',
                selected: _dueDays == kDueDayOptions[i],
                accent: AppTheme.invoiceStyle.fg,
                expand: true,
                onTap: () => setState(() => _dueDays = kDueDayOptions[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _methodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('PAID VIA', style: AppTheme.caption()),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final m in kPaymentMethods)
              SelectablePill(
                label: m,
                selected: _method == m,
                accent: AppTheme.receiptStyle.fg,
                onTap: () => setState(() => _method = m),
              ),
          ],
        ),
      ],
    );
  }

  Widget _lineCard(LineItem line, String currency) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E4)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _descCtrls[line.id],
                  textInputAction: TextInputAction.next,
                  scrollPadding: _keyboardClearance,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 4MP dome camera, installed',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => line.description = v),
                ),
              ),
              GestureDetector(
                onTap: () => _removeLine(line),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 6, bottom: 4),
                  child: Icon(Icons.close, size: 18, color: Color(0xFFB5B5AE)),
                ),
              ),
            ],
          ),
          _extraLineField(line),
          const SizedBox(height: 10),
          Row(
            children: [
              _stepper(Icons.remove, () {
                if (line.quantity > 1) setState(() => line.quantity -= 1);
              }),
              SizedBox(
                width: 26,
                child: Text(
                  line.quantity == line.quantity.roundToDouble()
                      ? line.quantity.toStringAsFixed(0)
                      : line.quantity.toString(),
                  textAlign: TextAlign.center,
                  style: AppTheme.mono(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              _stepper(Icons.add, () => setState(() => line.quantity += 1)),
              const SizedBox(width: 7),
              const Text('x', style: TextStyle(color: AppTheme.faintText, fontSize: 13)),
              const SizedBox(width: 7),
              SizedBox(
                width: 92,
                child: TextField(
                  controller: _priceCtrls[line.id],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  scrollPadding: _keyboardClearance,
                  inputFormatters: [_ThousandsFormatter()],
                  style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'price',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                  onChanged: (v) {
                    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                    setState(() => line.unitPrice = digits.isEmpty ? 0 : double.parse(digits));
                  },
                ),
              ),
              const Spacer(),
              Text(
                formatMoney(line.amount, currency),
                style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Removing the last line leaves a blank one behind: a document with no
  /// lines at all cannot be saved, so an empty form is friendlier than an
  /// empty list with nothing to type into.
  void _removeLine(LineItem line) {
    setState(() {
      if (_lines.length > 1) {
        _lines.remove(line);
        _disposeControllers(line.id);
      } else {
        _descCtrls[line.id]?.clear();
        _priceCtrls[line.id]?.clear();
        _unitCtrls[line.id]?.clear();
        _categoryCtrls[line.id]?.clear();
        line.description = '';
        line.quantity = 1;
        line.unitPrice = 0;
        line.unit = '';
        line.category = '';
      }
    });
  }

  /// Quotations group their work by category; invoices and receipts count
  /// theirs in units. Only the one this type actually prints is shown, so
  /// the line card never carries a field that leads nowhere.
  Widget _extraLineField(LineItem line) {
    final isQuote = _type == DocType.quotation;
    final controller = isQuote ? _categoryCtrls[line.id] : _unitCtrls[line.id];

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            isQuote ? 'Group' : 'Units',
            style: AppTheme.mono(fontSize: 10.5, color: AppTheme.mutedText),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.next,
              scrollPadding: _keyboardClearance,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: isQuote ? 'e.g. Roof, Gutters, Painting' : 'e.g. pcs, roll(s), hrs',
                hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.faintText),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (v) => setState(() {
                if (isQuote) {
                  line.category = v;
                } else {
                  line.unit = v;
                }
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.chipBackground,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _addLineButton(Color accent) {
    return GestureDetector(
      onTap: () => setState(() {
        final line = _blankLine();
        _lines.add(line);
        _registerControllers(line);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.strongBorder, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '+ Add a line',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: accent),
        ),
      ),
    );
  }

  Widget _notesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('JOB NOTES', style: AppTheme.caption()),
            const SizedBox(width: 6),
            const Text(
              '- prints on the PDF',
              style: TextStyle(fontSize: 11.5, color: AppTheme.mutedText),
            ),
          ],
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _notesCtrl,
          minLines: 3,
          maxLines: 6,
          scrollPadding: _keyboardClearance,
          style: const TextStyle(fontSize: 13.5, height: 1.5),
          decoration: InputDecoration(
            hintText: 'Site conditions, what is not included, warranty exclusions...',
            contentPadding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE7E7E4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE7E7E4)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalsPanel(String currency, Color accent) {
    final vatPercent = (_vatRate * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Subtotal', style: TextStyle(fontSize: 14, color: Color(0xFF55554F))),
              const Spacer(),
              Text(formatMoney(_subtotal, currency), style: AppTheme.mono(fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              TickBox(
                checked: _vatEnabled,
                accent: accent,
                label: 'VAT $vatPercent%',
                onTap: () => setState(() => _vatEnabled = !_vatEnabled),
              ),
              const Spacer(),
              Text(formatMoney(_vatAmount, currency), style: AppTheme.mono(fontSize: 13.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(String currency, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFECECEA))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('TOTAL', style: AppTheme.caption(fontSize: 11)),
                Text(
                  formatMoney(_total, currency),
                  style: AppTheme.mono(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _save(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.strongBorder),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _preview,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(15)),
              child: const Text(
                'Preview',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same day arithmetic the store uses, so the due date previewed here is
/// the one that actually gets saved.
DateTime _addDays(DateTime from, int days) => DateTime(from.year, from.month, from.day + days);
