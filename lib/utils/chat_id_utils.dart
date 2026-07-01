/// Deterministic chat thread ids shared by field users and suppliers.
class ChatIdUtils {
  ChatIdUtils._();

  /// Same id both sides compute: `{sortedUidA}_{sortedUidB}_{companyId}`.
  static String buildChatId({
    required String companyId,
    required String fieldUserId,
    required String supplierId,
  }) {
    final participants = [fieldUserId, supplierId]..sort();
    return '${participants[0]}_${participants[1]}_$companyId';
  }
}
