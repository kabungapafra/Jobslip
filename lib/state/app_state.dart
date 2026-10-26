import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/backup_service.dart';
import '../data/repository.dart';
import '../data/seed_data.dart';
import '../models/client.dart';
import '../models/document.dart';
import '../models/line_item.dart';
import '../models/settings.dart';

const _uuid = Uuid();

/// The number segment for a type ("Q", "INV", "R"). Deliberately not taken
/// from the theme, so numbering never depends on anything visual.
String _numberCode(DocType type) {
  switch (type) {
    case DocType.quotation:
      return 'Q';
    case DocType.invoice:
      return 'INV';
    case DocType.receipt:
      return 'R';
  }
}

/// The five bottom-nav destinations. Setup is deliberately not one of them:
/// it is pushed from the home header, which keeps the bar to the parts of
/// the app that are about money.
enum AppTab { home, quotes, invoices, receipts, clients }

class AppState extends ChangeNotifier {
  final Repository _repo = Repository();
  final BackupService _backup = BackupService();

  List<Client> clients = [];
  List<DocumentModel> documents = [];
  BusinessSettings settings = BusinessSettings.initial();

  bool loaded = false;
  int tabIndex = 0;

  /// True only until a fresh install finishes (or skips) the one-time
  /// branding screen. Nothing is persisted to disk for a first run until
  /// that happens, so killing the app mid-onboarding just asks again next
  /// launch instead of silently adopting blank/default branding.
  bool needsOnboarding = false;

  /// Set when the store file exists but could not be read. The app stays
  /// usable, but **nothing is written to disk** while this is true: an
  /// unreadable store is still the user's only copy of their business, and
  /// saving over it would finish the job the corruption started.
  bool storeUnreadable = false;

  /// Where the unreadable store was copied to, so it can be named to the
  /// user instead of disappearing.
  String? quarantinePath;

  AppTab get tab => AppTab.values[tabIndex];

  void setTab(int index) {
    tabIndex = index;
    notifyListeners();
  }

  void goToTab(AppTab tab) => setTab(tab.index);

  /// Jumps to a type's list tab — used by the home screen's shortcuts.
  void showList(DocType type) {
    switch (type) {
      case DocType.quotation:
        goToTab(AppTab.quotes);
      case DocType.invoice:
        goToTab(AppTab.invoices);
      case DocType.receipt:
        goToTab(AppTab.receipts);
    }
  }

  Future<void> load() async {
    final result = await _repo.load();

    switch (result.state) {
      case StoreState.missing:
        clients = [];
        documents = [];
        settings = BusinessSettings.initial();
        needsOnboarding = true;

      case StoreState.unreadable:
        // Deliberately NOT treated as a fresh install. Onboarding here would
        // walk the user through "setting up" an app that already holds their
        // records, and the first save would overwrite them.
        clients = [];
        documents = [];
        settings = BusinessSettings.initial();
        needsOnboarding = false;
        storeUnreadable = true;
        quarantinePath = result.quarantinePath;

      case StoreState.ok:
        final data = result.data!;
        clients = _parseList(data['clients'], Client.fromJson);
        documents = _parseList(data['documents'], DocumentModel.fromJson);
        settings = data['settings'] is Map<String, dynamic>
            ? BusinessSettings.fromJson(data['settings'] as Map<String, dynamic>)
            : BusinessSettings.initial();
        needsOnboarding = false;
    }

    loaded = true;
    notifyListeners();
  }

  /// Reads a list of records, skipping any single entry that will not parse
  /// rather than losing the whole book to one bad row. A document written by
  /// a newer version, or one damaged in transit, costs the user that one
  /// document instead of all of them.
  static List<T> _parseList<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) return [];
    final out = <T>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        out.add(parse(entry));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Future<void> completeOnboarding(BusinessSettings updated) async {
    settings = updated;
    needsOnboarding = false;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    // The one case where not saving is the safer act.
    if (storeUnreadable) return;
    try {
      await _repo.save(clients: clients, documents: documents, settings: settings);
    } catch (_) {
      // Best-effort: an offline single-user app should keep working in
      // memory for the session even if the disk write fails.
    }
  }

  /// Accepts that the unreadable store is not coming back and lets the app
  /// write again. Only reached by explicit user action, never automatically.
  Future<void> discardUnreadableStore() async {
    storeUnreadable = false;
    needsOnboarding = true;
    await _persist();
    notifyListeners();
  }

  // ---------------- Clients ----------------

  Client findOrCreateClient({
    required String name,
    required String phone,
    required String location,
  }) {
    final existing = clients.where((c) => c.name.trim().toLowerCase() == name.trim().toLowerCase());
    if (existing.isNotEmpty) {
      final c = existing.first;
      c.phone = phone;
      c.location = location;
      return c;
    }
    final client = Client(id: _uuid.v4(), name: name, phone: phone, location: location);
    clients.add(client);
    return client;
  }

  Client? clientById(String id) {
    for (final c in clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  int docCountFor(String clientId) => documents.where((d) => d.clientId == clientId).length;

  double totalFor(String clientId) =>
      documents.where((d) => d.clientId == clientId).fold(0.0, (s, d) => s + d.total);

  /// What this client still owes — unpaid invoices only, so a long history
  /// of settled work doesn't read as a debt.
  double outstandingFor(String clientId) => documents
      .where((d) => d.clientId == clientId && d.isOutstanding)
      .fold(0.0, (s, d) => s + d.total);

  bool hasOverdueFor(String clientId) =>
      documents.any((d) => d.clientId == clientId && d.isOverdue());

  Future<void> deleteClient(String clientId) async {
    // Removing a client also removes every document made for them, so no
    // screen ever shows paperwork for someone who no longer has a record.
    clients.removeWhere((c) => c.id == clientId);
    documents.removeWhere((d) => d.clientId == clientId);
    await _persist();
    notifyListeners();
  }

  // ---------------- Reading the books ----------------

  /// Newest first, falling back to the document number so two documents
  /// written on the same day keep a stable order.
  List<DocumentModel> sorted(Iterable<DocumentModel> docs) {
    final list = docs.toList();
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.number.compareTo(a.number);
    });
    return list;
  }

  List<DocumentModel> ofType(DocType type) => documents.where((d) => d.type == type).toList();

  List<DocumentModel> get unpaidInvoices => documents.where((d) => d.isOutstanding).toList();

  List<DocumentModel> get overdueInvoices => documents.where((d) => d.isOverdue()).toList();

  /// Quotes still waiting on an answer — not yet turned into an invoice or
  /// a receipt.
  List<DocumentModel> get openQuotes => documents
      .where(
        (d) =>
            d.type == DocType.quotation &&
            (d.status == DocStatus.draft || d.status == DocStatus.sent),
      )
      .toList();

  List<DocumentModel> receiptsIn(DateTime month) => documents
      .where(
        (d) =>
            d.type == DocType.receipt && d.date.year == month.year && d.date.month == month.month,
      )
      .toList();

  static double sumOf(Iterable<DocumentModel> docs) => docs.fold(0.0, (s, d) => s + d.total);

  /// Everything still owed to the business.
  double get owedTotal => sumOf(unpaidInvoices);

  double get overdueTotal => sumOf(overdueInvoices);

  double get collectedThisMonth => sumOf(receiptsIn(DateTime.now()));

  /// The home screen's "needs a nudge" list: what is late first, then what
  /// is merely outstanding, then quotes the client hasn't answered.
  List<DocumentModel> attentionList({int limit = 4}) {
    final overdue = sorted(overdueInvoices);
    final stillDue = sorted(unpaidInvoices.where((d) => !d.isOverdue()));
    final awaitingReply = sorted(
      documents.where((d) => d.type == DocType.quotation && d.status == DocStatus.sent),
    );
    return [...overdue, ...stillDue, ...awaitingReply].take(limit).toList();
  }

  DocumentModel? docById(String id) {
    for (final d in documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  DocumentModel? docByNumber(String number) {
    for (final d in documents) {
      if (d.number == number) return d;
    }
    return null;
  }

  // ---------------- Numbering ----------------

  int _seqFor(DocType type) {
    switch (type) {
      case DocType.quotation:
        return settings.quoteSeq;
      case DocType.invoice:
        return settings.invoiceSeq;
      case DocType.receipt:
        return settings.receiptSeq;
    }
  }

  void _bumpSeq(DocType type) {
    switch (type) {
      case DocType.quotation:
        settings.quoteSeq += 1;
      case DocType.invoice:
        settings.invoiceSeq += 1;
      case DocType.receipt:
        settings.receiptSeq += 1;
    }
  }

  String _formatNumber(DocType type, int seq) =>
      '${settings.numberPrefix}-${_numberCode(type)}-${seq.toString().padLeft(4, '0')}';

  String _nextNumber(DocType type) {
    _bumpSeq(type);
    return _formatNumber(type, _seqFor(type));
  }

  /// What the next document of this type will be called, without consuming
  /// the number.
  String previewNextNumber(DocType type) => _formatNumber(type, _seqFor(type) + 1);

  // ---------------- Writing documents ----------------

  Future<DocumentModel> createDocument({
    required DocType type,
    required Client client,
    required List<LineItem> lines,
    required bool vatEnabled,
    String notes = '',
    int? dueDays,
    String? method,
    DateTime? date,
  }) async {
    final issued = date ?? DateTime.now();
    final credit = dueDays ?? settings.dueDefaultDays;

    final doc = DocumentModel(
      id: _uuid.v4(),
      type: type,
      status: _initialStatus(type),
      number: _nextNumber(type),
      date: issued,
      clientId: client.id,
      clientName: client.name,
      clientPhone: client.phone,
      clientLocation: client.location,
      lines: lines,
      vatEnabled: vatEnabled,
      vatRate: settings.vatRate,
      notes: notes,
      dueDays: type == DocType.invoice ? credit : null,
      dueDate: type == DocType.invoice ? _addDays(issued, credit) : null,
      paidOn: type == DocType.receipt ? issued : null,
      method: type == DocType.receipt ? (method ?? kPaymentMethods.first) : null,
    );
    documents.insert(0, doc);
    await _persist();
    notifyListeners();
    return doc;
  }

  /// A quote starts as a draft, an invoice as money owed, a receipt as
  /// money already in hand.
  static DocStatus _initialStatus(DocType type) {
    switch (type) {
      case DocType.quotation:
        return DocStatus.draft;
      case DocType.invoice:
        return DocStatus.unpaid;
      case DocType.receipt:
        return DocStatus.paid;
    }
  }

  static DateTime _addDays(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day + days);

  /// Saves an edit in place. The document keeps its number and its issue
  /// date — only the contents change — and the due date is recomputed so a
  /// changed credit period takes effect.
  Future<void> updateDocument(
    String docId, {
    Client? client,
    List<LineItem>? lines,
    bool? vatEnabled,
    String? notes,
    int? dueDays,
    String? method,
  }) async {
    final doc = documents.firstWhere((d) => d.id == docId);
    if (lines != null) doc.lines = lines;
    if (vatEnabled != null) doc.vatEnabled = vatEnabled;
    if (notes != null) doc.notes = notes;
    if (method != null) doc.method = method;
    if (client != null) {
      doc.clientName = client.name;
      doc.clientPhone = client.phone;
      doc.clientLocation = client.location;
    }
    if (dueDays != null && doc.type == DocType.invoice) {
      doc.dueDays = dueDays;
      doc.dueDate = _addDays(doc.date, dueDays);
    }
    await _persist();
    notifyListeners();
  }

  /// Kept for the simpler "just the lines changed" path.
  Future<void> updateLines(String docId, List<LineItem> lines, bool vatEnabled) =>
      updateDocument(docId, lines: lines, vatEnabled: vatEnabled);

  Future<void> setStatus(String docId, DocStatus status) async {
    final doc = documents.firstWhere((d) => d.id == docId);
    doc.status = status;
    await _persist();
    notifyListeners();
  }

  /// Undo a wrongly recorded payment. A receipt that was already issued is
  /// left alone — it may be in the client's hands already — but the link is
  /// dropped so the invoice can be settled again cleanly.
  Future<void> markUnpaid(String docId) async {
    final doc = documents.firstWhere((d) => d.id == docId);
    doc.status = DocStatus.unpaid;
    doc.paidOn = null;
    doc.method = null;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteDocument(String docId) async {
    final doc = docById(docId);
    if (doc == null) return;
    documents.removeWhere((d) => d.id == docId);
    // The sequence is deliberately *not* rewound: a number that was issued
    // to a client stays spent, so two documents can never share one.
    for (final other in documents) {
      if (other.fromNumber == doc.number) other.fromNumber = null;
      if (other.invoiceNumber == doc.number) other.invoiceNumber = null;
      if (other.receiptNumber == doc.number) other.receiptNumber = null;
    }
    await _persist();
    notifyListeners();
  }

  /// Copies [source] into a new document of [type], carrying the lines, the
  /// notes and the VAT choice across and recording where it came from.
  DocumentModel _derive(
    DocumentModel source,
    DocType type, {
    required DocStatus status,
    DateTime? date,
    int? dueDays,
    String? method,
  }) {
    final issued = date ?? DateTime.now();
    final credit = dueDays ?? settings.dueDefaultDays;
    return DocumentModel(
      id: _uuid.v4(),
      type: type,
      status: status,
      number: _nextNumber(type),
      date: issued,
      clientId: source.clientId,
      clientName: source.clientName,
      clientPhone: source.clientPhone,
      clientLocation: source.clientLocation,
      lines: source.lines
          .map(
            (l) => LineItem(
              id: _uuid.v4(),
              description: l.description,
              quantity: l.quantity,
              unitPrice: l.unitPrice,
            ),
          )
          .toList(),
      vatEnabled: source.vatEnabled,
      vatRate: source.vatRate,
      notes: source.notes,
      dueDays: type == DocType.invoice ? credit : null,
      dueDate: type == DocType.invoice ? _addDays(issued, credit) : null,
      paidOn: type == DocType.receipt ? issued : null,
      method: type == DocType.receipt ? (method ?? kPaymentMethods.first) : null,
      fromNumber: source.number,
    );
  }

  /// "The client said yes" — turns an accepted quote into either an invoice
  /// (they'll pay later) or a receipt (they already paid), linking the two
  /// so the quote shows what became of it.
  Future<DocumentModel> convertQuote(
    String quoteId, {
    required DocType into,
    String? method,
  }) async {
    final quote = documents.firstWhere((d) => d.id == quoteId);
    final derived = _derive(
      quote,
      into,
      status: into == DocType.invoice ? DocStatus.unpaid : DocStatus.paid,
      method: method,
    );

    if (into == DocType.invoice) {
      quote.status = DocStatus.invoiced;
      quote.invoiceNumber = derived.number;
    } else {
      quote.status = DocStatus.receipted;
      quote.receiptNumber = derived.number;
    }

    documents.insert(0, derived);
    await _persist();
    notifyListeners();
    return derived;
  }

  /// Marks an invoice paid and, when asked, issues the matching receipt in
  /// the same step — which is what the client actually wants in their hand.
  /// Returns the receipt if one was created.
  Future<DocumentModel?> recordPayment(
    String invoiceId, {
    required String method,
    bool alsoIssueReceipt = true,
  }) async {
    final invoice = documents.firstWhere((d) => d.id == invoiceId);
    final now = DateTime.now();
    invoice.status = DocStatus.paid;
    invoice.paidOn = now;
    invoice.method = method;

    DocumentModel? receipt;
    if (alsoIssueReceipt) {
      receipt = _derive(
        invoice,
        DocType.receipt,
        status: DocStatus.paid,
        date: now,
        method: method,
      );
      invoice.receiptNumber = receipt.number;
      documents.insert(0, receipt);
    }

    await _persist();
    notifyListeners();
    return receipt;
  }

  /// Issues the receipt for an invoice that was marked paid without one.
  Future<DocumentModel> issueReceipt(String invoiceId) async {
    final invoice = documents.firstWhere((d) => d.id == invoiceId);
    final receipt = _derive(
      invoice,
      DocType.receipt,
      status: DocStatus.paid,
      date: invoice.paidOn ?? DateTime.now(),
      method: invoice.method ?? kPaymentMethods.first,
    );
    invoice.receiptNumber = receipt.number;
    documents.insert(0, receipt);
    await _persist();
    notifyListeners();
    return receipt;
  }

  // ---------------- Settings ----------------

  Future<void> updateSettings(BusinessSettings newSettings) async {
    settings = newSettings;
    await _persist();
    notifyListeners();
  }

  Future<void> clearAllDocuments() async {
    documents = [];
    await _persist();
    notifyListeners();
  }

  Future<void> restoreSampleDocuments() async {
    clients = SeedData.clients();
    documents = SeedData.documents();
    settings.quoteSeq = SeedData.quoteSeq;
    settings.invoiceSeq = SeedData.invoiceSeq;
    settings.receiptSeq = SeedData.receiptSeq;
    await _persist();
    notifyListeners();
  }

  // ---------------- Backup / restore ----------------

  /// Builds a single self-contained backup file (clients, documents,
  /// settings, logo). The caller hands this to the share sheet so the user
  /// can pick their own WhatsApp or email — this method never touches the
  /// network.
  Future<File> createBackupFile() async {
    final file = await _backup.createBackupFile(
      clients: clients,
      documents: documents,
      settings: settings,
    );
    settings.lastBackupAt = DateTime.now();
    await _persist();
    notifyListeners();
    return file;
  }

  /// Replaces everything on this phone with what's in the backup file.
  /// Throws [BackupParseException] if the file isn't a valid JobSlip backup.
  Future<void> restoreFromBackupFile(File file) async {
    final parsed = await _backup.parseBackupFile(file);
    clients = parsed.clients;
    documents = parsed.documents;
    settings = parsed.settings;
    needsOnboarding = false;
    // A good backup supersedes whatever could not be read, so writing is
    // safe again from here.
    storeUnreadable = false;
    quarantinePath = null;
    await _persist();
    notifyListeners();
  }
}
