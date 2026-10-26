import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/client.dart';
import '../models/document.dart';
import '../models/settings.dart';

/// How a load of the on-device store turned out.
enum StoreState {
  /// Nothing saved yet - a genuinely fresh install.
  missing,

  /// Read and parsed.
  ok,

  /// The file is there but could not be read or parsed. This is NOT a fresh
  /// install, and must never be treated as one: the user's only copy of
  /// their business is in that file.
  unreadable,
}

class StoreLoad {
  final StoreState state;
  final Map<String, dynamic>? data;

  /// Where the unreadable original was copied to, so it can be recovered by
  /// hand rather than being overwritten.
  final String? quarantinePath;

  const StoreLoad(this.state, {this.data, this.quarantinePath});
}

/// Everything is read/written to a single JSON file in the app's local
/// documents directory. No network calls anywhere in this app — that is
/// the whole point of JobSlip: it works with no signal.
class Repository {
  /// Bumped when the on-disk shape changes in a way a reader must know
  /// about. Absent in files written before versioning, which read as 1.
  static const int schemaVersion = 2;

  static const String storeFileName = 'digiflect_store.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$storeFileName');
  }

  Future<StoreLoad> load() async {
    final File file;
    try {
      file = await _file();
      if (!await file.exists()) return const StoreLoad(StoreState.missing);
    } catch (_) {
      // Could not even reach storage; say so rather than inventing a fresh
      // install that would later be written over the real one.
      return const StoreLoad(StoreState.unreadable);
    }

    String raw;
    try {
      raw = await file.readAsString();
    } catch (_) {
      return StoreLoad(StoreState.unreadable, quarantinePath: await _quarantine(file));
    }

    // An empty file is the one ambiguous case. Treat it as missing: there is
    // nothing to lose, and it is what a half-finished first run leaves.
    if (raw.trim().isEmpty) return const StoreLoad(StoreState.missing);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return StoreLoad(StoreState.unreadable, quarantinePath: await _quarantine(file));
      }
      return StoreLoad(StoreState.ok, data: decoded);
    } catch (_) {
      return StoreLoad(StoreState.unreadable, quarantinePath: await _quarantine(file));
    }
  }

  /// Copies an unreadable store aside before anything else touches it, so a
  /// later save cannot destroy whatever is still in there. Returns the copy's
  /// path, or null if even that failed.
  Future<String?> _quarantine(File file) async {
    try {
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final copy = File('${file.path}.unreadable-$stamp');
      await file.copy(copy.path);
      return copy.path;
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
      'schemaVersion': schemaVersion,
      'clients': clients.map((c) => c.toJson()).toList(),
      'documents': documents.map((d) => d.toJson()).toList(),
      'settings': settings.toJson(),
    };

    // Write to a temporary file and rename over the real one. A rename is
    // atomic, so a crash or a flat battery mid-write leaves the previous
    // store intact instead of a half-written file nothing can read.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(file.path);
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
