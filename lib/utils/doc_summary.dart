import 'package:flutter/material.dart';

import '../models/document.dart';
import '../models/line_item.dart';
import '../models/settings.dart';
import '../theme/app_theme.dart';
import 'currency.dart';
import 'date_format.dart';

/// How long a quotation is treated as good for. Printed as "valid until" on
/// the PDF and used in the summary line under a quote in a list.
const int kQuoteValidityDays = 14;

DateTime quoteValidUntil(DocumentModel doc) =>
    DateTime(doc.date.year, doc.date.month, doc.date.day + kQuoteValidityDays);

/// A document's one-line status sentence, with the colour it should be set
/// in. This is the sentence that does the actual work on the home and list
/// screens: not "unpaid", but *how* unpaid — "Overdue by 9 days".
class DocSummary {
  final String text;
  final Color color;
  const DocSummary(this.text, this.color);

  factory DocSummary.of(DocumentModel doc, [DateTime? now]) {
    switch (doc.type) {
      case DocType.invoice:
        if (doc.status != DocStatus.paid) {
          final past = doc.daysPastDue(now);
          if (past == null) {
            return DocSummary('Due on receipt', AppTheme.unpaidStatus.fg);
          }
          if (past > 0) {
            return DocSummary('Overdue by ${formatDayCount(past)}', AppTheme.overdueStatus.fg);
          }
          if (past == 0) {
            return DocSummary('Due today', AppTheme.unpaidStatus.fg);
          }
          return DocSummary(
            'Due ${formatShortDate(doc.dueDate!)} - in ${formatDayCount(-past)}',
            AppTheme.subtleText,
          );
        }
        return DocSummary(
          'Paid ${formatShortDate(doc.paidOn ?? doc.date)}'
          '${doc.method != null ? ' - ${doc.method}' : ''}',
          AppTheme.success,
        );

      case DocType.receipt:
        return DocSummary(
          'Paid ${formatShortDate(doc.date)}'
          '${doc.method != null ? ' - ${doc.method}' : ''}',
          AppTheme.subtleText,
        );

      case DocType.quotation:
        if (doc.status == DocStatus.invoiced && doc.invoiceNumber != null) {
          return DocSummary('Invoiced - ${doc.invoiceNumber}', AppTheme.invoiceStyle.fg);
        }
        if (doc.status == DocStatus.receipted && doc.receiptNumber != null) {
          return DocSummary('Paid - ${doc.receiptNumber}', AppTheme.success);
        }
        return DocSummary(
          'Issued ${formatShortDate(doc.date)} - valid to '
          '${formatShortDate(quoteValidUntil(doc))}',
          AppTheme.subtleText,
        );
    }
  }
}

/// The caption above the big number on the detail hero: a quote only ever
/// *proposed* an amount, a settled document has been paid, anything else is
/// still owed.
String amountCaption(DocumentModel doc) {
  if (doc.type == DocType.quotation) return 'QUOTED';
  if (doc.isSettled) return 'PAID';
  return 'BALANCE DUE';
}

/// The same idea in the PDF's totals box.
String pdfTotalWord(DocumentModel doc) {
  switch (doc.type) {
    case DocType.quotation:
      return 'TOTAL';
    case DocType.receipt:
      return 'RECEIVED';
    case DocType.invoice:
      return doc.status == DocStatus.paid ? 'TOTAL PAID' : 'TOTAL DUE';
  }
}

/// The mobile-money block printed near the foot of the document. It is
/// shown only while money is still owed — once something is settled, asking
/// again for payment is at best confusing and at worst a second demand.
({String title, String body})? payBoxFor(DocumentModel doc, String payDetails) {
  if (doc.isSettled) return null;
  final details = payDetails.trim();
  return (
    title: 'Mobile Money Details',
    body: details.isEmpty ? 'Reference: ${doc.number}' : '$details\nReference: ${doc.number}',
  );
}

/// The message that goes out with the PDF. Written as the tradesperson
/// would write it — first name, the amount, and what happens next.
String shareMessage(
  DocumentModel doc, {
  required String businessName,
  required String currency,
  DateTime? now,
}) {
  final first = _firstName(doc.clientName);
  final amount = formatMoney(doc.total, currency);
  final signature = businessName.trim().isEmpty ? '' : '\n- ${businessName.trim()}';

  switch (doc.type) {
    case DocType.quotation:
      return 'Hi $first, here is my quotation ${doc.number} for $amount. '
          'Valid for $kQuoteValidityDays days - reply here to go ahead.$signature';
    case DocType.invoice:
      if (doc.status != DocStatus.paid) {
        final overdue = doc.isOverdue(now);
        final due = doc.dueDate;
        final when = due == null
            ? ' is due on receipt'
            : overdue
            ? ' was due on ${formatDocDate(due)}'
            : ' is due ${formatDocDate(due)}';
        return 'Hi $first, ${overdue ? 'a reminder that ' : ''}invoice ${doc.number} '
            'for $amount$when. Payment details are on the PDF. Thank you!$signature';
      }
      return 'Hi $first, thank you for your payment of $amount. '
          'Invoice ${doc.number} is settled in full.$signature';
    case DocType.receipt:
      return 'Hi $first, thank you for your payment of $amount. '
          'Your receipt ${doc.number} is attached.$signature';
  }
}

/// First word of the name, except for a title like "Mrs." where the first
/// word alone would be rude rather than friendly.
String _firstName(String fullName) {
  final name = fullName.trim();
  if (name.isEmpty) return 'there';
  final first = name.split(RegExp(r'\s+')).first;
  const titles = {'mr.', 'mrs.', 'ms.', 'dr.', 'mr', 'mrs', 'ms', 'dr'};
  return titles.contains(first.toLowerCase()) ? name : first;
}

/// The unit a line is counted in, as the printed table shows it.
///
/// Most trades never bother typing one, so rather than leave the column
/// empty the description is read for the obvious cases — an hourly rate, a
/// run of cable, a job price — and anything else counts as pieces.
String unitOf(LineItem line) {
  final typed = line.unit.trim();
  if (typed.isNotEmpty) return typed.toUpperCase();

  final desc = line.description.toLowerCase();
  if (RegExp(r'hour|hr\b').hasMatch(desc)) return 'HRS';
  if (RegExp(r'metre|meter|\bper m\b').hasMatch(desc)) return 'M';
  if (RegExp(r'install|setup|service|survey|fix|reinstall|configur').hasMatch(desc)) {
    return 'JOB';
  }
  return 'PCS';
}

/// What the client is called on each kind of document.
String recipientLabel(DocType type) {
  switch (type) {
    case DocType.quotation:
      return 'Quotation To:';
    case DocType.invoice:
      return 'Invoice To:';
    case DocType.receipt:
      return 'Received From:';
  }
}

/// The reference rows printed top-right, under the document word.
List<({String key, String value})> pdfMetaRows(DocumentModel doc, BusinessSettings settings) {
  // The leading business code is dropped: the letterhead above already says
  // whose document this is, so repeating it in every number is noise. Any
  // code is stripped, not just the current one — a document numbered under
  // an older business name must shorten too.
  final shortNumber = doc.number.replaceFirst(RegExp(r'^[A-Za-z]+-'), '');
  final rows = <({String key, String value})>[
    if (settings.tin.trim().isNotEmpty) (key: 'TIN No.:', value: settings.tin.trim()),
  ];

  switch (doc.type) {
    case DocType.quotation:
      rows.addAll([
        (key: 'Quotation No.:', value: shortNumber),
        (key: 'Issue Date:', value: formatSlashDate(doc.date)),
        (key: 'Valid Until:', value: formatSlashDate(quoteValidUntil(doc))),
      ]);
    case DocType.invoice:
      rows.addAll([
        (key: 'Invoice No.:', value: shortNumber),
        (key: 'Issue Date:', value: formatSlashDate(doc.date)),
        (
          key: 'Due Date:',
          value: doc.dueDays == 0 || doc.dueDate == null
              ? 'On receipt'
              : formatSlashDate(doc.dueDate!),
        ),
      ]);
    case DocType.receipt:
      rows.addAll([
        (key: 'Receipt No.:', value: shortNumber),
        (key: 'Date:', value: formatSlashDate(doc.date)),
        if (doc.method != null) (key: 'Paid via:', value: doc.method!),
      ]);
  }
  return rows;
}
