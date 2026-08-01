/// Human-readable formatting helpers, all Arabic-facing.
class Formatters {
  Formatters._();

  static const List<String> _units = ['B', 'KB', 'MB', 'GB', 'TB'];

  /// 1536000 -> "1.5 MB"
  static String bytes(int value) {
    if (value <= 0) return '0 B';
    var size = value.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < _units.length - 1) {
      size /= 1024;
      unit++;
    }
    final digits = size >= 100 || unit == 0 ? 0 : 1;
    return '${size.toStringAsFixed(digits)} ${_units[unit]}';
  }

  /// Bytes per second -> "12.4 MB/s"
  static String speed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '—';
    return '${bytes(bytesPerSecond.round())}/s';
  }

  /// Seconds remaining -> "3 دقائق"
  static String duration(int seconds) {
    if (seconds <= 0) return '—';
    if (seconds < 60) return '$seconds ثانية';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    final restMinutes = minutes % 60;
    if (hours < 24) {
      return restMinutes == 0 ? '$hours ساعة' : '$hours س $restMinutes د';
    }
    final days = hours ~/ 24;
    return '$days يوم';
  }

  /// 0.812 -> "81%"
  static String percent(double fraction) =>
      '${(fraction.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';

  /// Extracts a 4-digit year from any of the loose date formats Xtream returns.
  static String? year(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'(19|20)\d{2}').firstMatch(raw);
    return match?.group(0);
  }

  /// Derives a quality tag from the stream title, since Xtream has no field.
  static String? quality(String title) {
    final upper = title.toUpperCase();
    if (upper.contains('2160') || upper.contains('4K') || upper.contains('UHD')) {
      return '4K';
    }
    if (upper.contains('1080')) return '1080p';
    if (upper.contains('720')) return '720p';
    if (upper.contains('480')) return '480p';
    return null;
  }
}
