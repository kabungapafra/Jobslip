import 'package:flutter/material.dart';

import '../models/document.dart';
import '../models/settings.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import 'pill.dart';

/// Shared shell for the bottom sheets: the grabber, the rounded top, and a
/// "Not now" way out that is always in the same place.
Future<T?> _showSheet<T>(BuildContext context, Widget Function(BuildContext) body) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.strongBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            body(ctx),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text(
                  'Not now',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.subtleText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _sheetTitle(String text) => Text(
  text,
  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.2),
);

Widget _bigButton({
  required String label,
  required Color background,
  required VoidCallback onTap,
  Color foreground = Colors.white,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      child: Text(
        label,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: foreground),
      ),
    ),
  );
}

// ---------------------------------------------------------------- share

/// What the user picked in the share sheet. The PDF itself is built and
/// handed over by the caller, which owns the document and the settings.
enum ShareAction { send, copyMessage, print }

/// "Send DGF-INV-0012" — shows the message that will go with the PDF, then
/// hands off to the system share sheet, the clipboard, or the printer.
///
/// Individual apps (WhatsApp, SMS, email) are deliberately not separate
/// buttons: Android only lets an app attach a file through the system
/// chooser, where WhatsApp appears as a target anyway. Pretending to send
/// straight to one app would be a button that cannot keep its promise.
Future<ShareAction?> showShareSheet(
  BuildContext context, {
  required DocumentModel doc,
  required String message,
}) {
  return _showSheet<ShareAction>(context, (ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetTitle('Send ${doc.number}'),
        const SizedBox(height: 4),
        Text(
          '${doc.number}.pdf  -  with the message below',
          style: AppTheme.mono(fontSize: 11.5, color: AppTheme.subtleText),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(16)),
          child: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.55)),
        ),
        const SizedBox(height: 16),
        _bigButton(
          label: 'Send the PDF',
          background: Theme.of(ctx).colorScheme.primary,
          onTap: () => Navigator.of(ctx).pop(ShareAction.send),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(ShareAction.copyMessage),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.strongBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Copy message',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(ShareAction.print),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.strongBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Print',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  });
}

// -------------------------------------------------------------- convert

/// "The client said yes" — carry an accepted quote over into an invoice
/// (they will pay later) or straight into a receipt (they already paid).
Future<DocType?> showConvertSheet(
  BuildContext context, {
  required String quoteNumber,
  required String nextInvoiceNumber,
  required String nextReceiptNumber,
  required int dueDays,
  required DateTime dueDate,
}) {
  return _showSheet<DocType>(context, (ctx) {
    Widget option({
      required String title,
      required String subtitle,
      required String number,
      required DocTypeStyle style,
      required DocType value,
    }) {
      return GestureDetector(
        onTap: () => Navigator.of(ctx).pop(value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: style.fg,
                      ),
                    ),
                  ),
                  Text(number, style: AppTheme.mono(fontSize: 11.5, color: style.fg)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: style.fg.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetTitle('The client said yes'),
        const SizedBox(height: 5),
        Text(
          'Same lines and total carry over from $quoteNumber.',
          style: const TextStyle(fontSize: 14, color: AppTheme.subtleText),
        ),
        const SizedBox(height: 16),
        option(
          title: 'Send an invoice',
          subtitle: dueDays == 0
              ? 'Payable on receipt'
              : 'Due in ${formatDayCount(dueDays)}  -  ${formatDocDate(dueDate)}',
          number: nextInvoiceNumber,
          style: AppTheme.invoiceStyle,
          value: DocType.invoice,
        ),
        const SizedBox(height: 9),
        option(
          title: 'Paid now - issue receipt',
          subtitle: 'Cash or mobile money already in hand',
          number: nextReceiptNumber,
          style: AppTheme.receiptStyle,
          value: DocType.receipt,
        ),
        const SizedBox(height: 10),
      ],
    );
  });
}

// ------------------------------------------------------------- payment

/// How an invoice was settled: the method, and whether to hand the client a
/// receipt at the same time.
class PaymentChoice {
  final String method;
  final bool issueReceipt;
  const PaymentChoice(this.method, this.issueReceipt);
}

/// "Record payment" — the step that turns an unpaid invoice into money in
/// and, by default, produces the receipt the client will ask for.
Future<PaymentChoice?> showPaymentSheet(
  BuildContext context, {
  required DocumentModel invoice,
  required String currency,
  required String nextReceiptNumber,
  String? initialMethod,
}) {
  return _showSheet<PaymentChoice>(context, (ctx) {
    var method = initialMethod ?? kPaymentMethods.first;
    var issueReceipt = true;

    return StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle('Record payment'),
          const SizedBox(height: 5),
          Text(
            '${invoice.number}  -  ${formatMoney(invoice.total, currency)}',
            style: AppTheme.mono(fontSize: 13, color: const Color(0xFF55554F)),
          ),
          const SizedBox(height: 18),
          Text('HOW DID THEY PAY?', style: AppTheme.caption()),
          const SizedBox(height: 9),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.4,
            children: [
              for (final m in kPaymentMethods)
                SelectablePill(
                  label: m,
                  selected: method == m,
                  accent: AppTheme.success,
                  expand: true,
                  onTap: () => setState(() => method = m),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TickBox(
            checked: issueReceipt,
            accent: AppTheme.success,
            label: 'Also issue a receipt ($nextReceiptNumber)',
            onTap: () => setState(() => issueReceipt = !issueReceipt),
          ),
          const SizedBox(height: 18),
          _bigButton(
            label: 'Mark invoice paid',
            background: AppTheme.success,
            onTap: () => Navigator.of(ctx).pop(PaymentChoice(method, issueReceipt)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  });
}

// -------------------------------------------------------------- delete

/// Deleting is final on an offline app — there is no server copy to restore
/// from — so the sheet says exactly that before the red button.
Future<bool> showDeleteSheet(BuildContext context, String number) async {
  final result = await _showSheet<bool>(context, (ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetTitle('Delete $number?'),
        const SizedBox(height: 6),
        const Text(
          "It only lives on this phone, so it can't come back. The number stays used.",
          style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.subtleText),
        ),
        const SizedBox(height: 18),
        _bigButton(
          label: 'Delete for good',
          background: AppTheme.danger,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
        const SizedBox(height: 10),
      ],
    );
  });
  return result == true;
}
