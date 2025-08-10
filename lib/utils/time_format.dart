// utils/time_format.dart
/// Utilities to format durations and minute values for UI.
String formatDuration(Duration d) {
  final totalMinutes = d.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) return '$totalMinutes min';
  if (minutes == 0) return '${hours} h';
  return '${hours} h ${minutes} min';
}

/// Format a minutes value (double) as min or h when >= 60.
/// e.g. 75.3 -> "1 h 15 min"; 60.0 -> "1 h"; 45.7 -> "45.7 min".
String formatMinutesDouble(double minutes) {
  if (minutes.isNaN || minutes.isInfinite) return '-';
  final total = minutes;
  if (total < 60) {
    return '${total.toStringAsFixed(1)} min';
  }
  final hours = total ~/ 60; // integer hours
  final restMinutes = (total - hours * 60).round(); // nearest minute
  if (restMinutes == 0) return '${hours.toString()} h';
  return '${hours.toString()} h ${restMinutes.toString()} min';
}
