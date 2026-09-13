import 'package:intl/intl.dart';

class AppFormatters {
  static String formatPKRCurrency(double amount) {
    if (amount >= 10000000) {
      // 1 Crore = 10 Million
      final crores = amount / 10000000;
      return "Rs. ${crores.toStringAsFixed(2)} Crore";
    } else if (amount >= 100000) {
      // 1 Lakh = 100,000
      final lakhs = amount / 100000;
      return "Rs. ${lakhs.toStringAsFixed(2)} Lakh";
    }
    
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'Rs. ',
      decimalDigits: 0,
    );
    return currencyFormatter.format(amount);
  }

  static String formatTonsQuantity(double value) {
    return "${value.toStringAsFixed(1)} Tons";
  }

  static String date(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
