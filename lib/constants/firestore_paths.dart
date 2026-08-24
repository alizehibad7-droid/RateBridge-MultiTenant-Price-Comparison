// MVVM: Constants — Firestore path definitions
class FirestorePaths {
  FirestorePaths._();

  // Top-level collections
  static const String usersCol = 'users';
  static const String companiesCol = 'companies';
  static const String suppliersCol = 'suppliers';
  static const String categoriesCol = 'categories';
  static const String invitationsCol = 'invitations';
  static const String joinRequestsCol = 'joinRequests';
  static const String partnershipRequestsCol = 'partnershipRequests';
  static const String transactionsCol = 'transactions';
  static const String subscriptionsCol = 'subscriptions';
  static const String processedEventsCol = 'processedEvents';

  // User document
  static String userDoc(String uid) => '$usersCol/$uid';

  // Company document
  static String companyDoc(String companyId) => '$companiesCol/$companyId';

  // Supplier document
  static String supplierDoc(String uid) => '$suppliersCol/$uid';

  // Subscription document
  static String subscriptionDoc(String companyId) => '$subscriptionsCol/$companyId';

  // Company sub-collections
  static String companyMaterialsCol(String companyId) =>
    '$companiesCol/$companyId/materials';

  static String companyMaterialDoc(String companyId, String matId) =>
    '$companiesCol/$companyId/materials/$matId';

  static String materialPriceHistoryCol(String companyId, String matId) =>
    '$companiesCol/$companyId/materials/$matId/priceHistory';

  static String companyOrdersCol(String companyId) =>
    '$companiesCol/$companyId/orders';

  static String companyOrderDoc(String companyId, String orderId) =>
    '$companiesCol/$companyId/orders/$orderId';

  static String orderChatsCol(String companyId, String orderId) =>
    '$companiesCol/$companyId/orders/$orderId/chats';

  static String orderChatMetaDoc(String companyId, String orderId) =>
    '$companiesCol/$companyId/orders/$orderId/chatMeta/meta';

  static String orderRatingsCol(String companyId, String orderId) =>
    '$companiesCol/$companyId/orders/$orderId/ratings';

  static String companySuppliersCol(String companyId) =>
    '$companiesCol/$companyId/suppliers';

  static String companyFieldUsersCol(String companyId) =>
    '$companiesCol/$companyId/fieldUsers';

  static String companyNotificationsCol(String companyId) =>
    '$companiesCol/$companyId/notifications';

  // User-level notifications (alternative path)
  static String userNotificationsCol(String uid) =>
    '$usersCol/$uid/notifications';

  // Supplier sub-collections
  static String supplierCompanyLinksCol(String supplierUid) =>
    '$suppliersCol/$supplierUid/companyLinks';

  static String supplierEarningsCol(String supplierUid) =>
    '$suppliersCol/$supplierUid/earnings';
}
