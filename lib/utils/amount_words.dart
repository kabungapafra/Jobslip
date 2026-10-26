/// Spelling a total out in words, the way a printed invoice does it:
/// "Thirty-Four Million, Six Hundred Ninety Thousand Uganda Shillings Only".
///
/// It is there to stop a figure being altered after the fact — which is
/// exactly why it has to agree with the numerals, so it is generated from
/// the same total rather than typed by hand.
library;

const List<String> _units = [
  'Zero',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
];

const List<String> _tens = [
  '',
  '',
  'Twenty',
  'Thirty',
  'Forty',
  'Fifty',
  'Sixty',
  'Seventy',
  'Eighty',
  'Ninety',
];

/// Short scale, which is what East African and international invoicing use.
const List<String> _scales = ['', 'Thousand', 'Million', 'Billion', 'Trillion'];

/// How each supported currency reads when spoken aloud on a document.
const Map<String, String> _currencyWords = {
  'UGX': 'Uganda Shillings',
  'KES': 'Kenya Shillings',
  'TZS': 'Tanzania Shillings',
  'USD': 'US Dollars',
};

/// 0-999 in words. Hyphenates the compound tens, as "Thirty-Four".
String _threeDigitsToWords(int n) {
  if (n < 20) return _units[n];
  if (n < 100) {
    final ten = _tens[n ~/ 10];
    final unit = n % 10;
    return unit == 0 ? ten : '$ten-${_units[unit]}';
  }
  final hundreds = '${_units[n ~/ 100]} Hundred';
  final rest = n % 100;
  return rest == 0 ? hundreds : '$hundreds ${_threeDigitsToWords(rest)}';
}

/// The number alone, with a comma between each scale group.
String numberToWords(int value) {
  if (value == 0) return 'Zero';
  if (value < 0) return 'Minus ${numberToWords(-value)}';

  final groups = <String>[];
  var remaining = value;
  var scale = 0;

  while (remaining > 0) {
    final group = remaining % 1000;
    if (group != 0) {
      final words = _threeDigitsToWords(group);
      groups.insert(0, scale == 0 ? words : '$words ${_scales[scale]}');
    }
    remaining ~/= 1000;
    scale++;
    if (scale >= _scales.length) break;
  }

  return groups.join(', ');
}

/// The full line as printed: the amount, its currency spoken in full, and
/// "Only" to close it off against anything being appended.
///
/// Cents are dropped deliberately — every currency this app offers is
/// configured to print whole units, so spelling out fractions would
/// contradict the figure beside it.
String amountInWords(num amount, String currencyCode) {
  final whole = amount.round().abs();
  final currency = _currencyWords[currencyCode] ?? currencyCode;
  return '${numberToWords(whole)} $currency Only';
}
