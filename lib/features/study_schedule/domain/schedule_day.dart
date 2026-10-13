/// Calendar days for the Study Schedule.
///
/// Due dates are whole local days stored as `yyyy-MM-dd`, so time zones,
/// daylight saving and late-night study never shift a review. Days are kept
/// as UTC midnights purely to make day arithmetic exact.
abstract final class ScheduleDay {
  static DateTime of(DateTime time) =>
      DateTime.utc(time.year, time.month, time.day);

  static DateTime today() => of(DateTime.now());

  static DateTime add(DateTime day, int days) =>
      DateTime.utc(day.year, day.month, day.day + days);

  /// Whole days from [from] to [to] (negative when [to] is earlier).
  static int between(DateTime from, DateTime to) =>
      of(to).difference(of(from)).inDays;

  static String format(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3) throw FormatException('Invalid day', value);
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static DateTime? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return parse(value);
    } on FormatException {
      return null;
    }
  }

  /// "Today", "Tomorrow", "In 5 days", "2 days overdue".
  static String relative(DateTime day, {DateTime? today}) {
    final days = between(today ?? ScheduleDay.today(), day);
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    if (days < 0) return '${-days} days overdue';
    return 'In $days days';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "Oct 18" (adds the year when it differs from today's).
  static String short(DateTime day, {DateTime? today}) {
    final label = '${_months[day.month - 1]} ${day.day}';
    final year = (today ?? ScheduleDay.today()).year;
    return day.year == year ? label : '$label, ${day.year}';
  }
}
