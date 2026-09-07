import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ratebridge/constants/route_names.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/dispute_model.dart';
import 'package:ratebridge/models/notification_model.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/models/partnership_request_model.dart';
import 'package:ratebridge/models/rfq_bid_model.dart';
import 'package:ratebridge/models/rfq_model.dart';
import 'package:ratebridge/models/subscription_model.dart';
import 'package:ratebridge/models/supplier_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/repositories/user_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';
import 'package:ratebridge/theme/ceo_theme.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/ceo_viewmodel.dart';
import 'package:ratebridge/viewmodels/dispute_viewmodel.dart';
import 'package:ratebridge/viewmodels/notification_viewmodel.dart';
import 'package:ratebridge/viewmodels/rfq_viewmodel.dart';
import 'package:ratebridge/viewmodels/subscription_viewmodel.dart';

import '../../mocks/mocks.dart';

UserModel ceoUser({
  String status = 'active',
  String? rejectionReason,
}) {
  return UserModel(
    uid: 'ceo-1',
    email: 'ceo@acme.test',
    name: 'Ali CEO',
    role: 'CEO',
    companyId: 'co-1',
    phone: '03001234567',
    city: 'Lahore',
    status: status,
    rejectionReason: rejectionReason,
    createdAt: DateTime.utc(2026, 1, 15),
  );
}

UserModel sampleFieldUser({
  String uid = 'field-1',
  String name = 'Hassan Field',
  String status = 'pending',
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
  String inviteCode = 'RB-ACME01',
  String plan = 'free',
  String status = 'active',
}) {
  return CompanyModel(
    id: id,
    name: name,
    registrationNumber: 'NTN-1',
    address: 'Lahore',
    city: 'Lahore',
    phone: '03001111111',
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    inviteCode: inviteCode,
    inviteCodeGeneratedAt: DateTime.utc(2026, 9, 7, 7, 0),
    plan: plan,
    ceoUid: 'ceo-1',
    ceoFullName: 'Ali CEO',
    designation: 'CEO',
    companyType: 'Private Limited',
    estimatedMonthlyVolume: 'PKR 2M',
    activeSitesCount: 4,
    autoApprovalThreshold: 25000,
  );
}

SupplierModel sampleSupplier({
  String id = 'sup-1',
  String name = 'Skyline Materials',
  String city = 'Karachi',
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
    city: city,
    isVerified: true,
    categories: const ['Cement'],
  );
}

OrderModel sampleOrder({
  String id = 'order-001',
  String status = 'pending',
  String materialName = 'Lucky Cement',
  double totalAmount = 62500,
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
    totalAmount: totalAmount,
    deliveryAddress: 'Site A, Lahore',
    status: status,
    createdAt: DateTime.utc(2026, 4, 1),
    updatedAt: DateTime.utc(2026, 4, 1),
  );
}

PartnershipRequestModel samplePartnershipRequest({
  String id = 'req-1',
  String status = 'pending',
  String initiatedBy = 'supplier',
  String supplierName = 'Skyline Materials',
}) {
  return PartnershipRequestModel(
    requestId: id,
    companyId: 'co-1',
    companyName: 'Acme Builders',
    supplierId: 'sup-1',
    supplierName: supplierName,
    initiatedBy: initiatedBy,
    status: status,
    message: 'We would like to partner.',
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

DisputeModel sampleDispute({
  String id = 'd-1',
  String status = 'open',
}) {
  return DisputeModel(
    id: id,
    orderId: 'order-001',
    supplierId: 'sup-1',
    companyId: 'co-1',
    raisedByUid: 'field-1',
    raisedByRole: 'field_user',
    raisedByName: 'Hassan Field',
    type: DisputeType.wrongMaterial,
    description: 'Bags arrived wet.',
    status: status,
    createdAt: DateTime.utc(2026, 4, 1),
    updatedAt: DateTime.utc(2026, 4, 1),
  );
}

NotificationModel sampleNotification({
  String id = 'n-1',
  bool isRead = false,
  String type = 'system',
  String title = 'New join request',
  String message = 'Skyline Materials wants to partner.',
  Map<String, dynamic> data = const {},
}) {
  return NotificationModel(
    notifId: id,
    recipientUserId: 'ceo-1',
    recipientRole: 'CEO',
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
    supplierName: 'Cement House',
    bidPrice: bidPrice,
    estimatedDeliveryTime: '3 days',
    note: 'Ready stock',
    createdAt: DateTime.utc(2026, 4, 2),
  );
}

SubscriptionModel sampleSubscription({
  String plan = 'basic',
  String status = 'active',
}) {
  return SubscriptionModel(
    companyId: 'co-1',
    plan: plan,
    status: status,
    startedAt: DateTime.utc(2026, 3, 1),
    expiresAt: DateTime.utc(2026, 12, 1),
  );
}

Map<String, dynamic> sampleLinkedSupplier({
  String id = 'sup-1',
  String name = 'Skyline Materials',
  String city = 'Karachi',
  String status = 'active',
}) {
  return {
    'id': id,
    'name': name,
    'city': city,
    'materialType': 'Cement',
    'status': status,
    'rating': 4.5,
  };
}

void stubAuthViewModel(MockAuthViewModel auth, {UserModel? user}) {
  final current = user ?? ceoUser();
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
  when(() => notif.uid).thenReturn('ceo-1');
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

void stubCeoViewModel(
  MockCeoViewModel ceo, {
  CompanyModel? company,
  bool isLoading = false,
}) {
  when(() => ceo.uid).thenReturn('ceo-1');
  when(() => ceo.name).thenReturn('Ali CEO');
  when(() => ceo.isLoading).thenReturn(isLoading);
  when(() => ceo.errorMessage).thenReturn(null);
  when(() => ceo.successMessage).thenReturn(null);
  when(() => ceo.company).thenReturn(company ?? sampleCompany());
  when(() => ceo.marketplaceSuppliers).thenReturn(const []);
  when(() => ceo.partnershipRequestsReady).thenReturn(true);
  when(() => ceo.receivedPartnershipRequests).thenReturn(const []);
  when(() => ceo.sentPartnershipRequests).thenReturn(const []);
  when(() => ceo.pendingReceivedPartnershipRequests).thenReturn(const []);
  when(() => ceo.pendingSentPartnershipRequests).thenReturn(const []);
  when(() => ceo.linkStatusFor(any())).thenReturn('Not Invited');
  when(() => ceo.linkRejectionReasonFor(any())).thenReturn(null);
  when(() => ceo.loadDashboard()).thenAnswer((_) async {});
  when(() => ceo.loadMarketplace()).thenAnswer((_) async {});
  when(() => ceo.loadCompanyProfile()).thenAnswer((_) async {});
  when(() => ceo.regenerateInviteCode()).thenAnswer((_) async {});
  when(ceo.clearMessages).thenReturn(null);
  when(() => ceo.ensurePartnershipStatusWatch(any())).thenReturn(null);
  when(() => ceo.searchSuppliers(any())).thenAnswer((_) async {});
  when(
    () => ceo.applyFilters(
      city: any(named: 'city'),
      category: any(named: 'category'),
      verifiedOnly: any(named: 'verifiedOnly'),
    ),
  ).thenAnswer((_) async {});
  when(() => ceo.sortSuppliers(any())).thenAnswer((_) async {});
  when(
    () => ceo.sendPartnershipRequest(any(), message: any(named: 'message')),
  ).thenAnswer((_) async {});
  when(() => ceo.acceptPartnershipRequest(any())).thenAnswer((_) async {});
  when(() => ceo.rejectPartnershipRequest(any(), any()))
      .thenAnswer((_) async {});
  when(() => ceo.withdrawPartnershipRequest(any())).thenAnswer((_) async {});
  when(() => ceo.updateCompanyProfile(any())).thenAnswer((_) async {});
  when(() => ceo.approveFieldUser(any())).thenAnswer((_) async {});
  when(() => ceo.rejectFieldUser(any(), any())).thenAnswer((_) async {});
  when(() => ceo.deactivateFieldUser(any())).thenAnswer((_) async {});
  when(() => ceo.reactivateFieldUser(any())).thenAnswer((_) async {});
  when(() => ceo.approveOrder(any())).thenAnswer((_) async {});
  when(() => ceo.rejectOrder(any(), reason: any(named: 'reason')))
      .thenAnswer((_) async {});
  when(() => ceo.cancelOrder(any(), any())).thenAnswer((_) async {});
  when(() => ceo.removeSupplier(any())).thenAnswer((_) async {});
  when(() => ceo.toggleSupplierStatus(any(), any(), any()))
      .thenAnswer((_) async {});
  when(() => ceo.watchCeoStatus())
      .thenAnswer((_) => Stream<UserModel?>.value(ceoUser()));
  when(() => ceo.watchDashboardStats(any())).thenAnswer(
    (_) => Stream<Map<String, dynamic>>.value(const {}),
  );
  when(() => ceo.watchCompanyOrders(any(), any())).thenAnswer(
    (_) => Stream<List<OrderModel>>.value(const []),
  );
  when(() => ceo.watchMySuppliers(any())).thenAnswer(
    (_) => Stream<List<Map<String, dynamic>>>.value(const []),
  );
  when(() => ceo.watchFieldUsers(any(), any())).thenAnswer(
    (_) => Stream<List<UserModel>>.value(const []),
  );
}

void stubDisputeViewModel(MockDisputeViewModel dispute) {
  when(() => dispute.isLoading).thenReturn(false);
  when(() => dispute.error).thenReturn(null);
  when(() => dispute.watchCompanyDisputes(any()))
      .thenAnswer((_) => Stream<List<DisputeModel>>.value(const []));
  when(() => dispute.watchAllDisputes(status: any(named: 'status')))
      .thenAnswer((_) => Stream<List<DisputeModel>>.value(const []));
  when(() => dispute.watchMyDisputes(any()))
      .thenAnswer((_) => Stream<List<DisputeModel>>.value(const []));
  when(() => dispute.watchDispute(any()))
      .thenAnswer((_) => Stream<DisputeModel?>.value(null));
  when(
    () => dispute.withdrawDispute(
      uid: any(named: 'uid'),
      disputeId: any(named: 'disputeId'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => dispute.resolveDispute(
      any(),
      any(),
      any(),
      adminUid: any(named: 'adminUid'),
      raisedByUid: any(named: 'raisedByUid'),
      raisedByRole: any(named: 'raisedByRole'),
      orderId: any(named: 'orderId'),
      companyId: any(named: 'companyId'),
    ),
  ).thenAnswer((_) async {});
}

void stubRfqViewModel(MockRfqViewModel rfq) {
  when(() => rfq.isLoading).thenReturn(false);
  when(() => rfq.error).thenReturn(null);
  when(rfq.clearError).thenReturn(null);
  when(() => rfq.watchCompanyRfqs(any()))
      .thenAnswer((_) => Stream<List<RfqModel>>.value(const []));
  when(() => rfq.watchRfq(any()))
      .thenAnswer((_) => Stream<RfqModel?>.value(null));
  when(() => rfq.watchRfqBids(any()))
      .thenAnswer((_) => Stream<List<RfqBidModel>>.value(const []));
  when(
    () => rfq.createRfq(
      uid: any(named: 'uid'),
      companyId: any(named: 'companyId'),
      companyName: any(named: 'companyName'),
      category: any(named: 'category'),
      materialDescription: any(named: 'materialDescription'),
      quantity: any(named: 'quantity'),
      unit: any(named: 'unit'),
      city: any(named: 'city'),
      requiredByDate: any(named: 'requiredByDate'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => rfq.awardRfq(
      rfq: any(named: 'rfq'),
      bid: any(named: 'bid'),
      ceoUid: any(named: 'ceoUid'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => rfq.cancelRfq(
      rfqId: any(named: 'rfqId'),
      uid: any(named: 'uid'),
    ),
  ).thenAnswer((_) async {});
}

void stubSubscriptionViewModel(MockSubscriptionViewModel sub) {
  when(() => sub.isLoading).thenReturn(false);
  when(() => sub.error).thenReturn(null);
  when(() => sub.successMessage).thenReturn(null);
  when(() => sub.currentSubscription).thenReturn(null);
  when(() => sub.history).thenReturn(const []);
  when(() => sub.pendingPayment).thenReturn(null);
  when(() => sub.isWaitingVerification).thenReturn(false);
  when(() => sub.hasPendingPayment).thenReturn(false);
  when(sub.clearMessages).thenReturn(null);
  when(() => sub.loadSubscription(any())).thenAnswer((_) async {});
  when(() => sub.cancelSubscription(any())).thenAnswer((_) async {});
}

void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

bool _isIgnorableCeoTestErrorText(String text) {
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
    if (!_isIgnorableCeoTestErrorText(error.toString())) {
      fail('Unexpected exception during CEO widget test: $error');
    }
  }
}

void ignoreKnownCeoTestErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (_isIgnorableCeoTestErrorText(text) ||
        _isIgnorableCeoTestErrorText('${details.context}')) {
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

void registerCeoWidgetFallbacks() {
  Provider.debugCheckInvalidValueType = null;
  registerFallbackValue('');
  registerFallbackValue(0);
  registerFallbackValue(0.0);
  registerFallbackValue(false);
  registerFallbackValue(DateTime.utc(2026, 5, 1));
  registerFallbackValue(<String>[]);
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(sampleCompany());
  registerFallbackValue(sampleSupplier());
  registerFallbackValue(sampleOrder());
  registerFallbackValue(sampleRfq());
  registerFallbackValue(sampleBid());
  registerFallbackValue(kPlans[1]);
}

Future<void> pumpCeoScreen(
  WidgetTester tester, {
  required Widget child,
  required MockCeoViewModel ceo,
  MockAuthViewModel? auth,
  MockNotificationViewModel? notifications,
  MockDisputeViewModel? dispute,
  MockSubscriptionViewModel? subscription,
  MockRfqViewModel? rfq,
  MockFirestoreService? firestore,
  MockUserRepository? users,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  Provider.debugCheckInvalidValueType = null;
  useLargeSurface(tester);
  ignoreKnownCeoTestErrors();

  final authVm = auth ?? MockAuthViewModel();
  if (auth == null) stubAuthViewModel(authVm);

  final notifVm = notifications ?? MockNotificationViewModel();
  if (notifications == null) stubNotificationViewModel(notifVm);

  final disputeVm = dispute ?? MockDisputeViewModel();
  if (dispute == null) stubDisputeViewModel(disputeVm);

  final subVm = subscription ?? MockSubscriptionViewModel();
  if (subscription == null) stubSubscriptionViewModel(subVm);

  final rfqVm = rfq ?? MockRfqViewModel();
  if (rfq == null) stubRfqViewModel(rfqVm);

  final firestoreService = firestore ?? MockFirestoreService();
  if (firestore == null) {
    when(
      () => firestoreService.getSupplierStats(
        any(),
        companyId: any(named: 'companyId'),
      ),
    ).thenAnswer((_) async => {'totalFulfilled': 0, 'onTimeRate': 0.0});
    when(
      () => firestoreService.getSupplierDisputeCount(
        any(),
        companyId: any(named: 'companyId'),
      ),
    ).thenAnswer((_) async => 0);
    when(() => firestoreService.streamSupplierRating(any()))
        .thenAnswer((_) => Stream<double>.value(4.5));
  }

  final userRepo = users ?? MockUserRepository();
  if (users == null) {
    when(() => userRepo.updateUserDoc(any(), any())).thenAnswer((_) async {});
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
            builder: (_, __) => CeoTheme.wrap(child),
          ),
        ],
      ),
      GoRoute(path: RouteNames.login, builder: (_, __) => stub('login-screen')),
      GoRoute(
        path: RouteNames.ceoDashboard,
        builder: (_, __) => stub('ceo-dashboard'),
      ),
      GoRoute(
        path: RouteNames.ceoMySuppliers,
        builder: (_, __) => stub('ceo-suppliers'),
      ),
      GoRoute(
        path: RouteNames.ceoInvite,
        builder: (_, __) => stub('ceo-invite'),
      ),
      GoRoute(
        path: RouteNames.ceoFieldUsers,
        builder: (_, __) => stub('ceo-field-users'),
      ),
      GoRoute(
        path: RouteNames.ceoOrders,
        builder: (_, __) => stub('ceo-orders'),
      ),
      GoRoute(
        path: RouteNames.ceoProfile,
        builder: (_, __) => stub('ceo-profile'),
      ),
      GoRoute(
        path: RouteNames.ceoSubscription,
        builder: (_, __) => stub('ceo-subscription'),
      ),
      GoRoute(
        path: RouteNames.ceoNotifications,
        builder: (_, __) => stub('ceo-notifications'),
      ),
      GoRoute(
        path: RouteNames.ceoRfqs,
        builder: (_, __) => stub('ceo-rfqs'),
      ),
      GoRoute(
        path: RouteNames.ceoCreateRfq,
        builder: (_, __) => stub('ceo-create-rfq'),
      ),
      GoRoute(
        path: RouteNames.ceoRfqDetail,
        builder: (_, __) => stub('ceo-rfq-detail'),
      ),
      GoRoute(
        path: RouteNames.ceoDisputes,
        builder: (_, __) => stub('ceo-disputes'),
      ),
      GoRoute(
        path: RouteNames.ceoDisputeDetail,
        builder: (_, __) => stub('ceo-dispute-detail'),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthViewModel>.value(value: authVm),
        Provider<CeoViewModel>.value(value: ceo),
        Provider<NotificationViewModel>.value(value: notifVm),
        Provider<DisputeViewModel>.value(value: disputeVm),
        Provider<SubscriptionViewModel>.value(value: subVm),
        Provider<RfqViewModel>.value(value: rfqVm),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<UserRepository>.value(value: userRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  drainIgnorableExceptions(tester);
}
