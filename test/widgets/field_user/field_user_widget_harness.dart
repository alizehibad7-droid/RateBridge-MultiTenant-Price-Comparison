import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ratebridge/constants/route_names.dart';
import 'package:ratebridge/models/category_model.dart';
import 'package:ratebridge/models/chat_message_model.dart';
import 'package:ratebridge/models/chat_thread_model.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/material_listing.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/models/dispute_model.dart';
import 'package:ratebridge/models/notification_model.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/models/price_history_model.dart';
import 'package:ratebridge/models/rating_model.dart';
import 'package:ratebridge/models/supplier_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/repositories/material_repository.dart';
import 'package:ratebridge/repositories/order_repository.dart';
import 'package:ratebridge/repositories/user_repository.dart';
import 'package:ratebridge/services/ai_context_service.dart';
import 'package:ratebridge/services/recently_viewed_service.dart';
import 'package:ratebridge/theme/field_theme.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_catalog_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_chat_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_compare_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_orders_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_rating_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_session_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_supplier_profile_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_trends_viewmodel.dart';
import 'package:ratebridge/viewmodels/notification_viewmodel.dart';
import 'package:ratebridge/viewmodels/dispute_viewmodel.dart';
import 'package:ratebridge/views/field_user/orders/field_order_status.dart';

import '../../mocks/mocks.dart';

UserModel fieldUser({
  String uid = 'field-1',
  String name = 'Hassan Field',
  String status = 'active',
}) {
  return UserModel(
    uid: uid,
    email: 'hassan@acme.test',
    name: name,
    role: 'field_user',
    companyId: 'co-1',
    phone: '03007654321',
    city: 'Lahore',
    status: status,
    createdAt: DateTime.utc(2026, 2, 1),
  );
}

CompanyModel sampleCompany({
  String id = 'co-1',
  String name = 'Acme Builders',
  String city = 'Lahore',
  String status = 'active',
}) {
  return CompanyModel(
    id: id,
    name: name,
    registrationNumber: 'NTN-1',
    address: 'Lahore',
    city: city,
    phone: '03001111111',
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    inviteCode: 'RB-ACME01',
    plan: 'free',
    ceoUid: 'ceo-1',
    ceoFullName: 'Ali CEO',
    designation: 'CEO',
    companyType: 'Private Limited',
    estimatedMonthlyVolume: 'PKR 2M',
    activeSitesCount: 4,
    autoApprovalThreshold: 25000,
  );
}

MaterialModel sampleMaterial({
  String id = 'mat-1',
  String name = 'Lucky Cement',
  String category = 'Cement',
}) {
  return MaterialModel(
    id: id,
    name: name,
    category: category,
    pricePerUnit: 1250,
    unit: 'bag',
    specifications: 'OPC 53',
    qualityGrade: 'OPC 53',
    supplierId: 'sup-1',
    supplierName: 'Skyline Materials',
    isCertified: true,
    originCity: 'Karachi',
    brand: 'Lucky',
    stockStatus: 'Available',
    description: 'Premium OPC bags',
    createdAt: DateTime.utc(2026, 3, 1),
  );
}

CategoryModel sampleCategory({
  String id = 'cat-cement',
  String name = 'Cement',
  String unit = 'bag',
}) {
  return CategoryModel(
    id: id,
    name: name,
    unit: unit,
    brands: const ['Lucky', 'DG Khan'],
    grades: const ['OPC 43', 'OPC 53'],
  );
}

OrderModel sampleOrder({
  String id = 'order-001',
  String status = 'pending',
  String materialName = 'Lucky Cement',
}) {
  return OrderModel(
    orderId: id,
    companyId: 'co-1',
    fieldUserUid: 'field-1',
    supplierId: 'sup-1',
    materialId: 'mat-1',
    materialName: materialName,
    supplierName: 'Skyline Materials',
    fieldUserName: 'Hassan Field',
    quantity: 50,
    unit: 'bag',
    unitPrice: 1250,
    totalAmount: 62500,
    deliveryAddress: 'Site A, Lahore',
    status: status,
    createdAt: DateTime.utc(2026, 4, 1),
    updatedAt: DateTime.utc(2026, 4, 1),
  );
}

RatingModel sampleRating({
  String id = 'rating-1',
  String materialName = 'Lucky Cement',
  double rating = 4.5,
}) {
  return RatingModel(
    id: id,
    orderId: 'order-001',
    supplierUid: 'sup-1',
    userId: 'field-1',
    userName: 'Hassan Field',
    materialId: 'mat-1',
    materialName: materialName,
    rating: rating,
    comment: 'Bags arrived in good condition.',
    dimensions: const {
      'Quality': 4.5,
      'Packaging': 4.0,
      'Quantity': 5.0,
      'Timeliness': 4.0,
    },
    createdAt: DateTime.utc(2026, 4, 2),
  );
}

MaterialListing sampleListing({
  String id = 'mat-1',
  String materialName = 'Lucky Cement',
}) {
  return MaterialListing(
    id: id,
    materialName: materialName,
    supplierName: 'Skyline Materials',
    supplierId: 'sup-1',
    pricePerUnit: 1250,
    unit: 'bag',
    category: 'Cement',
    city: 'Karachi',
    brand: 'Lucky',
    qualityGrade: 'OPC 53',
  );
}

SupplierModel sampleSupplier({
  String id = 'sup-1',
  String name = 'Skyline Materials',
}) {
  return SupplierModel(
    id: id,
    name: name,
    email: 'sales@skyline.test',
    materialType: 'Cement',
    contact: '03009998888',
    status: 'Active',
    rating: 4.5,
    activeContracts: 3,
    contractValue: 120000,
    leadTimeDays: 2,
    city: 'Karachi',
  );
}

NotificationModel sampleNotification({
  String id = 'n-1',
  bool isRead = false,
  String type = 'order',
  String title = 'Order update',
  String message = 'Lucky Cement is on the way.',
  Map<String, dynamic> data = const {},
}) {
  return NotificationModel(
    notifId: id,
    recipientUserId: 'field-1',
    recipientRole: 'field_user',
    type: type,
    title: title,
    message: message,
    data: data,
    isRead: isRead,
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

ChatThreadModel sampleThread({
  String id = 'chat-1',
  String lastMessage = 'Need 50 more bags tomorrow.',
  int unreadFieldUser = 0,
}) {
  return ChatThreadModel(
    chatId: id,
    companyId: 'co-1',
    fieldUserId: 'field-1',
    supplierId: 'sup-1',
    supplierName: 'Skyline Materials',
    fieldUserName: 'Hassan Field',
    lastMessage: lastMessage,
    lastMessageAt: DateTime.utc(2026, 4, 3, 10),
    lastSenderId: 'field-1',
    unreadFieldUser: unreadFieldUser,
  );
}

ChatMessageModel sampleMessage({
  String id = 'msg-1',
  String content = 'Need 50 more bags tomorrow.',
  String senderId = 'field-1',
}) {
  return ChatMessageModel(
    id: id,
    chatId: 'chat-1',
    companyId: 'co-1',
    senderId: senderId,
    senderName: senderId == 'sup-1' ? 'Skyline Materials' : 'Hassan Field',
    receiverId: senderId == 'sup-1' ? 'field-1' : 'sup-1',
    content: content,
    timestamp: DateTime.utc(2026, 4, 3, 10),
  );
}

PriceHistoryModel samplePriceHistory({
  String id = 'hist-1',
  double price = 1250,
  DateTime? timestamp,
}) {
  return PriceHistoryModel(
    histId: id,
    materialId: 'mat-1',
    supplierUid: 'sup-1',
    companyId: 'co-1',
    price: price,
    timestamp: timestamp ?? DateTime.utc(2026, 3, 1),
  );
}

void stubAuthViewModel(MockAuthViewModel auth, {UserModel? user}) {
  final current = user ?? fieldUser();
  when(() => auth.user).thenReturn(current);
  when(() => auth.role).thenReturn(current.role);
  when(() => auth.companyId).thenReturn(current.companyId);
  when(() => auth.isLoading).thenReturn(false);
  when(() => auth.errorMessage).thenReturn(null);
  when(() => auth.isAuthenticated).thenReturn(true);
  when(() => auth.signOut()).thenAnswer((_) async {});
  when(() => auth.logout()).thenAnswer((_) async {});
}

void stubNotificationViewModel(MockNotificationViewModel notif) {
  when(() => notif.uid).thenReturn('field-1');
  when(() => notif.unreadCount).thenReturn(0);
  when(() => notif.isLoading).thenReturn(false);
  when(() => notif.errorMessage).thenReturn(null);
  when(() => notif.notifications).thenReturn(const []);
  when(() => notif.markAllRead(any())).thenAnswer((_) async {});
  when(() => notif.markAsRead(any(), any())).thenAnswer((_) async {});
  when(() => notif.loadNotifications(any())).thenReturn(null);
  when(() => notif.watchUnreadCount(any())).thenReturn(null);
  when(notif.clearError).thenReturn(null);
}

void stubUserRepository(MockUserRepository repo) {
  when(() => repo.getUserDoc(any())).thenAnswer((_) async => fieldUser());
  when(() => repo.updateUserDoc(any(), any())).thenAnswer((_) async {});
}

void stubOrderRepository(MockOrderRepository repo) {
  when(() => repo.getSupplierById(any()))
      .thenAnswer((_) async => sampleSupplier());
}

void stubMaterialRepository(MockMaterialRepository repo) {
  when(() => repo.getMaterialById(any()))
      .thenAnswer((_) async => sampleMaterial());
  when(() => repo.getMaterialsByNameForCompany(any(), any()))
      .thenAnswer((_) async => [sampleMaterial()]);
}

void stubFieldSessionViewModel(
  MockFieldSessionViewModel session, {
  UserModel? user,
  CompanyModel? company,
}) {
  final currentUser = user ?? fieldUser();
  final currentCompany = company ?? sampleCompany();
  when(() => session.user).thenReturn(currentUser);
  when(() => session.company).thenReturn(currentCompany);
  when(() => session.companyId).thenReturn(currentUser.companyId);
  when(() => session.companyName).thenReturn(currentCompany.name);
  when(() => session.isLoading).thenReturn(false);
  when(() => session.errorMessage).thenReturn(null);
  when(() => session.updateAuth(any())).thenReturn(null);
  when(() => session.loadCompanyContext()).thenAnswer((_) async {});
  when(() => session.refreshProfile()).thenAnswer((_) async {});
  when(
    () => session.updateProfile(
      name: any(named: 'name'),
      phone: any(named: 'phone'),
    ),
  ).thenAnswer((_) async => true);
  when(session.clearError).thenReturn(null);
}

void stubFieldCatalogViewModel(MockFieldCatalogViewModel catalog) {
  when(() => catalog.isLoading).thenReturn(false);
  when(() => catalog.isCatalogLoading).thenReturn(false);
  when(() => catalog.errorMessage).thenReturn(null);
  when(() => catalog.materials).thenReturn(const []);
  when(() => catalog.catalogMaterials).thenReturn(const []);
  when(() => catalog.searchResults).thenReturn(const []);
  when(() => catalog.recentMaterials).thenReturn(const []);
  when(() => catalog.recentlyViewedMaterials).thenReturn(const []);
  when(() => catalog.categories).thenReturn(const []);
  when(() => catalog.browseCategories).thenReturn(const []);
  when(() => catalog.uniqueCategories).thenReturn(const []);
  when(() => catalog.materialCategoryNames).thenReturn(const []);
  when(() => catalog.categoryFilter).thenReturn(null);
  when(() => catalog.sortOption).thenReturn(CatalogSortOption.priceAsc);
  when(() => catalog.hasCachedMaterials).thenReturn(false);
  when(() => catalog.supplierRatingFor(any())).thenReturn(0.0);
  when(() => catalog.materialCountForCategory(any())).thenReturn(0);
  when(() => catalog.loadHomeData(any())).thenAnswer((_) async {});
  when(() => catalog.loadMarketplace(any())).thenAnswer((_) async {});
  when(
    () => catalog.loadRecentlyViewedMaterials(any(), any()),
  ).thenAnswer((_) async {});
  when(() => catalog.loadCategoriesBrowse(any())).thenAnswer((_) async {});
  when(() => catalog.filterByCategory(any())).thenReturn(null);
  when(() => catalog.filterByCategory(null)).thenReturn(null);
  when(() => catalog.setSortOption(any())).thenAnswer((_) async {});
  when(catalog.clearFilters).thenReturn(null);
  when(() => catalog.searchLocalMaterials(any())).thenReturn(null);
  when(catalog.clearSearchResults).thenReturn(null);
  when(() => catalog.prefetchSupplierRatings()).thenAnswer((_) async {});
  when(catalog.clearRecentlyViewedDisplay).thenReturn(null);
  when(catalog.clearError).thenReturn(null);
}

void stubFieldOrdersViewModel(MockFieldOrdersViewModel orders) {
  when(() => orders.isSubmitting).thenReturn(false);
  when(() => orders.isLoadingOrders).thenReturn(false);
  when(() => orders.errorMessage).thenReturn(null);
  when(() => orders.orders).thenReturn(const []);
  when(() => orders.recentOrders).thenReturn(const []);
  when(() => orders.pendingCount).thenReturn(0);
  when(() => orders.activeCount).thenReturn(0);
  when(() => orders.deliveredCount).thenReturn(0);
  when(() => orders.historyCount).thenReturn(0);
  when(() => orders.activeOrders).thenReturn(const []);
  when(() => orders.hasPendingOrdersSubTab).thenReturn(false);
  when(() => orders.ordersForTab(any())).thenReturn(const []);
  when(() => orders.requestOrdersSubTab(any())).thenReturn(null);
  when(() => orders.consumeRequestedOrdersSubTab()).thenReturn(null);
  when(() => orders.watchOrders(any(), any())).thenReturn(null);
  when(() => orders.findOrder(any())).thenReturn(null);
  when(() => orders.fetchOrder(any())).thenAnswer((_) async => null);
  when(() => orders.fetchOrderFromServer(any())).thenAnswer((_) async => null);
  when(() => orders.fetchSupplier(any())).thenAnswer((_) async => null);
  when(
    () => orders.hasRatingForOrder(any(), any()),
  ).thenAnswer((_) async => false);
  when(
    () => orders.hasUserRatedOrder(any(), any()),
  ).thenAnswer((_) async => false);
  when(
    () => orders.placeOrderFromListing(
      companyId: any(named: 'companyId'),
      fieldUserUid: any(named: 'fieldUserUid'),
      fieldUserName: any(named: 'fieldUserName'),
      fieldUserPhone: any(named: 'fieldUserPhone'),
      material: any(named: 'material'),
      quantity: any(named: 'quantity'),
      deliveryAddress: any(named: 'deliveryAddress'),
      requiredDate: any(named: 'requiredDate'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer((_) async => true);
  when(
    () => orders.placeOrder(
      companyId: any(named: 'companyId'),
      fieldUserUid: any(named: 'fieldUserUid'),
      fieldUserName: any(named: 'fieldUserName'),
      fieldUserPhone: any(named: 'fieldUserPhone'),
      material: any(named: 'material'),
      quantity: any(named: 'quantity'),
      siteLocation: any(named: 'siteLocation'),
      requiredDate: any(named: 'requiredDate'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer((_) async => true);
  when(
    () => orders.confirmDelivery(
      orderId: any(named: 'orderId'),
      companyId: any(named: 'companyId'),
    ),
  ).thenAnswer((_) async => true);
  when(
    () => orders.submitWeightReport(
      orderId: any(named: 'orderId'),
      companyId: any(named: 'companyId'),
      actualWeight: any(named: 'actualWeight'),
      remarks: any(named: 'remarks'),
    ),
  ).thenAnswer((_) async => true);
  when(() => orders.cancelOrder(any(), any())).thenAnswer((_) async => true);
  when(orders.clearError).thenReturn(null);
}

void stubFieldRatingViewModel(MockFieldRatingViewModel rating) {
  when(() => rating.isLoading).thenReturn(false);
  when(() => rating.isCheckingExisting).thenReturn(false);
  when(() => rating.errorMessage).thenReturn(null);
  when(
    () => rating.hasUserRatedOrder(any(), any()),
  ).thenAnswer((_) async => false);
  when(
    () => rating.submitRating(
      orderId: any(named: 'orderId'),
      companyId: any(named: 'companyId'),
      rating: any(named: 'rating'),
    ),
  ).thenAnswer((_) async => FieldRatingSubmitResult.success);
  when(rating.clearError).thenReturn(null);
}

void stubFieldChatViewModel(MockFieldChatViewModel chat) {
  when(() => chat.isLoadingThreads).thenReturn(false);
  when(() => chat.isLoadingMessages).thenReturn(false);
  when(() => chat.isSending).thenReturn(false);
  when(() => chat.errorMessage).thenReturn(null);
  when(() => chat.threads).thenReturn(const []);
  when(() => chat.messages).thenReturn(const []);
  when(() => chat.unreadMessageCount).thenReturn(0);
  when(() => chat.watchConversations(any(), any())).thenReturn(null);
  when(
    () => chat.startListening(any(), currentUserId: any(named: 'currentUserId')),
  ).thenAnswer((_) async {});
  when(
    () => chat.openThread(
      companyId: any(named: 'companyId'),
      fieldUserId: any(named: 'fieldUserId'),
      fieldUserName: any(named: 'fieldUserName'),
      supplierId: any(named: 'supplierId'),
      supplierName: any(named: 'supplierName'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => chat.sendMessage(
      companyId: any(named: 'companyId'),
      fieldUserId: any(named: 'fieldUserId'),
      fieldUserName: any(named: 'fieldUserName'),
      supplierId: any(named: 'supplierId'),
      supplierName: any(named: 'supplierName'),
      content: any(named: 'content'),
      attachmentUrl: any(named: 'attachmentUrl'),
    ),
  ).thenAnswer((_) async => true);
  when(chat.closeThread).thenReturn(null);
  when(chat.clearError).thenReturn(null);
}

void stubFieldCompareViewModel(MockFieldCompareViewModel compare) {
  when(() => compare.isLoading).thenReturn(false);
  when(() => compare.errorMessage).thenReturn(null);
  when(() => compare.results).thenReturn(const []);
  when(() => compare.rawResults).thenReturn(const []);
  when(() => compare.materialName).thenReturn(null);
  when(() => compare.sortBy).thenReturn(CompareSortOption.price);
  when(() => compare.cityFilter).thenReturn(null);
  when(() => compare.showAiCard).thenReturn(false);
  when(() => compare.isAiLoading).thenReturn(false);
  when(() => compare.aiSummary).thenReturn(null);
  when(() => compare.hasCityFilter).thenReturn(false);
  when(() => compare.availableCities).thenReturn(const []);
  when(() => compare.bestPrice).thenReturn(null);
  when(() => compare.bestValueSupplier).thenReturn(null);
  when(() => compare.badgeFor(any())).thenReturn(CompareBadgeType.none);
  when(() => compare.insightLineFor(any())).thenReturn(null);
  when(() => compare.loadComparison(any(), any())).thenAnswer((_) async {});
  when(() => compare.loadCompareRates(any(), any())).thenAnswer((_) async {});
  when(() => compare.setSortBy(any())).thenReturn(null);
  when(() => compare.setCityFilter(any())).thenReturn(null);
  when(() => compare.setCityFilter(null)).thenReturn(null);
  when(compare.clearCityFilter).thenReturn(null);
  when(compare.clearError).thenReturn(null);
}

void stubFieldSupplierProfileViewModel(
  MockFieldSupplierProfileViewModel profile,
) {
  when(() => profile.supplier).thenReturn(null);
  when(() => profile.averageRating).thenReturn(0.0);
  when(() => profile.materials).thenReturn(const []);
  when(() => profile.recentRatings).thenReturn(const []);
  when(() => profile.ratingCount).thenReturn(0);
  when(() => profile.isLoading).thenReturn(false);
  when(() => profile.errorMessage).thenReturn(null);
  when(() => profile.qualityAverage).thenReturn(0.0);
  when(() => profile.deliveryAverage).thenReturn(0.0);
  when(() => profile.load(any(), any())).thenAnswer((_) async {});
  when(profile.clearError).thenReturn(null);
}

void stubFieldTrendsViewModel(MockFieldTrendsViewModel trends) {
  when(() => trends.isLoading).thenReturn(false);
  when(() => trends.errorMessage).thenReturn(null);
  when(() => trends.history).thenReturn(const []);
  when(() => trends.chartPoints).thenReturn(const []);
  when(() => trends.trendDirection).thenReturn('stable');
  when(() => trends.materialName).thenReturn(null);
  when(() => trends.supplierName).thenReturn(null);
  when(() => trends.showAiCard).thenReturn(false);
  when(() => trends.isAiLoading).thenReturn(false);
  when(() => trends.aiInsight).thenReturn(null);
  when(() => trends.distinctMonthCount).thenReturn(0);
  when(() => trends.hasEnoughDataForAi).thenReturn(false);
  when(() => trends.hasEnoughChartData).thenReturn(false);
  when(() => trends.currentPrice).thenReturn(null);
  when(() => trends.periodChangePercent).thenReturn(null);
  when(() => trends.lowestPrice).thenReturn(null);
  when(() => trends.highestPrice).thenReturn(null);
  when(() => trends.loadTrends(any(), any(), any())).thenAnswer((_) async {});
  when(() => trends.loadPriceTrend(any(), any(), any())).thenAnswer((_) async {});
  when(trends.clearError).thenReturn(null);
}

bool _isIgnorableFieldUserTestErrorText(String text) {
  return text.contains('ListTile background color') ||
      text.contains('NetworkImageLoadException') ||
      text.contains('HTTP request failed') ||
      text.contains('resolving an image codec') ||
      text.contains('Invalid image data') ||
      text.contains('Connection refused') ||
      text.contains('SocketException') ||
      text.contains('HandshakeException');
}

void drainIgnorableExceptions(WidgetTester tester) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    if (!_isIgnorableFieldUserTestErrorText(error.toString())) {
      fail('Unexpected exception during field-user widget test: $error');
    }
  }
}

void ignoreKnownFieldUserTestErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (_isIgnorableFieldUserTestErrorText(text) ||
        _isIgnorableFieldUserTestErrorText('${details.context}')) {
      return;
    }
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Finder textFieldByHint(String hint) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.hintText == hint,
    ),
    matching: find.byType(EditableText),
  );
}

void registerFieldUserWidgetFallbacks() {
  Provider.debugCheckInvalidValueType = null;
  registerFallbackValue('');
  registerFallbackValue(0);
  registerFallbackValue(0.0);
  registerFallbackValue(false);
  registerFallbackValue(DateTime.utc(2026, 5, 1));
  registerFallbackValue(<String>[]);
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(sampleCompany());
  registerFallbackValue(sampleMaterial());
  registerFallbackValue(sampleOrder());
  registerFallbackValue(sampleListing());
  registerFallbackValue(sampleRating());
  registerFallbackValue(sampleSupplier());
  registerFallbackValue(sampleCategory());
  registerFallbackValue(sampleThread());
  registerFallbackValue(sampleMessage());
  registerFallbackValue(samplePriceHistory());
  registerFallbackValue(CatalogSortOption.priceAsc);
  registerFallbackValue(CompareSortOption.price);
  registerFallbackValue(FieldOrderTab.pending);
  registerFallbackValue(MockAuthViewModel());
}

Future<void> pumpFieldScreen(
  WidgetTester tester, {
  required Widget child,
  MockFieldSessionViewModel? session,
  MockFieldCatalogViewModel? catalog,
  MockFieldOrdersViewModel? orders,
  MockFieldRatingViewModel? rating,
  MockFieldChatViewModel? chat,
  MockFieldCompareViewModel? compare,
  MockFieldSupplierProfileViewModel? supplierProfile,
  MockFieldTrendsViewModel? trends,
  MockAuthViewModel? auth,
  MockNotificationViewModel? notifications,
  MockUserRepository? users,
  MockOrderRepository? orderRepository,
  MockMaterialRepository? materialRepository,
  MockDisputeViewModel? dispute,
  Map<String, Object> prefsValues = const {},
  bool pumpPostFrame = true,
  Size surfaceSize = const Size(1200, 8000),
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  Provider.debugCheckInvalidValueType = null;
  SharedPreferences.setMockInitialValues(prefsValues);
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  ignoreKnownFieldUserTestErrors();

  final sessionVm = session ?? MockFieldSessionViewModel();
  if (session == null) stubFieldSessionViewModel(sessionVm);

  final catalogVm = catalog ?? MockFieldCatalogViewModel();
  if (catalog == null) stubFieldCatalogViewModel(catalogVm);

  final ordersVm = orders ?? MockFieldOrdersViewModel();
  if (orders == null) stubFieldOrdersViewModel(ordersVm);

  final ratingVm = rating ?? MockFieldRatingViewModel();
  if (rating == null) stubFieldRatingViewModel(ratingVm);

  final chatVm = chat ?? MockFieldChatViewModel();
  if (chat == null) stubFieldChatViewModel(chatVm);

  final compareVm = compare ?? MockFieldCompareViewModel();
  if (compare == null) stubFieldCompareViewModel(compareVm);

  final profileVm = supplierProfile ?? MockFieldSupplierProfileViewModel();
  if (supplierProfile == null) stubFieldSupplierProfileViewModel(profileVm);

  final trendsVm = trends ?? MockFieldTrendsViewModel();
  if (trends == null) stubFieldTrendsViewModel(trendsVm);

  final authVm = auth ?? MockAuthViewModel();
  if (auth == null) stubAuthViewModel(authVm);

  final notifVm = notifications ?? MockNotificationViewModel();
  if (notifications == null) stubNotificationViewModel(notifVm);

  final userRepo = users ?? MockUserRepository();
  if (users == null) stubUserRepository(userRepo);

  final orderRepo = orderRepository ?? MockOrderRepository();
  if (orderRepository == null) stubOrderRepository(orderRepo);

  final materialRepo = materialRepository ?? MockMaterialRepository();
  if (materialRepository == null) stubMaterialRepository(materialRepo);

  final disputeVm = dispute ?? MockDisputeViewModel();
  if (dispute == null) {
    when(() => disputeVm.isLoading).thenReturn(false);
    when(() => disputeVm.error).thenReturn(null);
    when(() => disputeVm.watchMyDisputes(any()))
        .thenAnswer((_) => Stream<List<DisputeModel>>.value(const []));
    when(() => disputeVm.watchDispute(any()))
        .thenAnswer((_) => Stream<DisputeModel?>.value(null));
    when(
      () => disputeVm.withdrawDispute(
        uid: any(named: 'uid'),
        disputeId: any(named: 'disputeId'),
      ),
    ).thenAnswer((_) async {});
  }

  final prefs = await SharedPreferences.getInstance();
  final recentlyViewed = RecentlyViewedService(prefs);
  final aiContext = AiContextService();

  Widget stub(String label) => Scaffold(body: Text(label));

  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => stub('root-screen'),
        routes: [
          GoRoute(
            path: 'screen',
            builder: (_, __) => FieldTheme.wrap(child),
          ),
        ],
      ),
      GoRoute(path: RouteNames.login, builder: (_, __) => stub('login-screen')),
      GoRoute(
        path: RouteNames.roleSelection,
        builder: (_, __) => stub('role-selection'),
      ),
      GoRoute(
        path: RouteNames.fieldHome,
        builder: (_, __) => stub('field-home'),
      ),
      GoRoute(
        path: RouteNames.fieldSearch,
        builder: (_, __) => stub('field-search'),
      ),
      GoRoute(
        path: RouteNames.fieldMarketplace,
        builder: (_, __) => stub('field-marketplace'),
      ),
      GoRoute(
        path: RouteNames.fieldCategories,
        builder: (_, __) => stub('field-categories'),
      ),
      GoRoute(
        path: RouteNames.fieldCategory,
        builder: (_, __) => stub('field-category'),
      ),
      GoRoute(
        path: RouteNames.fieldOrders,
        builder: (_, __) => stub('field-orders'),
      ),
      GoRoute(
        path: RouteNames.fieldOrderDetail,
        builder: (_, __) => stub('field-order-detail'),
      ),
      GoRoute(
        path: RouteNames.fieldPlaceOrder,
        builder: (_, __) => stub('field-place-order'),
      ),
      GoRoute(
        path: RouteNames.fieldWeightReport,
        builder: (_, __) => stub('field-weight-report'),
      ),
      GoRoute(
        path: RouteNames.fieldRateSupplier,
        builder: (_, __) => stub('field-rate-supplier'),
      ),
      GoRoute(
        path: RouteNames.fieldChat,
        builder: (_, __) => stub('field-chat'),
      ),
      GoRoute(
        path: RouteNames.fieldChatThread,
        builder: (_, __) => stub('field-chat-thread'),
      ),
      GoRoute(
        path: RouteNames.fieldProfile,
        builder: (_, __) => stub('field-profile'),
      ),
      GoRoute(
        path: RouteNames.fieldNotifications,
        builder: (_, __) => stub('field-notifications'),
      ),
      GoRoute(
        path: RouteNames.fieldMyDisputes,
        builder: (_, __) => stub('field-my-disputes'),
      ),
      GoRoute(
        path: RouteNames.fieldDisputeDetail,
        builder: (_, __) => stub('field-dispute-detail'),
      ),
      GoRoute(
        path: RouteNames.fieldCompare,
        builder: (_, __) => stub('field-compare'),
      ),
      GoRoute(
        path: RouteNames.fieldCompareRates,
        builder: (_, __) => stub('field-compare-rates'),
      ),
      GoRoute(
        path: RouteNames.fieldRfqs,
        builder: (_, __) => stub('field-rfqs'),
      ),
      GoRoute(
        path: RouteNames.fieldSupplierProfile,
        builder: (_, __) => stub('field-supplier-profile'),
      ),
      GoRoute(
        path: RouteNames.fieldTrend,
        builder: (_, __) => stub('field-trend'),
      ),
      GoRoute(
        path: RouteNames.fieldRecentlyViewed,
        builder: (_, __) => stub('field-recently-viewed'),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthViewModel>.value(value: authVm),
        Provider<FieldSessionViewModel>.value(value: sessionVm),
        Provider<FieldCatalogViewModel>.value(value: catalogVm),
        Provider<FieldOrdersViewModel>.value(value: ordersVm),
        Provider<FieldRatingViewModel>.value(value: ratingVm),
        Provider<FieldChatViewModel>.value(value: chatVm),
        Provider<FieldCompareViewModel>.value(value: compareVm),
        Provider<FieldSupplierProfileViewModel>.value(value: profileVm),
        Provider<FieldTrendsViewModel>.value(value: trendsVm),
        Provider<NotificationViewModel>.value(value: notifVm),
        Provider<UserRepository>.value(value: userRepo),
        Provider<OrderRepository>.value(value: orderRepo),
        Provider<MaterialRepository>.value(value: materialRepo),
        Provider<DisputeViewModel>.value(value: disputeVm),
        Provider<SharedPreferences>.value(value: prefs),
        Provider<RecentlyViewedService>.value(value: recentlyViewed),
        Provider<AiContextService>.value(value: aiContext),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (pumpPostFrame) {
    await tester.pump();
  }
  drainIgnorableExceptions(tester);
}
