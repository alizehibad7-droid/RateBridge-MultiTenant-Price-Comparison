import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _format = NumberFormat('#,##0', 'en_PK');

  static String formatPKR(double amount) {
    return 'Rs. ${_format.format(amount)}';
  }

  static String formatRupees(double amount) {
    return formatPKR(amount);
  }

  static String formatRupeesInt(int amount) {
    return 'Rs. ${_format.format(amount)}';
  }

  static String formatShort(double amount) {
    if (amount >= 1000000) return 'Rs. ${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return 'Rs. ${(amount / 1000).toStringAsFixed(1)}K';
    return formatPKR(amount);
  }
}
