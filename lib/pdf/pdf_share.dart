import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document.dart';
import '../models/settings.dart';
import 'pdf_builder.dart';

/// Building, sharing and printing the PDF, in one place so the detail
/// screen, the editor and the preview all produce byte-identical files.
///
/// Nothing here touches the network: the file is written to the app's own
/// storage and handed to the system share sheet, which is where WhatsApp,
/// email and everything else the phone has installed show up.
class PdfShare {
  static Future<Uint8List> bytes(DocumentModel doc, BusinessSettings settings) async {
    final pdf = await PdfBuilder.build(doc, settings);
    return pdf.save();
  }

  /// Writes `<number>.pdf` into the app's documents directory and returns
  /// it. The name is the document number, so what lands in the client's
  /// chat is already labelled.
  static Future<File> writeFile(DocumentModel doc, BusinessSettings settings) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${doc.number}.pdf');
    await file.writeAsBytes(await bytes(doc, settings));
    return file;
  }

  /// Hands the PDF to the system share sheet together with the covering
  /// message, so the user picks the app rather than the app guessing.
  static Future<void> share(
    DocumentModel doc,
    BusinessSettings settings, {
    required String message,
  }) async {
    final file = await writeFile(doc, settings);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: '${doc.number} - ${settings.businessName}',
      text: message,
    );
  }

  /// Opens the system print dialog. Works with any printer the phone has a
  /// service for — USB, Bluetooth and Wi-Fi receipt printers included —
  /// and stays entirely offline.
  static Future<void> printDoc(DocumentModel doc, BusinessSettings settings) async {
    final data = await bytes(doc, settings);
    await Printing.layoutPdf(onLayout: (format) async => data, name: '${doc.number}.pdf');
  }
}
