/// Admin-facing Stripe payment row (CEO subscriptions + supplier commissions).
class AdminPaymentRecord {
  final String id;
  final String payerId;
  final String payerName;
  final String payerRole; // CEO | Supplier
  final String companyId;
  final String companyName;
  final double amount;
  /// Normalized: pending | success | failed
  final String status;
  final DateTime date;
  final String type; // subscription | commission
  final String relatedLabel;
  final String? stripeRef;

  const AdminPaymentRecord({
    required this.id,
    required this.payerId,
    required this.payerName,
    required this.payerRole,
    required this.companyId,
    required this.companyName,
    required this.amount,
    required this.status,
    required this.date,
    required this.type,
    required this.relatedLabel,
    this.stripeRef,
  });

  bool get isCeo => payerRole.toLowerCase() == 'ceo';
  bool get isSupplier => payerRole.toLowerCase() == 'supplier';

  static String normalizeStatus(String raw) {
    final s = raw.toLowerCase().trim();
    switch (s) {
      case 'confirmed':
      case 'settled':
      case 'approved':
      case 'success':
      case 'complete':
      case 'paid':
        return 'success';
      case 'rejected':
        return 'failed';
      case 'failed':
      case 'error':
        return 'failed';
      case 'pending':
      default:
        return 'pending';
    }
  }
}
