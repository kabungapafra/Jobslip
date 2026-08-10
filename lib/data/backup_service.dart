import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/client.dart';
import '../models/document.dart';
import '../models/settings.dart';

class BackupParseException implements Exception {
  final String message;
  BackupParseException(this.message);
  @override
  String toString() => message;
}

class ParsedBackup {
  final List<Client> clients;
  final List<DocumentModel> documents;
  final BusinessSettings settings;
  ParsedBackup({required this.clients, required this.documents, required this.settings});
}

/// A backup is a single self-contained JSON file: clients, documents,
/// settings, and — if one is set — the logo image embedded as base64, so
/// restoring on a different phone (or after a reinstall) doesn't depend on
/// a file path that no longer exists. No network involved in building or
/// reading it; only the hand-off (sharing it, or picking it back up) needs
/// connectivity, and that's the user's own email app, not this app.
class BackupService {
  static const _formatVersion = 1;

  Future<File> createBackupFile({
    required List<Client> clients,
    required List<DocumentModel> documents,
    required BusinessSettings settings,
  }) async {
    String? logoBase64;
    String? logoExt;
    final logoPath = settings.logoPath;
    if (logoPath != null) {
      final logoFile = File(logoPath);
      if (await logoFile.exists()) {
        logoBase64 = base64Encode(await logoFile.readAsBytes());
        logoExt = logoPath.split('.').last;
      }
    }

    final payload = {
      'app': 'JobSlip',
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'clients': clients.map((c) => c.toJson()).toList(),
      'documents': documents.map((d) => d.toJson()).toList(),
      'settings': settings.toJson(),
      if (logoBase64 != null) 'logoBase64': logoBase64,
      if (logoExt != null) 'logoExt': logoExt,
    };

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final safeName = settings.businessName.trim().isEmpty
        ? 'jobslip'
        : settings.businessName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    final file = File('${dir.path}/backup-$safeName-$stamp.json');
    await file.writeAsString(jsonEncode(payload));
    return file;
  }

  Future<ParsedBackup> parseBackupFile(File file) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      throw BackupParseException("That file doesn't look like a JobSlip backup.");
    }

    if (data['app'] != 'JobSlip' || data['clients'] == null || data['documents'] == null || data['settings'] == null) {
      throw BackupParseException("That file doesn't look like a JobSlip backup.");
    }

    try {
      final settings = BusinessSettings.fromJson(data['settings'] as Map<String, dynamic>);

      final logoBase64 = data['logoBase64'] as String?;
      if (logoBase64 != null) {
        final ext = (data['logoExt'] as String?) ?? 'png';
        final dir = await getApplicationDocumentsDirectory();
        final logoFile = File('${dir.path}/business_logo_restored.$ext');
        await logoFile.writeAsBytes(base64Decode(logoBase64));
        settings.logoPath = logoFile.path;
      } else {
        settings.logoPath = null;
      }

      final clients = (data['clients'] as List)
          .map((c) => Client.fromJson(c as Map<String, dynamic>))
          .toList();
      final documents = (data['documents'] as List)
          .map((d) => DocumentModel.fromJson(d as Map<String, dynamic>))
          .toList();

      return ParsedBackup(clients: clients, documents: documents, settings: settings);
    } catch (_) {
      throw BackupParseException('This backup file is damaged or from an incompatible version.');
    }
  }
}
