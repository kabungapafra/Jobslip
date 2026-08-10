import 'package:intl/intl.dart';

String formatMoney(num value, String currency) {
  final formatter = NumberFormat('#,##0', 'en_US');
  return '$currency ${formatter.format(value)}';
}

String formatAmount(num value) {
  final formatter = NumberFormat('#,##0', 'en_US');
  return formatter.format(value);
}
