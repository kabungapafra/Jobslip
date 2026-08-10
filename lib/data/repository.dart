import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/client.dart';
import '../models/document.dart';
import '../models/settings.dart';

/// Everything is read/written to a single JSON file in the app's local
/// documents directory. No network calls anywhere in this app — that is
/// the whole point of Digiflect: it works with no signal.
class Repository {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/digiflect_store.json');
  }

  Future<Map<String, dynamic>?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required List<Client> clients,
    required List<DocumentModel> documents,
    required BusinessSettings settings,
  }) async {
    final file = await _file();
    final data = {
      'clients': clients.map((c) => c.toJson()).toList(),
      'documents': documents.map((d) => d.toJson()).toList(),
      'settings': settings.toJson(),
    };
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
