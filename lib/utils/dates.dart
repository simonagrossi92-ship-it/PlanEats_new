DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String isoDate(DateTime d) {
  final dd = dateOnly(d);
  final m = dd.month.toString().padLeft(2, '0');
  final day = dd.day.toString().padLeft(2, '0');
  return '${dd.year}-$m-$day';
}

DateTime parseIsoDate(String s) {
  final parts = s.split('-');
  if (parts.length != 3) return DateTime.now();
  return DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// Ritorna il lunedì della settimana della data `d`.
DateTime weekStartMonday(DateTime d) {
  final dd = dateOnly(d);
  final diff = (dd.weekday + 6) % 7; // Monday=0 ... Sunday=6
  return dd.subtract(Duration(days: diff));
}

List<DateTime> weekDays(DateTime anyDayInWeek) {
  final start = weekStartMonday(anyDayInWeek);
  return List.generate(7, (i) => start.add(Duration(days: i)));
}

String weekdayShortLabel(DateTime d) {
  const labels = ['Lu', 'Ma', 'Me', 'Gi', 'Ve', 'Sa', 'Do'];
  return labels[(d.weekday + 6) % 7];
}
