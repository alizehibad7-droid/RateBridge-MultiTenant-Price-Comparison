// Application-wide constants
class AppConstants {
  AppConstants._();

  // Commission
  static const double commissionRate = 0.02;

  // Pagination
  static const int paginationLimit = 20;

  // Price history
  static const int priceHistoryMinForAI = 3;

  // Image constraints
  static const int maxImageSizeBytes = 200 * 1024; // 200KB
  static const int maxImageDimension = 800;

  // Invite token expiry
  static const Duration inviteTokenExpiry = Duration(days: 7);

  // AI rate limit
  static const int geminiRateLimit = 14;

  // Debounce
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration supplierSearchDebounce = Duration(milliseconds: 400);

  // Subscription
  static const int subscriptionWarningDays = 7;
  static const int subscriptionDurationDays = 30;

  // Cache
  static const String prefsLanguageKey = 'preferred_language';
  static const String prefsRecentSearchesKey = 'recent_searches';
  static const String prefsOnboardingKey = 'onboarding_complete';

  // Plans
  static const String planFree = 'free';
  static const String planBasic = 'basic';
  static const String planPremium = 'premium';

  // Plan prices (PKR)
  static const int planBasicPrice = 1000;
  static const int planPremiumPrice = 5000;

  // User roles
  static const String roleAdmin = 'admin';
  static const String roleCEO = 'ceo';
  static const String roleSupplier = 'supplier';
  static const String roleFieldUser = 'fieldUser';

  // Order statuses
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusInProgress = 'inProgress';
  static const String statusDelivered = 'delivered';
  static const String statusConfirmed = 'confirmed';
  static const String statusRejected = 'rejected';
  static const String statusCancelled = 'cancelled';

  // Material categories
  static const List<String> defaultCategories = [
    'Cement', 'Steel', 'Bricks', 'Sand', 'Electrical',
  ];
}
