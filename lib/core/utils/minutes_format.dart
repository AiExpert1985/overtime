/// Formats [minutes] as `h:mm` (hours unpadded, minutes zero-padded).
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}

/// Rounds [minutes] up per the display [mode] ('quarter' / 'half' / 'hour',
/// anything else = no rounding), then formats it as `h:mm`.
String formatRoundedMinutes(int minutes, String mode) {
  final step = switch (mode) {
    'quarter' => 15,
    'half' => 30,
    'hour' => 60,
    _ => 1,
  };
  return formatMinutes((minutes / step).ceil() * step);
}

/// Formats a whole number of hours as `h:00`.
String formatWholeHours(int hours) => formatMinutes(hours * 60);
