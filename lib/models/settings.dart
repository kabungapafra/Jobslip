import 'package:flutter/material.dart';

class BrandColorOption {
  final String name;
  final Color color;
  const BrandColorOption(this.name, this.color);
}

/// Five fixed slots, in a fixed order — [BusinessSettings.brandColorIndex]
/// is an index into this list and is persisted, so entries may be
/// re-tinted but must never be reordered or removed.
/// The design's own palette. Slot 0 is its default teal, so a fresh install
/// produces documents that match the design without touching Setup.
const List<BrandColorOption> kBrandColors = [
  BrandColorOption('Teal', Color(0xFF1F6F6A)),
  BrandColorOption('Amber', Color(0xFFC8761F)),
  BrandColorOption('Blue', Color(0xFF2F5FA8)),
  BrandColorOption('Plum', Color(0xFF8C3B52)),
  BrandColorOption('Ink', Color(0xFF141414)),
];

/// How a client can hand over money. Offered when recording a payment and
/// when writing a receipt; the chosen one prints on the PDF.
const List<String> kPaymentMethods = ['Cash', 'MTN MoMo', 'Airtel Money', 'Bank'];

/// Credit periods offered for invoices. `0` means "on receipt".
const List<int> kDueDayOptions = [0, 7, 14, 30];

class BusinessSettings {
  String businessName;
  String tagline;
  String phone;
  String location;
  int brandColorIndex;
  bool chargeVat;
  double vatRate;
  String currency;
  int quoteSeq;
  int invoiceSeq;
  int receiptSeq;
  String terms;
  String? logoPath;

  /// How clients pay you — MoMo numbers, bank account. Printed on every
  /// unpaid invoice so the client never has to ask where to send it.
  String payDetails;

  /// Credit period applied to a new invoice unless it is changed on the
  /// document itself.
  int dueDefaultDays;

  /// Tax identification number, printed in the invoice header. Blank means
  /// the row is left off the page entirely.
  String tin;

  /// Who drew the document up, and their number - printed under
  /// "PREPARED BY". Blank leaves the signature block off.
  String preparedName;
  String preparedPhone;

  /// Printed in the letterhead contact row.
  String businessEmail;

  /// Mobile-money merchant codes, shown as the MoMo and Airtel tiles on an
  /// unpaid document. Blank hides that tile.
  String momoCode;
  String airtelCode;

  /// When the user last wrote a backup file, so Setup can say so instead of
  /// leaving them guessing.
  DateTime? lastBackupAt;

  BusinessSettings({
    required this.businessName,
    required this.tagline,
    required this.phone,
    required this.location,
    required this.brandColorIndex,
    required this.chargeVat,
    required this.vatRate,
    required this.currency,
    required this.quoteSeq,
    required this.receiptSeq,
    required this.terms,
    this.invoiceSeq = 0,
    this.logoPath,
    this.payDetails = '',
    this.dueDefaultDays = 14,
    this.lastBackupAt,
    this.tin = '',
    this.preparedName = '',
    this.preparedPhone = '',
    this.businessEmail = '',
    this.momoCode = '',
    this.airtelCode = '',
  });

  Color get brandColor => kBrandColors[brandColorIndex].color;

  /// Short code used as the document-number prefix (e.g. "DGF" from
  /// "Digiflect"). Derived from the business name so a renamed business
  /// gets sensible numbering without needing a separate setting — existing
  /// documents keep whatever prefix they were created with, since this is
  /// only consulted when a *new* number is minted.
  String get numberPrefix {
    final letters = businessName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.isEmpty) return 'DOC';
    return letters.substring(0, letters.length < 3 ? letters.length : 3);
  }

  /// A genuinely blank starting point for a real user — no sample-business
  /// flavor text. The demo identity lives only in [SeedData] now, reached
  /// via "Load samples" in Setup, never pushed onto a fresh install
  /// automatically.
  factory BusinessSettings.initial() => BusinessSettings(
    businessName: '',
    tagline: '',
    phone: '',
    location: '',
    brandColorIndex: 0,
    // Off by default: most one-person trades are not VAT-registered,
    // and it can still be ticked per job on the document itself.
    chargeVat: false,
    vatRate: 0.18,
    currency: 'UGX',
    quoteSeq: 0,
    invoiceSeq: 0,
    receiptSeq: 0,
    terms: '',
    payDetails: '',
    dueDefaultDays: 14,
    tin: '',
    preparedName: '',
    preparedPhone: '',
    businessEmail: '',
    momoCode: '',
    airtelCode: '',
  );

  BusinessSettings clone() => BusinessSettings(
    businessName: businessName,
    tagline: tagline,
    phone: phone,
    location: location,
    brandColorIndex: brandColorIndex,
    chargeVat: chargeVat,
    vatRate: vatRate,
    currency: currency,
    quoteSeq: quoteSeq,
    invoiceSeq: invoiceSeq,
    receiptSeq: receiptSeq,
    terms: terms,
    logoPath: logoPath,
    payDetails: payDetails,
    dueDefaultDays: dueDefaultDays,
    lastBackupAt: lastBackupAt,
    tin: tin,
    preparedName: preparedName,
    preparedPhone: preparedPhone,
    businessEmail: businessEmail,
    momoCode: momoCode,
    airtelCode: airtelCode,
  );

  Map<String, dynamic> toJson() => {
    'businessName': businessName,
    'tagline': tagline,
    'phone': phone,
    'location': location,
    'brandColorIndex': brandColorIndex,
    'chargeVat': chargeVat,
    'vatRate': vatRate,
    'currency': currency,
    'quoteSeq': quoteSeq,
    'invoiceSeq': invoiceSeq,
    'receiptSeq': receiptSeq,
    'terms': terms,
    'logoPath': logoPath,
    'payDetails': payDetails,
    'dueDefaultDays': dueDefaultDays,
    'lastBackupAt': lastBackupAt?.toIso8601String(),
    'tin': tin,
    'preparedName': preparedName,
    'preparedPhone': preparedPhone,
    'businessEmail': businessEmail,
    'momoCode': momoCode,
    'airtelCode': airtelCode,
  };

  /// v2 keys are read defensively so a v1 store or backup — which had no
  /// invoice sequence, payment details or due-date default — still loads.
  factory BusinessSettings.fromJson(Map<String, dynamic> json) => BusinessSettings(
    businessName: json['businessName'] as String,
    tagline: json['tagline'] as String,
    phone: json['phone'] as String,
    location: json['location'] as String,
    brandColorIndex: (json['brandColorIndex'] as int).clamp(0, kBrandColors.length - 1),
    chargeVat: json['chargeVat'] as bool,
    vatRate: (json['vatRate'] as num).toDouble(),
    currency: json['currency'] as String,
    quoteSeq: json['quoteSeq'] as int,
    invoiceSeq: (json['invoiceSeq'] as num?)?.toInt() ?? 0,
    receiptSeq: json['receiptSeq'] as int,
    terms: json['terms'] as String,
    logoPath: json['logoPath'] as String?,
    payDetails: (json['payDetails'] as String?) ?? '',
    dueDefaultDays: (json['dueDefaultDays'] as num?)?.toInt() ?? 14,
    lastBackupAt: json['lastBackupAt'] is String
        ? DateTime.tryParse(json['lastBackupAt'] as String)
        : null,
    tin: (json['tin'] as String?) ?? '',
    // 'preparedBy' was the single field this replaced; read it as a
    // fallback so a store written between releases keeps the name.
    preparedName: (json['preparedName'] as String?) ?? (json['preparedBy'] as String?) ?? '',
    preparedPhone: (json['preparedPhone'] as String?) ?? '',
    businessEmail: (json['businessEmail'] as String?) ?? '',
    momoCode: (json['momoCode'] as String?) ?? '',
    airtelCode: (json['airtelCode'] as String?) ?? '',
  );
}
