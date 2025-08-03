import 'package:intl/intl.dart';

String formatDate(DateTime date) {
  final formatter = DateFormat('d MMM y HH:mm', 'fr_FR');
  return formatter.format(date);
}
