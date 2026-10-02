/// DeepSeek API peak / off-peak pricing windows (UTC).
///
/// Peak (Mon–Fri only): 01:00–04:00 UTC and 06:00–10:00 UTC.
/// Off-peak: all other times, weekends, and Chinese public holidays.
///
/// Afghanistan (UTC+4:30) peak windows:
/// - 05:30–08:30 and 10:30–14:30 local time on weekdays.
///
/// Chinese public holidays are also off-peak per DeepSeek; this helper does
/// not maintain a holiday calendar, so weekday peak hours may still report
/// peak on those rare days.
enum DeepSeekPricingPeriod { peak, offPeak }

extension DeepSeekPricingPeriodX on DeepSeekPricingPeriod {
  String get label => switch (this) {
    DeepSeekPricingPeriod.peak => 'Peak',
    DeepSeekPricingPeriod.offPeak => 'Off-peak',
  };

  String get shortHint => switch (this) {
    DeepSeekPricingPeriod.peak => 'Higher rates right now',
    DeepSeekPricingPeriod.offPeak => 'Cheaper rates right now (~½ peak)',
  };
}

abstract final class DeepSeekPricingSchedule {
  /// Peak window starts/ends in UTC minutes-from-midnight (half-open).
  static const peakWindowsUtc = <(int, int)>[
    (1 * 60, 4 * 60), // 01:00–04:00 UTC
    (6 * 60, 10 * 60), // 06:00–10:00 UTC
  ];

  /// Afghanistan local peak windows for display (UTC+4:30).
  static const afghanistanPeakHint =
      'Peak (Afghanistan): 5:30–8:30 AM and 10:30 AM–2:30 PM, Mon–Fri. '
      'Weekends and other times are off-peak (cheaper).';

  static DeepSeekPricingPeriod forUtc(DateTime utc) {
    final instant = utc.isUtc ? utc : utc.toUtc();
    // Saturday = 6, Sunday = 7 in DateTime.weekday (Mon=1 … Sun=7).
    if (instant.weekday == DateTime.saturday ||
        instant.weekday == DateTime.sunday) {
      return DeepSeekPricingPeriod.offPeak;
    }
    final minutes = instant.hour * 60 + instant.minute;
    for (final (start, end) in peakWindowsUtc) {
      if (minutes >= start && minutes < end) {
        return DeepSeekPricingPeriod.peak;
      }
    }
    return DeepSeekPricingPeriod.offPeak;
  }

  static DeepSeekPricingPeriod now([DateTime Function()? clock]) {
    final t = clock?.call() ?? DateTime.now().toUtc();
    return forUtc(t);
  }
}
