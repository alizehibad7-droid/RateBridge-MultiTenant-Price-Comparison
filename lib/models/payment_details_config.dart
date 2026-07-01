/// Admin-configurable payment instructions for manual subscription payments.
class PaymentDetailsConfig {
  final String jazzCashNumber;
  final String bankName;
  final String bankAccountNumber;
  final String accountTitle;

  const PaymentDetailsConfig({
    this.jazzCashNumber = '',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.accountTitle = '',
  });

  bool get isConfigured =>
      jazzCashNumber.trim().isNotEmpty ||
      (bankName.trim().isNotEmpty && bankAccountNumber.trim().isNotEmpty);

  factory PaymentDetailsConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PaymentDetailsConfig();
    return PaymentDetailsConfig(
      jazzCashNumber: map['jazzCashNumber'] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
      bankAccountNumber: map['bankAccountNumber'] as String? ?? '',
      accountTitle: map['accountTitle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'jazzCashNumber': jazzCashNumber.trim(),
        'bankName': bankName.trim(),
        'bankAccountNumber': bankAccountNumber.trim(),
        'accountTitle': accountTitle.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
}
