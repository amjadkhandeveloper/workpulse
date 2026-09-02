import 'package:intl/intl.dart';

final dateFull = DateFormat('EEEE, MMM d, y');
final dateShort = DateFormat('dd/MM/yyyy');
final dateLong = DateFormat('d MMMM y');
final timeHm = DateFormat('HH:mm');
final dateTimeRange = DateFormat('d MMMM y, HH.mm');
final monthLabel = DateFormat('MMMM y');

String formatJobWindow(DateTime start, DateTime end) {
  return '${dateLong.format(start)}, ${timeHm.format(start)} - ${timeHm.format(end)}';
}

String csvEscape(Object? value) {
  final text = '${value ?? ''}';
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
