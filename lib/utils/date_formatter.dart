import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'en_PK');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a', 'en_PK');
  static final DateFormat _monthFormat = DateFormat('MMM yyyy', 'en_PK');
  static final DateFormat _monthKey = DateFormat('yyyy-MM');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatMonth(DateTime date) => _monthFormat.format(date);
  static String monthKey(DateTime date) => _monthKey.format(date);

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return formatDate(date);
  }
}
