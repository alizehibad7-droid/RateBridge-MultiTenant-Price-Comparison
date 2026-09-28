import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

class CurrencyFormatter {
  static final NumberFormat _format = NumberFormat('#,##0', 'en_PK');

  /// Round money to whole Pakistani rupees (no paisa).
  /// Used for commission generation, owed balance, and payment validation
  /// so display and ledger never drift by fractional rupees.
  static double roundToRupee(num amount) => amount.roundToDouble();

  /// Platform commission on [totalAmount], rounded to whole rupees.
  static double commissionOn(num totalAmount) =>
      roundToRupee(totalAmount.toDouble() * AppConstants.commissionRate);

  /// Supplier net after commission, consistent with [commissionOn].
  static double supplierEarningOn(num totalAmount) {
    final total = totalAmount.toDouble();
    return roundToRupee(total - commissionOn(total));
  }

  static String formatPKR(double amount) {
    return 'Rs. ${_format.format(roundToRupee(amount))}';
  }

  static String formatRupees(double amount) {
    return formatPKR(amount);
  }

  static String formatRupeesInt(int amount) {
    return 'Rs. ${_format.format(amount)}';
  }

  static String formatShort(double amount) {
    final rounded = roundToRupee(amount);
    if (rounded >= 1000000) {
      return 'Rs. ${(rounded / 1000000).toStringAsFixed(1)}M';
    }
    if (rounded >= 1000) {
      return 'Rs. ${(rounded / 1000).toStringAsFixed(1)}K';
    }
    return formatPKR(rounded);
  }
}
