import 'line_item.dart';

enum DocType { quotation, receipt }

enum DocStatus { draft, sent, paid }

class DocumentModel {
  final String id;
  DocType type;
  DocStatus status;
  final String number;
  final DateTime date;

  final String clientId;
  String clientName;
  String clientPhone;
  String clientLocation;

  List<LineItem> lines;
  bool vatEnabled;
  double vatRate;

  DocumentModel({
    required this.id,
    required this.type,
    required this.status,
    required this.number,
    required this.date,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.clientLocation,
    required this.lines,
    required this.vatEnabled,
    required this.vatRate,
  });

  double get subtotal => lines.fold(0.0, (sum, l) => sum + l.amount);

  double get vatAmount => vatEnabled ? subtotal * vatRate : 0.0;

  double get total => subtotal + vatAmount;

  DocumentModel copyWith({
    DocType? type,
    DocStatus? status,
    String? number,
    DateTime? date,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? clientLocation,
    List<LineItem>? lines,
    bool? vatEnabled,
    double? vatRate,
  }) {
    return DocumentModel(
      id: id,
      type: type ?? this.type,
      status: status ?? this.status,
      number: number ?? this.number,
      date: date ?? this.date,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientLocation: clientLocation ?? this.clientLocation,
      lines: lines ?? this.lines,
      vatEnabled: vatEnabled ?? this.vatEnabled,
      vatRate: vatRate ?? this.vatRate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'number': number,
        'date': date.toIso8601String(),
        'clientId': clientId,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'clientLocation': clientLocation,
        'lines': lines.map((l) => l.toJson()).toList(),
        'vatEnabled': vatEnabled,
        'vatRate': vatRate,
      };

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
        id: json['id'] as String,
        type: DocType.values.byName(json['type'] as String),
        status: DocStatus.values.byName(json['status'] as String),
        number: json['number'] as String,
        date: DateTime.parse(json['date'] as String),
        clientId: json['clientId'] as String,
        clientName: json['clientName'] as String,
        clientPhone: json['clientPhone'] as String,
        clientLocation: json['clientLocation'] as String,
        lines: (json['lines'] as List)
            .map((l) => LineItem.fromJson(l as Map<String, dynamic>))
            .toList(),
        vatEnabled: json['vatEnabled'] as bool,
        vatRate: (json['vatRate'] as num).toDouble(),
      );
}
