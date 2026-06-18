// All named routes for go_router
class RouteNames {
  RouteNames._();

  // Auth
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String registerCEO = '/register/ceo';
  static const String registerSupplier = '/register/supplier';
  static const String registerFieldUser = '/register/field-user';
  static const String forgotPassword = '/forgot-password';
  static const String inviteLanding = '/invite/:token';
  
  // Account Status
  static const String pendingApproval = '/account/pending';
  static const String suspended = '/account/suspended';
  static const String rejected = '/account/rejected';

  // Admin
  static const String adminDashboard = '/admin/dashboard';
  static const String adminCompanies = '/admin/companies';
  static const String adminCategories = '/admin/categories';
  static const String adminPayments = '/admin/payments';
  static const String adminSubscription = '/admin/subscriptions';

  // CEO
  static const String ceoDashboard = '/ceo/dashboard';
  static const String ceoPending = '/ceo/pending';
  static const String ceoMarketplace = '/ceo/marketplace';
  static const String ceoJoinRequests = '/ceo/join-requests';
  static const String ceoInvite = '/ceo/invite';
  static const String ceoMySuppliers = '/ceo/suppliers';
  static const String ceoFieldUsers = '/ceo/field-users';
  static const String ceoOrders = '/ceo/orders';
  static const String ceoSubscription = '/ceo/subscription';
  static const String ceoProfile = '/ceo/profile';

  // Supplier
  static const String supplierDashboard = '/supplier/dashboard';
  static const String supplierPending = '/supplier/pending';
  static const String supplierAppeal = '/supplier/appeal';
  static const String supplierMaterials = '/supplier/materials';
  static const String supplierAddMaterial = '/supplier/add-material';
  static const String supplierEditMaterial = '/supplier/edit-material/:matId';
  static const String supplierOrders = '/supplier/orders';
  static const String supplierChat = '/supplier/chat';
  static const String supplierChatThread = '/supplier/chat/:orderId';
  static const String supplierRatings = '/supplier/ratings';
  static const String supplierEarnings = '/supplier/earnings';
  static const String supplierDirectory = '/supplier/directory';
  static const String supplierProfile = '/supplier/profile';

  // Field User
  static const String fieldHome = '/field/home';
  static const String fieldCategory = '/field/category/:categoryName';
  static const String fieldSearch = '/field/search';
  static const String fieldCompare = '/field/compare/:materialId';
  static const String fieldCompareRates = '/field/compare-rates';
  static const String fieldMarketplace = '/field/marketplace';
  static const String fieldTrend = '/field/trend/:matId/:supplierUid';
  static const String fieldSupplierProfile = '/field/supplier/:supplierUid';
  static const String fieldPlaceOrder = '/field/place-order';
  static const String fieldOrders = '/field/orders';
  static const String fieldOrderDetail = '/field/order/:orderId';
  static const String fieldWeightReport = '/field/weight-report/:orderId';
  static const String fieldChat = '/field/chat';
  static const String fieldChatThread = '/field/chat/:orderId';
  static const String fieldRateSupplier = '/field/rate/:orderId';
  static const String fieldNotifications = '/field/notifications';
  static const String fieldProfile = '/field/profile';
}
