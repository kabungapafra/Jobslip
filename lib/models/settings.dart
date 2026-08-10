import 'package:flutter/material.dart';

class BrandColorOption {
  final String name;
  final Color color;
  const BrandColorOption(this.name, this.color);
}

const List<BrandColorOption> kBrandColors = [
  BrandColorOption('Teal', Color(0xFF2F7D6B)),
  BrandColorOption('Orange', Color(0xFFD9822B)),
  BrandColorOption('Blue', Color(0xFF2A5BB0)),
  BrandColorOption('Maroon', Color(0xFF9C2D52)),
  BrandColorOption('Dark', Color(0xFF2A2A28)),
];

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
  int receiptSeq;
  String terms;
  String? logoPath;

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
    this.logoPath,
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
  /// via "Restore sample documents" in Setup, never pushed onto a fresh
  /// install automatically.
  factory BusinessSettings.initial() => BusinessSettings(
        businessName: '',
        tagline: '',
        phone: '',
        location: '',
        brandColorIndex: 0,
        chargeVat: true,
        vatRate: 0.18,
        currency: 'UGX',
        quoteSeq: 0,
        receiptSeq: 0,
        terms: '',
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
        receiptSeq: receiptSeq,
        terms: terms,
        logoPath: logoPath,
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
        'receiptSeq': receiptSeq,
        'terms': terms,
        'logoPath': logoPath,
      };

  factory BusinessSettings.fromJson(Map<String, dynamic> json) => BusinessSettings(
        businessName: json['businessName'] as String,
        tagline: json['tagline'] as String,
        phone: json['phone'] as String,
        location: json['location'] as String,
        brandColorIndex: json['brandColorIndex'] as int,
        chargeVat: json['chargeVat'] as bool,
        vatRate: (json['vatRate'] as num).toDouble(),
        currency: json['currency'] as String,
        quoteSeq: json['quoteSeq'] as int,
        receiptSeq: json['receiptSeq'] as int,
        terms: json['terms'] as String,
        logoPath: json['logoPath'] as String?,
      );
}
