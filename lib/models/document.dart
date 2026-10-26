import 'line_item.dart';

/// `quotation` keeps its original name so documents written by v1 still
/// deserialise; `invoice` is the v2 addition that sits between a quote and
/// a receipt — billed now, paid later.
enum DocType { quotation, invoice, receipt }

/// One enum covers all three document types, because a status is only ever
/// read alongside the type that gives it meaning:
///
/// * quotation — `draft`, `sent`, then `invoiced` or `receipted` once the
///   client says yes and the follow-on document exists.
/// * invoice — `unpaid` or `paid`. "Overdue" is never stored: it is derived
///   from [DocumentModel.dueDate] so an invoice goes overdue on its own,
///   with no background job and nothing to re-save.
/// * receipt — always `paid`.
enum DocStatus { draft, sent, invoiced, receipted, unpaid, paid }

/// Date-only copy, so day comparisons ignore the clock time.
DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

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

  /// Free text that prints on the PDF under "NOTES" — site conditions,
  /// exclusions, warranty wording.
  String notes;

  /// Invoices only: the agreed credit period, and the date it lands on.
  /// `dueDays == 0` means "on receipt".
  int? dueDays;
  DateTime? dueDate;

  /// Invoices and receipts: when the money actually arrived, and how.
  DateTime? paidOn;
  String? method;

  /// Paper trail between related documents. [fromNumber] points back at the
  /// document this one was derived from; the other two point forward at what
  /// came out of this one. Numbers (not ids) are stored so the link still
  /// reads correctly after the other document has been deleted.
  String? fromNumber;
  String? invoiceNumber;
  String? receiptNumber;

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
    this.notes = '',
    this.dueDays,
    this.dueDate,
    this.paidOn,
    this.method,
    this.fromNumber,
    this.invoiceNumber,
    this.receiptNumber,
  });

  double get subtotal => lines.fold(0.0, (sum, l) => sum + l.amount);

  double get vatAmount => vatEnabled ? subtotal * vatRate : 0.0;

  double get total => subtotal + vatAmount;

  /// How many days past due this invoice is: positive when overdue, 0 on the
  /// due date itself, negative while there is still time. `null` when the
  /// document has no due date at all.
  int? daysPastDue([DateTime? now]) {
    final due = dueDate;
    if (due == null) return null;
    return _dayOf(now ?? DateTime.now()).difference(_dayOf(due)).inDays;
  }

  /// Derived, never stored — an unpaid invoice whose due date has passed.
  /// Due *today* is not yet overdue.
  bool isOverdue([DateTime? now]) {
    if (type != DocType.invoice || status == DocStatus.paid) return false;
    final past = daysPastDue(now);
    return past != null && past > 0;
  }

  /// True once the money is in: a receipt, or an invoice marked paid.
  bool get isSettled =>
      type == DocType.receipt || (type == DocType.invoice && status == DocStatus.paid);

  /// Money still owed to the business — what the "owed to you" totals on the
  /// home screen add up. A quote is never counted: nobody owes on a price
  /// they have not accepted.
  bool get isOutstanding => type == DocType.invoice && status != DocStatus.paid;

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
    String? notes,
    int? dueDays,
    DateTime? dueDate,
    DateTime? paidOn,
    String? method,
    String? fromNumber,
    String? invoiceNumber,
    String? receiptNumber,
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
      notes: notes ?? this.notes,
      dueDays: dueDays ?? this.dueDays,
      dueDate: dueDate ?? this.dueDate,
      paidOn: paidOn ?? this.paidOn,
      method: method ?? this.method,
      fromNumber: fromNumber ?? this.fromNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      receiptNumber: receiptNumber ?? this.receiptNumber,
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
    'notes': notes,
    'dueDays': dueDays,
    'dueDate': dueDate?.toIso8601String(),
    'paidOn': paidOn?.toIso8601String(),
    'method': method,
    'fromNumber': fromNumber,
    'invoiceNumber': invoiceNumber,
    'receiptNumber': receiptNumber,
  };

  /// Every v2 field is read defensively, so a store or backup written by v1
  /// — which had no invoices, notes, due dates or links — loads unchanged
  /// instead of throwing and sending the user back through onboarding.
  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

    return DocumentModel(
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
      notes: (json['notes'] as String?) ?? '',
      dueDays: (json['dueDays'] as num?)?.toInt(),
      dueDate: parseDate(json['dueDate']),
      paidOn: parseDate(json['paidOn']),
      method: json['method'] as String?,
      fromNumber: json['fromNumber'] as String?,
      invoiceNumber: json['invoiceNumber'] as String?,
      receiptNumber: json['receiptNumber'] as String?,
    );
  }
}
