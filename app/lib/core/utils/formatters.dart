import 'package:intl/intl.dart';

/// Date/time presentation. Distinct medical dates (report, upload, visit...) are always
/// passed separately and labelled by the caller; nothing here merges them.
abstract final class Fmt {
  static final _date = DateFormat('d MMM yyyy');
  static final _shortDate = DateFormat('d MMM');
  static final _time = DateFormat('h:mm a');
  static final _dateTime = DateFormat('d MMM yyyy, h:mm a');
  static final _number = NumberFormat.decimalPattern();
  static final _iso = DateFormat('yyyy-MM-dd');

  static String date(DateTime? d) => d == null ? '—' : _date.format(d.toLocal());
  static String shortDate(DateTime? d) => d == null ? '—' : _shortDate.format(d.toLocal());
  static String time(DateTime? d) => d == null ? '—' : _time.format(d.toLocal());
  static String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d.toLocal());
  static String isoDate(DateTime d) => _iso.format(d);
  static String number(num n) => _number.format(n);

  static String relative(DateTime? d, {DateTime? now}) {
    if (d == null) return '—';
    final diff = (now ?? DateTime.now()).difference(d.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return date(d);
  }

  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String duration(num minutes) {
    final m = minutes.round();
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '${r}m';
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String percent(double? p) => p == null ? '—' : '${(p * 100).round()}%';

  /// A model probability for display. Extremes read as ">99%" / "<1%" so a rounded value never
  /// looks like certainty. The stored value is untouched.
  static String modelProbability(double? p) {
    if (p == null) return '—';
    if (p >= 0.995) return '>99%';
    if (p <= 0.005) return '<1%';
    return percent(p);
  }

  static String titleCase(String snake) =>
      snake.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  static String firstName(String full) => full.trim().split(RegExp(r'\s+')).first;
}

DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
