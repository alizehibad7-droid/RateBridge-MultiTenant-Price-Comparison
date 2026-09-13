/// Navigation payload for [FieldChatThreadView].
class FieldChatThreadArgs {
  final String supplierUid;
  final String supplierName;
  final String? orderId;

  const FieldChatThreadArgs({
    required this.supplierUid,
    required this.supplierName,
    this.orderId,
  });
}
