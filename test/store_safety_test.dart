import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:digiflect_quotes/data/repository.dart';
import 'package:digiflect_quotes/models/document.dart';
import 'package:digiflect_quotes/models/line_item.dart';
import 'package:digiflect_quotes/models/settings.dart';
import 'package:digiflect_quotes/state/app_state.dart';
import 'package:digiflect_quotes/utils/amount_words.dart';

/// A fixed directory, unlike the throwaway one the widget test uses — these
/// tests are specifically about what survives between a write and a read.
late Directory _dir;

class _FixedPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => _dir.path;
}

File get _storeFile => File('${_dir.path}/${Repository.storeFileName}');

/// A store in the shape the first release wrote: no schema version, no
/// invoices, no notes, due dates, links, units or categories.
String _v1Store() => jsonEncode({
  'clients': [
    {'id': 'c1', 'name': 'Nakawa Hardware', 'phone': '+256 701 445 902', 'location': 'Nakawa'},
  ],
  'documents': [
    {
      'id': 'd1',
      'type': 'quotation',
      'status': 'sent',
      'number': 'DGF-Q-0042',
      'date': '2026-08-02T00:00:00.000',
      'clientId': 'c1',
      'clientName': 'Nakawa Hardware',
      'clientPhone': '+256 701 445 902',
      'clientLocation': 'Nakawa',
      'lines': [
        {'id': 'l1', 'description': 'Router replacement', 'quantity': 1, 'unitPrice': 240000},
      ],
      'vatEnabled': false,
      'vatRate': 0.18,
    },
  ],
  'settings': {
    'businessName': 'Digiflect Tech',
    'tagline': 'CCTV',
    'phone': '+256 772 000 000',
    'location': 'Kampala',
    'brandColorIndex': 0,
    'chargeVat': true,
    'vatRate': 0.18,
    'currency': 'UGX',
    'quoteSeq': 42,
    'receiptSeq': 18,
    'terms': 'Valid 14 days',
  },
});

void main() {
  setUp(() async {
    _dir = await Directory.systemTemp.createTemp('jobslip_store');
    PathProviderPlatform.instance = _FixedPathProvider();
  });

  group('updating must not cost the user their records', () {
    test('a store written by the previous version loads in full', () async {
      await _storeFile.writeAsString(_v1Store());

      final appState = AppState();
      await appState.load();

      expect(appState.storeUnreadable, isFalse);
      expect(appState.needsOnboarding, isFalse);
      expect(appState.clients, hasLength(1));
      expect(appState.documents, hasLength(1));
      expect(appState.documents.single.number, 'DGF-Q-0042');
      expect(appState.settings.businessName, 'Digiflect Tech');
      // Fields that did not exist yet come back as sensible blanks.
      expect(appState.settings.invoiceSeq, 0);
      expect(appState.documents.single.notes, isEmpty);
      expect(appState.documents.single.lines.single.unit, isEmpty);
      expect(appState.previewNextNumber(DocType.quotation), 'DIG-Q-0043');
    });

    test('the interim preparedBy key still reads as the prepared name', () {
      final settings = BusinessSettings.fromJson({
        'businessName': 'Digiflect Tech',
        'tagline': '',
        'phone': '',
        'location': '',
        'brandColorIndex': 0,
        'chargeVat': false,
        'vatRate': 0.18,
        'currency': 'UGX',
        'quoteSeq': 0,
        'receiptSeq': 0,
        'terms': '',
        'preparedBy': 'D. Kato',
      });
      expect(settings.preparedName, 'D. Kato');
      expect(settings.preparedPhone, isEmpty);
    });

    test('a damaged store is never mistaken for a fresh install', () async {
      await _storeFile.writeAsString('{"clients": [ this is not json');

      final appState = AppState();
      await appState.load();

      // The dangerous outcome would be needsOnboarding == true, which walks
      // the user through "setting up" and then saves over their records.
      expect(appState.storeUnreadable, isTrue);
      expect(appState.needsOnboarding, isFalse);
      expect(appState.quarantinePath, isNotNull);
      expect(File(appState.quarantinePath!).existsSync(), isTrue);
    });

    test('nothing is written while the store is unreadable', () async {
      const damaged = '{"clients": [ this is not json';
      await _storeFile.writeAsString(damaged);

      final appState = AppState();
      await appState.load();
      expect(appState.storeUnreadable, isTrue);

      // Ordinary use that would normally persist.
      final client = appState.findOrCreateClient(name: 'Walk-in', phone: '', location: '');
      await appState.updateSettings(appState.settings.clone()..businessName = 'Changed');
      expect(client.name, 'Walk-in');

      // The original bytes are still on disk, untouched.
      expect(await _storeFile.readAsString(), damaged);
    });

    test('one unreadable document does not take the rest with it', () async {
      final store = jsonDecode(_v1Store()) as Map<String, dynamic>;
      final documents = store['documents'] as List;
      documents.add({'id': 'broken', 'type': 'quotation'}); // missing required keys
      await _storeFile.writeAsString(jsonEncode(store));

      final appState = AppState();
      await appState.load();

      expect(appState.storeUnreadable, isFalse);
      expect(appState.documents, hasLength(1));
      expect(appState.documents.single.number, 'DGF-Q-0042');
    });

    test('what this version writes, this version reads back whole', () async {
      final first = AppState();
      await first.load();
      await first.completeOnboarding(
        BusinessSettings.initial()
          ..businessName = 'Digiflect Tech'
          ..tin = '1000085092'
          ..preparedName = 'Najjuma Harriet'
          ..preparedPhone = '0762151666',
      );

      final client = first.findOrCreateClient(
        name: 'Mrs. Achieng',
        phone: '+256 758 620 117',
        location: 'Najjera',
      );
      final invoice = await first.createDocument(
        type: DocType.invoice,
        client: client,
        lines: [
          LineItem(
            id: 'l1',
            description: 'Outdoor bullet camera, replaced',
            quantity: 2,
            unitPrice: 165000,
            unit: 'pcs',
            category: 'Cameras',
          ),
        ],
        vatEnabled: false,
        notes: 'Power points provided by client.',
        dueDays: 7,
      );

      // A second AppState over the same directory is what the next launch -
      // or the next app update - actually does.
      final reopened = AppState();
      await reopened.load();

      expect(reopened.storeUnreadable, isFalse);
      expect(reopened.needsOnboarding, isFalse);
      expect(reopened.settings.tin, '1000085092');
      expect(reopened.settings.preparedName, 'Najjuma Harriet');
      expect(reopened.settings.preparedPhone, '0762151666');
      expect(reopened.clients.single.name, 'Mrs. Achieng');

      final reloaded = reopened.documents.single;
      expect(reloaded.number, invoice.number);
      expect(reloaded.notes, 'Power points provided by client.');
      expect(reloaded.dueDays, 7);
      expect(reloaded.dueDate, isNotNull);
      expect(reloaded.lines.single.unit, 'pcs');
      expect(reloaded.lines.single.category, 'Cameras');
      expect(reloaded.total, invoice.total);
    });
  });

  group('amount in words', () {
    test('reads the way an invoice prints it', () {
      expect(
        amountInWords(34690000, 'UGX'),
        'Thirty-Four Million, Six Hundred Ninety Thousand Uganda Shillings Only',
      );
      expect(amountInWords(1500, 'KES'), 'One Thousand, Five Hundred Kenya Shillings Only');
      expect(amountInWords(0, 'UGX'), 'Zero Uganda Shillings Only');
      expect(amountInWords(115, 'USD'), 'One Hundred Fifteen US Dollars Only');
    });

    test('an unknown currency falls back to its code rather than breaking', () {
      expect(amountInWords(42, 'ZAR'), 'Forty-Two ZAR Only');
    });
  });
}
