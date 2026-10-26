import 'package:intl/intl.dart';

/// Full date as it prints on a document: "22 Oct 2026".
String formatDocDate(DateTime date) => DateFormat('d MMM y').format(date);

/// Day and month only, for the tight one-line summaries in list rows:
/// "22 Oct".
String formatShortDate(DateTime date) => DateFormat('d MMM').format(date);

/// The home screen's greeting line: "Sunday, 25 Oct 2026".
String formatDayLabel(DateTime date) => DateFormat('EEEE, d MMM y').format(date);

/// Month name used by the "collected in ..." tile: "OCT".
String formatMonthCode(DateTime date) => DateFormat('MMM').format(date).toUpperCase();

/// Timestamp for "last backup", kept short: "25 Oct 2026, 09:41".
String formatBackupStamp(DateTime date) => DateFormat('d MMM y, HH:mm').format(date);

/// A plural-aware day count: "1 day", "12 days".
String formatDayCount(int days) => '$days ${days == 1 ? 'day' : 'days'}';

/// The compact form the printed documents use in their reference block:
/// "25/05/2026".
String formatSlashDate(DateTime date) => DateFormat('dd/MM/y').format(date);
