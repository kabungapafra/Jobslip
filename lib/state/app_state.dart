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

  void setTab(int index) {
    tabIndex = index;
    notifyListeners();
  }

  Future<void> load() async {
    final data = await _repo.load();
    if (data == null) {
      clients = [];
      documents = [];
      settings = BusinessSettings.initial();
      needsOnboarding = true;
    } else {
      clients = (data['clients'] as List)
          .map((c) => Client.fromJson(c as Map<String, dynamic>))
          .toList();
      documents = (data['documents'] as List)
          .map((d) => DocumentModel.fromJson(d as Map<String, dynamic>))
          .toList();
      settings = data['settings'] != null
          ? BusinessSettings.fromJson(data['settings'] as Map<String, dynamic>)
          : BusinessSettings.initial();
      needsOnboarding = false;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding(BusinessSettings updated) async {
    settings = updated;
    needsOnboarding = false;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _repo.save(clients: clients, documents: documents, settings: settings);
    } catch (_) {
      // Best-effort: an offline single-user app should keep working in
      // memory for the session even if the disk write fails.
    }
  }

  // ---------------- Clients ----------------

  Client findOrCreateClient({
    required String name,
    required String phone,
    required String location,
  }) {
    final existing = clients.where(
      (c) => c.name.trim().toLowerCase() == name.trim().toLowerCase(),
    );
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

  int docCountFor(String clientId) => documents.where((d) => d.clientId == clientId).length;

  double totalFor(String clientId) =>
      documents.where((d) => d.clientId == clientId).fold(0.0, (s, d) => s + d.total);

  Future<void> deleteClient(String clientId) async {
    // Removing a client also removes every quotation/receipt made for
    // them, so the dashboard never shows paperwork for someone who no
    // longer has a client record.
    clients.removeWhere((c) => c.id == clientId);
    documents.removeWhere((d) => d.clientId == clientId);
    await _persist();
    notifyListeners();
  }

  // ---------------- Documents ----------------

  double get awaitingTotal =>
      documents.where((d) => d.status != DocStatus.paid).fold(0.0, (s, d) => s + d.total);

  String _nextNumber(DocType type) {
    final prefix = settings.numberPrefix;
    if (type == DocType.quotation) {
      settings.quoteSeq += 1;
      return '$prefix-Q-${settings.quoteSeq.toString().padLeft(4, '0')}';
    } else {
      settings.receiptSeq += 1;
      return '$prefix-R-${settings.receiptSeq.toString().padLeft(4, '0')}';
    }
  }

  String previewNextNumber(DocType type) {
    final seq = type == DocType.quotation ? settings.quoteSeq + 1 : settings.receiptSeq + 1;
    final prefix = '${settings.numberPrefix}-${type == DocType.quotation ? 'Q' : 'R'}-';
    return '$prefix${seq.toString().padLeft(4, '0')}';
  }

  Future<DocumentModel> createDocument({
    required DocType type,
    required Client client,
    required List<LineItem> lines,
    required bool vatEnabled,
    bool paid = false,
  }) async {
    final doc = DocumentModel(
      id: _uuid.v4(),
      type: type,
      // Not-paid unless explicitly set — the "Paid" toggle on the line
      // editor (receipts only) is what puts the PAID stamp on the PDF.
      status: paid ? DocStatus.paid : DocStatus.draft,
      number: _nextNumber(type),
      date: DateTime.now(),
      clientId: client.id,
      clientName: client.name,
      clientPhone: client.phone,
      clientLocation: client.location,
      lines: lines,
      vatEnabled: vatEnabled,
      vatRate: settings.vatRate,
    );
    documents.insert(0, doc);
    await _persist();
    notifyListeners();
    return doc;
  }

  Future<void> updateLines(String docId, List<LineItem> lines, bool vatEnabled) async {
    final doc = documents.firstWhere((d) => d.id == docId);
    doc.lines = lines;
    doc.vatEnabled = vatEnabled;
    await _persist();
    notifyListeners();
  }

  Future<void> setStatus(String docId, DocStatus status) async {
    final doc = documents.firstWhere((d) => d.id == docId);
    doc.status = status;
    await _persist();
    notifyListeners();
  }

  Future<DocumentModel> convertToReceipt(String docId) async {
    final quote = documents.firstWhere((d) => d.id == docId);
    quote.status = DocStatus.paid;
    final receipt = DocumentModel(
      id: _uuid.v4(),
      type: DocType.receipt,
      status: DocStatus.paid,
      number: _nextNumber(DocType.receipt),
      date: DateTime.now(),
      clientId: quote.clientId,
      clientName: quote.clientName,
      clientPhone: quote.clientPhone,
      clientLocation: quote.clientLocation,
      lines: quote.lines.map((l) => LineItem(
            id: _uuid.v4(),
            description: l.description,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
          )).toList(),
      vatEnabled: quote.vatEnabled,
      vatRate: quote.vatRate,
    );
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
    settings.quoteSeq = 42;
    settings.receiptSeq = 18;
    await _persist();
    notifyListeners();
  }

  // ---------------- Backup / restore ----------------

  /// Builds a single self-contained backup file (clients, documents,
  /// settings, logo). The caller hands this to the share sheet so the user
  /// can pick their own email app — this method never touches the network.
  Future<File> createBackupFile() {
    return _backup.createBackupFile(clients: clients, documents: documents, settings: settings);
  }

  /// Replaces everything on this phone with what's in the backup file.
  /// Throws [BackupParseException] if the file isn't a valid JobSlip backup.
  Future<void> restoreFromBackupFile(File file) async {
    final parsed = await _backup.parseBackupFile(file);
    clients = parsed.clients;
    documents = parsed.documents;
    settings = parsed.settings;
    needsOnboarding = false;
    await _persist();
    notifyListeners();
  }
}
