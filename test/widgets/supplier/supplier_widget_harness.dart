import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ratebridge/constants/route_names.dart';
import 'package:ratebridge/models/category_model.dart';
import 'package:ratebridge/models/chat_message_model.dart';
import 'package:ratebridge/models/chat_thread_model.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/dispute_model.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/models/notification_model.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/models/partner_company_stats.dart';
import 'package:ratebridge/models/partnership_request_model.dart';
import 'package:ratebridge/models/payment_proof_model.dart';
import 'package:ratebridge/models/rating_model.dart';
import 'package:ratebridge/models/rfq_bid_model.dart';
import 'package:ratebridge/models/rfq_model.dart';
import 'package:ratebridge/models/transaction_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/repositories/chat_repository.dart';
import 'package:ratebridge/repositories/user_repository.dart';
import 'package:ratebridge/services/notification_service.dart';
import 'package:ratebridge/theme/supplier_theme.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/chat_viewmodel.dart';
import 'package:ratebridge/viewmodels/dispute_viewmodel.dart';
import 'package:ratebridge/viewmodels/material_viewmodel.dart';
import 'package:ratebridge/viewmodels/notification_viewmodel.dart';
import 'package:ratebridge/viewmodels/supplier_viewmodel.dart';

import '../../mocks/mocks.dart';

UserModel supplierUser({
  String status = 'active',
  String? rejectionReason,
  String name = 'Skyline Materials',
}) {
  return UserModel(
    uid: 'sup-1',
    email: 'sales@skyline.test',
    name: name,
    role: 'Supplier',
    companyId: 'co-1',
    phone: '03009998888',
    city: 'Karachi',
    status: status,
    rejectionReason: rejectionReason,
    businessType: 'Material Supplier',
    createdAt: DateTime.utc(2026, 1, 15),
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

TransactionModel sampleTransaction({
  String id = 'tx-1',
  String status = 'unsettled',
}) {
  return TransactionModel(
    txId: id,
    orderId: 'order-001',
    companyId: 'co-1',
    supplierUid: 'sup-1',
    totalAmount: 62500,
    commissionRate: 0.02,
    commissionAmount: 1250,
    supplierEarning: 61250,
    status: status,
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

ChatThreadModel sampleThread({
  String id = 'chat-1',
  String lastMessage = 'Need 50 more bags tomorrow.',
  int unreadSupplier = 0,
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
    unreadSupplier: unreadSupplier,
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

PartnershipRequestModel samplePartnershipRequest({
  String id = 'req-1',
  String status = 'pending',
  String initiatedBy = 'ceo',
  String companyName = 'Acme Builders',
}) {
  return PartnershipRequestModel(
    requestId: id,
    companyId: 'co-1',
    companyName: companyName,
    supplierId: 'sup-1',
    supplierName: 'Skyline Materials',
    initiatedBy: initiatedBy,
    status: status,
    message: 'We would like to partner.',
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

NotificationModel sampleNotification({
  String id = 'n-1',
  bool isRead = false,
  String type = 'order',
  String title = 'New order received',
  String message = 'Hassan Field ordered Lucky Cement.',
  Map<String, dynamic> data = const {},
}) {
  return NotificationModel(
    notifId: id,
    recipientUserId: 'sup-1',
    recipientRole: 'Supplier',
    type: type,
    title: title,
    message: message,
    data: data,
    isRead: isRead,
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

RfqModel sampleRfq({
  String id = 'rfq-1',
  String status = 'open',
}) {
  return RfqModel(
    id: id,
    companyId: 'co-1',
    companyName: 'Acme Builders',
    category: 'Cement',
    materialDescription: 'OPC 53, 500 bags',
    quantity: 500,
    unit: 'bag',
    city: 'Lahore',
    requiredByDate: DateTime.utc(2026, 10, 1),
    status: status,
    createdAt: DateTime.utc(2026, 4, 1),
    createdByUid: 'ceo-1',
  );
}

RfqBidModel sampleBid({
  String id = 'bid-1',
  double bidPrice = 1180,
}) {
  return RfqBidModel(
    id: id,
    rfqId: 'rfq-1',
    supplierId: 'sup-1',
    supplierName: 'Skyline Materials',
    bidPrice: bidPrice,
    estimatedDeliveryTime: '3 days',
    note: 'Ready stock',
    createdAt: DateTime.utc(2026, 4, 2),
  );
}

PaymentProofModel samplePaymentProof({
  String id = 'pay-1',
  String status = 'pending',
}) {
  return PaymentProofModel(
    id: id,
    payerId: 'sup-1',
    companyId: 'co-1',
    payerName: 'Skyline Materials',
    payerRole: 'Supplier',
    amount: 2500,
    method: 'bank_transfer',
    screenshotUrl: '',
    status: status,
    type: 'commission',
    createdAt: DateTime.utc(2026, 4, 5),
  );
}

void stubAuthViewModel(MockAuthViewModel auth, {UserModel? user}) {
  final current = user ?? supplierUser();
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
  when(() => notif.uid).thenReturn('sup-1');
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

void stubChatViewModel(MockChatViewModel chat) {
  when(() => chat.messages).thenReturn(const []);
  when(() => chat.threads).thenReturn(const []);
  when(() => chat.isLoading).thenReturn(false);
  when(() => chat.isLoadingMessages).thenReturn(false);
  when(() => chat.isSending).thenReturn(false);
  when(() => chat.isChatLocked).thenReturn(false);
  when(() => chat.errorMessage).thenReturn(null);
  when(() => chat.unreadMessageCount).thenReturn(0);
  when(() => chat.watchSupplierThreads(any())).thenReturn(null);
  when(
    () => chat.startListening(any(), currentUserId: any(named: 'currentUserId')),
  ).thenAnswer((_) async {});
  when(() => chat.openChatThread(any(), any())).thenAnswer((_) async {});
  when(
    () => chat.sendMessage(any(), any(), any(), any(), any(), any(), any()),
  ).thenAnswer((_) async => true);
  when(() => chat.markRead(any(), any())).thenAnswer((_) async {});
  when(chat.stopListening).thenReturn(null);
}

void stubMaterialViewModel(MockMaterialViewModel material) {
  when(() => material.categories).thenReturn(const []);
  when(() => material.selectedCategory).thenReturn(null);
  when(() => material.isLoading).thenReturn(false);
  when(() => material.isLoadingCategories).thenReturn(false);
  when(() => material.error).thenReturn(null);
  when(() => material.isSuccess).thenReturn(false);
  when(material.resetSuccess).thenReturn(null);
  when(material.resetAddMaterialForm).thenReturn(null);
  when(() => material.loadCategories()).thenAnswer((_) async {});
  when(() => material.onCategorySelected(any())).thenReturn(null);
  when(() => material.selectCategoryByName(any())).thenReturn(null);
  when(
    () => material.addMaterial(any(), any(), any(), any()),
  ).thenAnswer((_) async {});
  when(
    () => material.updateMaterial(any(), any(), any(), any(), any()),
  ).thenAnswer((_) async {});
}

void stubChatRepository(MockChatRepository repo) {
  when(() => repo.markThreadReadForSupplier(any())).thenAnswer((_) async {});
  when(
    () => repo.updateThreadAfterMessage(
      chatId: any(named: 'chatId'),
      companyId: any(named: 'companyId'),
      lastMessage: any(named: 'lastMessage'),
      lastSenderId: any(named: 'lastSenderId'),
      fieldUserId: any(named: 'fieldUserId'),
      supplierId: any(named: 'supplierId'),
      fieldUserName: any(named: 'fieldUserName'),
    ),
  ).thenAnswer((_) async {});
}

void stubUserRepository(MockUserRepository repo) {
  when(() => repo.getUserDoc(any())).thenAnswer(
    (_) async => UserModel(
      uid: 'field-1',
      email: 'hassan@acme.test',
      name: 'Hassan Field',
      role: 'field_user',
      companyId: 'co-1',
      phone: '03007654321',
      city: 'Lahore',
      createdAt: DateTime.utc(2026, 2, 1),
    ),
  );
  when(() => repo.updateUserDoc(any(), any())).thenAnswer((_) async {});
}

void stubNotificationService(MockNotificationService service) {
  when(
    () => service.notifyChatMessage(
      recipientUserId: any(named: 'recipientUserId'),
      senderName: any(named: 'senderName'),
      preview: any(named: 'preview'),
      chatId: any(named: 'chatId'),
      companyId: any(named: 'companyId'),
      fieldUserId: any(named: 'fieldUserId'),
      fieldUserName: any(named: 'fieldUserName'),
      supplierId: any(named: 'supplierId'),
      supplierName: any(named: 'supplierName'),
      orderId: any(named: 'orderId'),
    ),
  ).thenAnswer((_) async {});
}

void stubSupplierViewModel(
  MockSupplierViewModel vm, {
  bool isLoading = false,
}) {
  when(() => vm.supplierUid).thenReturn('sup-1');
  when(() => vm.selectedCompanyId).thenReturn('co-1');
  when(() => vm.rejectionReason).thenReturn(null);
  when(() => vm.error).thenReturn(null);
  when(() => vm.successMessage).thenReturn(null);
  when(() => vm.isLoading).thenReturn(isLoading);
  when(() => vm.partnershipListsReady).thenReturn(true);
  when(() => vm.incomingPartnershipRequests).thenReturn(const []);
  when(() => vm.outgoingPartnershipRequests).thenReturn(const []);
  when(() => vm.allPartnershipRequests).thenReturn(const []);
  when(() => vm.pendingCeoInvitations).thenReturn(const []);
  when(() => vm.pendingSupplierSentRequests).thenReturn(const []);
  when(() => vm.pastPartnershipRequests).thenReturn(const []);
  when(() => vm.pendingPartnershipRequestsCount).thenReturn(0);
  when(() => vm.activePartnerCompanies).thenReturn(const []);
  when(() => vm.partnershipHubDataLoaded).thenReturn(true);
  when(() => vm.isDashboardLoading).thenReturn(false);
  when(() => vm.companiesLoaded).thenReturn(true);
  when(() => vm.companiesLoadFailed).thenReturn(false);
  when(() => vm.appealSubmitted).thenReturn(false);
  when(() => vm.materials).thenReturn(const []);
  when(() => vm.orders).thenReturn(const []);
  when(() => vm.ratings).thenReturn(const []);
  when(() => vm.transactions).thenReturn(const []);
  when(() => vm.companies).thenReturn(const []);
  when(() => vm.companyDirectory).thenReturn(const []);
  when(() => vm.invitations).thenReturn(const []);
  when(() => vm.monthlyEarnings).thenReturn(const []);
  when(() => vm.profile).thenReturn(supplierUser());
  when(() => vm.isCommissionRestricted).thenReturn(false);
  when(() => vm.commissionRestrictionReason).thenReturn(null);
  when(() => vm.status).thenReturn('active');
  when(() => vm.paymentHistory).thenReturn(const []);
  when(() => vm.totalMaterialsCount).thenReturn(0);
  when(() => vm.pendingOrdersCount).thenReturn(0);
  when(() => vm.activeOrdersCount).thenReturn(0);
  when(() => vm.ratingsCount).thenReturn(0);
  when(() => vm.averageRating).thenReturn(0.0);
  when(() => vm.recentOrders).thenReturn(const []);
  when(() => vm.recentMaterials).thenReturn(const []);
  when(() => vm.monthlyEarningsTotal).thenReturn(0.0);
  when(() => vm.completedThisMonth).thenReturn(0);
  when(() => vm.totalCommissionGenerated).thenReturn(0.0);
  when(() => vm.totalCommissionPaid).thenReturn(0.0);
  when(() => vm.commissionOwed).thenReturn(0.0);
  when(() => vm.pendingCommissionApproval).thenReturn(0.0);
  when(() => vm.totalEarnings).thenReturn(0.0);
  when(() => vm.netEarnings).thenReturn(0.0);
  when(() => vm.grossSalesForMonth(any())).thenReturn(0.0);
  when(() => vm.netEarningsForMonth(any())).thenReturn(0.0);
  when(() => vm.materialById(any())).thenReturn(null);
  when(() => vm.fetchMaterialById(any())).thenAnswer((_) async => null);
  when(() => vm.companyNameFor(any())).thenReturn('Acme Builders');
  when(() => vm.directoryActionFor(any())).thenReturn('Send Request');
  when(() => vm.interestCategoriesFor(any())).thenReturn(const ['Cement']);
  when(() => vm.partnershipStatusFor(any())).thenReturn('Not Requested');
  when(() => vm.partnershipRejectionReasonFor(any())).thenReturn(null);
  when(() => vm.canReapplyToCompany(any())).thenReturn(true);
  when(() => vm.pastRequestStatusLabel(any())).thenReturn('Declined by Them');
  when(
    () => vm.partnerStatsFor(any()),
  ).thenReturn(const PartnerCompanyStats());
  when(() => vm.updateAuth(any())).thenReturn(null);
  when(() => vm.retryInitialLoad()).thenAnswer((_) async {});
  when(() => vm.loadDashboard()).thenAnswer((_) async {});
  when(() => vm.loadProfile()).thenAnswer((_) async {});
  when(() => vm.loadMaterials(any())).thenAnswer((_) async {});
  when(() => vm.loadOrders(any(), any())).thenAnswer((_) async {});
  when(() => vm.acceptOrder(any(), any())).thenAnswer((_) async {});
  when(() => vm.rejectOrder(any(), any(), any())).thenAnswer((_) async {});
  when(() => vm.markDelivered(any(), any())).thenAnswer((_) async {});
  when(() => vm.loadRatings(any(), any())).thenAnswer((_) async {});
  when(() => vm.loadEarnings(any())).thenAnswer((_) async {});
  when(() => vm.changeMonth(any())).thenAnswer((_) async {});
  when(() => vm.loadCompanyDirectory()).thenAnswer((_) async {});
  when(() => vm.searchCompanies(any())).thenAnswer((_) async {});
  when(() => vm.filterCompanyDirectoryByCity(any())).thenReturn(null);
  when(
    () => vm.sendPartnershipRequest(any(), message: any(named: 'message')),
  ).thenAnswer((_) async => true);
  when(() => vm.acceptPartnershipRequest(any())).thenAnswer(
    (_) async => 'Acme Builders',
  );
  when(
    () => vm.rejectPartnershipRequest(any(), any()),
  ).thenAnswer((_) async => true);
  when(() => vm.withdrawPartnershipRequest(any())).thenAnswer((_) async {});
  when(() => vm.removePartnership(any())).thenAnswer((_) async => 'Acme Builders');
  when(() => vm.loadPartnershipHubData()).thenAnswer((_) async {});
  when(vm.ensurePartnershipStatusWatch).thenReturn(null);
  when(() => vm.submitAppeal(any(), any(), any())).thenAnswer((_) async {});
  when(vm.streamOpenRfqsForSupplier).thenAnswer(
    (_) => Stream<List<RfqModel>>.value(const []),
  );
  when(
    () => vm.submitRfqBid(
      rfqId: any(named: 'rfqId'),
      bidPrice: any(named: 'bidPrice'),
      deliveryTime: any(named: 'deliveryTime'),
      note: any(named: 'note'),
    ),
  ).thenAnswer((_) async {});
  when(() => vm.withdrawRfqBid(rfqId: any(named: 'rfqId')))
      .thenAnswer((_) async {});
  when(() => vm.deleteMaterial(any(), any())).thenAnswer((_) async {});
  when(() => vm.getMyBid(any())).thenAnswer((_) async => null);
  when(() => vm.updateProfile(any())).thenAnswer((_) async {});
  when(() => vm.switchCompany(any())).thenReturn(null);
  when(() => vm.openCompanyContext(any())).thenReturn(null);
}

void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

bool _isIgnorableSupplierTestErrorText(String text) {
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
    if (!_isIgnorableSupplierTestErrorText(error.toString())) {
      fail('Unexpected exception during supplier widget test: $error');
    }
  }
}

void ignoreKnownSupplierTestErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (_isIgnorableSupplierTestErrorText(text) ||
        _isIgnorableSupplierTestErrorText('${details.context}')) {
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

Finder textFieldByLabel(String label) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.labelText == label,
    ),
    matching: find.byType(EditableText),
  );
}

void registerSupplierWidgetFallbacks() {
  Provider.debugCheckInvalidValueType = null;
  registerFallbackValue('');
  registerFallbackValue(0);
  registerFallbackValue(0.0);
  registerFallbackValue(false);
  registerFallbackValue(DateTime.utc(2026, 5, 1));
  registerFallbackValue(<String>[]);
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(File('dummy'));
  registerFallbackValue(XFile('dummy.jpg'));
  registerFallbackValue(sampleCompany());
  registerFallbackValue(sampleMaterial());
  registerFallbackValue(sampleOrder());
  registerFallbackValue(sampleRfq());
  registerFallbackValue(sampleBid());
  registerFallbackValue(sampleThread());
  registerFallbackValue(sampleMessage());
  registerFallbackValue(sampleRating());
  registerFallbackValue(samplePartnershipRequest());
  registerFallbackValue(MockAuthViewModel());
}

Future<void> pumpSupplierScreen(
  WidgetTester tester, {
  required Widget child,
  required MockSupplierViewModel supplier,
  MockAuthViewModel? auth,
  MockNotificationViewModel? notifications,
  MockChatViewModel? chat,
  MockMaterialViewModel? material,
  MockChatRepository? chatRepo,
  MockUserRepository? users,
  MockNotificationService? notificationService,
  MockDisputeViewModel? dispute,
  bool pumpPostFrame = true,
  Size surfaceSize = const Size(1200, 8000),
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  Provider.debugCheckInvalidValueType = null;
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  ignoreKnownSupplierTestErrors();

  final authVm = auth ?? MockAuthViewModel();
  if (auth == null) stubAuthViewModel(authVm);

  final notifVm = notifications ?? MockNotificationViewModel();
  if (notifications == null) stubNotificationViewModel(notifVm);

  final chatVm = chat ?? MockChatViewModel();
  if (chat == null) stubChatViewModel(chatVm);

  final materialVm = material ?? MockMaterialViewModel();
  if (material == null) stubMaterialViewModel(materialVm);

  final chatRepository = chatRepo ?? MockChatRepository();
  if (chatRepo == null) stubChatRepository(chatRepository);

  final userRepo = users ?? MockUserRepository();
  if (users == null) stubUserRepository(userRepo);

  final notifService = notificationService ?? MockNotificationService();
  if (notificationService == null) stubNotificationService(notifService);

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
            builder: (_, __) => SupplierTheme.wrap(child),
          ),
        ],
      ),
      GoRoute(path: RouteNames.login, builder: (_, __) => stub('login-screen')),
      GoRoute(
        path: RouteNames.roleSelection,
        builder: (_, __) => stub('role-selection'),
      ),
      GoRoute(
        path: RouteNames.supplierDashboard,
        builder: (_, __) => stub('supplier-dashboard'),
      ),
      GoRoute(
        path: RouteNames.supplierPending,
        builder: (_, __) => stub('supplier-pending'),
      ),
      GoRoute(
        path: RouteNames.supplierAppeal,
        builder: (_, __) => stub('supplier-appeal'),
      ),
      GoRoute(
        path: RouteNames.supplierMaterials,
        builder: (_, __) => stub('supplier-materials'),
      ),
      GoRoute(
        path: RouteNames.supplierAddMaterial,
        builder: (_, __) => stub('supplier-add-material'),
      ),
      GoRoute(
        path: RouteNames.supplierEditMaterial,
        builder: (_, __) => stub('supplier-edit-material'),
      ),
      GoRoute(
        path: RouteNames.supplierOrders,
        builder: (_, __) => stub('supplier-orders'),
      ),
      GoRoute(
        path: RouteNames.supplierRfqs,
        builder: (_, __) => stub('supplier-rfqs'),
      ),
      GoRoute(
        path: RouteNames.supplierSubmitBid,
        builder: (_, __) => stub('supplier-submit-bid'),
      ),
      GoRoute(
        path: RouteNames.supplierChat,
        builder: (_, __) => stub('supplier-chat'),
      ),
      GoRoute(
        path: RouteNames.supplierChatThread,
        builder: (_, __) => stub('supplier-chat-thread'),
      ),
      GoRoute(
        path: RouteNames.supplierRatings,
        builder: (_, __) => stub('supplier-ratings'),
      ),
      GoRoute(
        path: RouteNames.supplierEarnings,
        builder: (_, __) => stub('supplier-earnings'),
      ),
      GoRoute(
        path: RouteNames.supplierProfile,
        builder: (_, __) => stub('supplier-profile'),
      ),
      GoRoute(
        path: RouteNames.supplierNotifications,
        builder: (_, __) => stub('supplier-notifications'),
      ),
      GoRoute(
        path: RouteNames.supplierCompanyDirectory,
        builder: (_, __) => stub('supplier-directory'),
      ),
      GoRoute(
        path: RouteNames.supplierPartnershipRequests,
        builder: (_, __) => stub('supplier-partnerships'),
      ),
      GoRoute(
        path: RouteNames.supplierMyCompanies,
        builder: (_, __) => stub('supplier-my-companies'),
      ),
      GoRoute(
        path: RouteNames.supplierMyDisputes,
        builder: (_, __) => stub('supplier-my-disputes'),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthViewModel>.value(value: authVm),
        Provider<SupplierViewModel>.value(value: supplier),
        Provider<NotificationViewModel>.value(value: notifVm),
        Provider<ChatViewModel>.value(value: chatVm),
        Provider<MaterialViewModel>.value(value: materialVm),
        Provider<ChatRepository>.value(value: chatRepository),
        Provider<UserRepository>.value(value: userRepo),
        Provider<NotificationService>.value(value: notifService),
        Provider<DisputeViewModel>.value(value: disputeVm),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (pumpPostFrame) {
    await tester.pump();
  }
  drainIgnorableExceptions(tester);
}
