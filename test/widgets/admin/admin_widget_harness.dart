import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:ratebridge/constants/route_names.dart';
import 'package:ratebridge/models/audit_log_model.dart';
import 'package:ratebridge/models/category_model.dart';
import 'package:ratebridge/models/dispute_model.dart';
import 'package:ratebridge/models/notification_model.dart';
import 'package:ratebridge/models/payment_proof_model.dart';
import 'package:ratebridge/models/subscription_model.dart';
import 'package:ratebridge/models/transaction_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/repositories/transaction_repository.dart';
import 'package:ratebridge/repositories/user_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';
import 'package:ratebridge/theme/admin_theme.dart';
import 'package:ratebridge/viewmodels/admin_viewmodel.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/dispute_viewmodel.dart';
import 'package:ratebridge/viewmodels/notification_viewmodel.dart';
import 'package:ratebridge/viewmodels/subscription_viewmodel.dart';

import '../../mocks/mocks.dart';

UserModel adminUser() {
  return UserModel(
    uid: 'admin-1',
    email: 'admin@ratebridge.test',
    name: 'Platform Admin',
    role: 'Admin',
    companyId: '',
    phone: '03001111111',
    city: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

PaymentProofModel samplePayment({
  String id = 'pay-1',
  String type = 'subscription',
  String status = 'pending',
  String payerName = 'Ali CEO',
}) {
  return PaymentProofModel(
    id: id,
    payerId: 'ceo-1',
    companyId: 'co-1',
    payerName: payerName,
    payerRole: type == 'commission' ? 'Supplier' : 'CEO',
    amount: 1000,
    method: 'bank_transfer',
    screenshotUrl: '',
    status: status,
    type: type,
    planId: 'basic',
    planName: 'Basic',
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

CategoryModel sampleCategory({
  String id = 'cement',
  String name = 'Cement',
  bool isActive = true,
}) {
  return CategoryModel(
    id: id,
    name: name,
    unit: 'bag',
    brands: const ['Lucky'],
    grades: const ['OPC'],
    isActive: isActive,
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
    raisedByName: 'Ali Raza',
    type: DisputeType.wrongMaterial,
    description: 'Bags arrived wet.',
    status: status,
    createdAt: DateTime.utc(2026, 4, 1),
    updatedAt: DateTime.utc(2026, 4, 1),
  );
}

AuditLogModel sampleAuditLog() {
  return AuditLogModel(
    id: 'log-1',
    actorId: 'admin-1',
    actorName: 'Platform Admin',
    actionType: 'approve_ceo',
    targetType: 'ceo',
    targetId: 'ceo-1',
    description: 'Approved CEO Ali Khan',
    timestamp: DateTime.utc(2026, 4, 1, 10),
  );
}

NotificationModel sampleNotification({
  String id = 'n-1',
  bool isRead = false,
}) {
  return NotificationModel(
    notifId: id,
    recipientUserId: 'admin-1',
    recipientRole: 'Admin',
    type: 'system',
    title: 'New CEO pending',
    message: 'Acme Builders submitted a registration.',
    data: const {},
    isRead: isRead,
    createdAt: DateTime.utc(2026, 4, 1),
  );
}

void stubAuthViewModel(MockAuthViewModel auth, {UserModel? user}) {
  final current = user ?? adminUser();
  when(() => auth.user).thenReturn(current);
  when(() => auth.role).thenReturn(current.role);
  when(() => auth.isLoading).thenReturn(false);
  when(() => auth.errorMessage).thenReturn(null);
  when(() => auth.isAuthenticated).thenReturn(true);
  when(() => auth.signOut()).thenAnswer((_) async {});
  when(() => auth.logout()).thenAnswer((_) async {});
}

void stubNotificationViewModel(MockNotificationViewModel notif) {
  when(() => notif.uid).thenReturn('admin-1');
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

void stubAdminViewModel(MockAdminViewModel admin) {
  when(() => admin.isLoading).thenReturn(false);
  when(() => admin.pendingPayments).thenReturn(const []);
  when(() => admin.confirmedPayments).thenReturn(const []);
  when(() => admin.ceosList).thenReturn(const []);
  when(() => admin.suppliersList).thenReturn(const []);
  when(() => admin.companiesList).thenReturn(const []);
  when(() => admin.watchPendingUsersCount())
      .thenAnswer((_) => Stream<int>.value(0));
  when(() => admin.watchActiveUsersCount())
      .thenAnswer((_) => Stream<int>.value(0));
  when(() => admin.watchSuspendedUsersCount())
      .thenAnswer((_) => Stream<int>.value(0));
  when(() => admin.watchCategories())
      .thenAnswer((_) => Stream<List<CategoryModel>>.value(const []));
  when(() => admin.loadPaymentQueue()).thenAnswer((_) async {});
  when(() => admin.loadDashboardData()).thenAnswer((_) async {});
  when(() => admin.acceptCEO(any(), any())).thenAnswer((_) async {});
  when(() => admin.rejectCEO(any(), any(), any())).thenAnswer((_) async {});
  when(() => admin.suspendCEO(any(), any())).thenAnswer((_) async {});
  when(() => admin.activateCEO(any(), any())).thenAnswer((_) async {});
  when(() => admin.approveSupplier(any())).thenAnswer((_) async {});
  when(() => admin.rejectSupplier(any(), any())).thenAnswer((_) async {});
  when(() => admin.suspendSupplier(any())).thenAnswer((_) async {});
  when(() => admin.reactivateSupplier(any())).thenAnswer((_) async {});
  when(() => admin.deleteSupplierPermanently(any())).thenAnswer((_) async {});
  when(() => admin.confirmPayment(any())).thenAnswer((_) async {});
  when(() => admin.rejectPayment(any(), any())).thenAnswer((_) async {});
  when(() => admin.setCategoryActive(any(), any())).thenAnswer((_) async {});
  when(() => admin.addCategory(any(), any(), any(), any()))
      .thenAnswer((_) async {});
  when(() => admin.editCategory(any(), any(), any(), any(), any()))
      .thenAnswer((_) async {});
  when(() => admin.deleteCategory(any())).thenAnswer((_) async {});
}

void stubDisputeViewModel(MockDisputeViewModel dispute) {
  when(() => dispute.isLoading).thenReturn(false);
  when(() => dispute.error).thenReturn(null);
  when(() => dispute.watchAllDisputes(status: any(named: 'status')))
      .thenAnswer((_) => Stream<List<DisputeModel>>.value(const []));
  when(() => dispute.watchMyDisputes(any()))
      .thenAnswer((_) => Stream<List<DisputeModel>>.value(const []));
  when(() => dispute.watchDispute(any()))
      .thenAnswer((_) => Stream<DisputeModel?>.value(null));
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
  when(
    () => dispute.withdrawDispute(
      uid: any(named: 'uid'),
      disputeId: any(named: 'disputeId'),
    ),
  ).thenAnswer((_) async {});
}

void stubSubscriptionViewModel(MockSubscriptionViewModel sub) {
  when(() => sub.error).thenReturn(null);
  when(() => sub.successMessage).thenReturn(null);
  when(sub.clearMessages).thenReturn(null);
  when(
    () => sub.adminGrantPlan(
      companyId: any(named: 'companyId'),
      plan: any(named: 'plan'),
      note: any(named: 'note'),
    ),
  ).thenAnswer((_) async {});
}

void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

bool _isIgnorableAdminTestErrorText(String text) {
  return text.contains('ListTile background color') ||
      text.contains('NetworkImageLoadException') ||
      text.contains('HTTP request failed') ||
      text.contains('resolving an image codec') ||
      text.contains('Invalid image data') ||
      text.contains('Connection refused') ||
      text.contains('SocketException') ||
      text.contains('HandshakeException');
}

bool _isIgnorableAdminTestError(FlutterErrorDetails details) {
  return _isIgnorableAdminTestErrorText(details.exceptionAsString()) ||
      _isIgnorableAdminTestErrorText('${details.context}');
}

void drainIgnorableExceptions(WidgetTester tester) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    if (!_isIgnorableAdminTestErrorText(error.toString())) {
      fail('Unexpected exception during admin widget test: $error');
    }
  }
}

void ignoreKnownAdminTestErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_isIgnorableAdminTestError(details)) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void registerAdminWidgetFallbacks() {
  Provider.debugCheckInvalidValueType = null;
  registerFallbackValue('');
  registerFallbackValue(0);
  registerFallbackValue(0.0);
  registerFallbackValue(false);
  registerFallbackValue(<String>[]);
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(samplePayment());
  registerFallbackValue(kPlans[1]);
}

Future<void> pumpAdminScreen(
  WidgetTester tester, {
  required Widget child,
  required MockAdminViewModel admin,
  MockAuthViewModel? auth,
  MockNotificationViewModel? notifications,
  MockDisputeViewModel? dispute,
  MockSubscriptionViewModel? subscription,
  MockFirestoreService? firestore,
  MockTransactionRepository? transactions,
  MockUserRepository? users,
  bool wrapInScaffold = false,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  Provider.debugCheckInvalidValueType = null;
  useLargeSurface(tester);
  ignoreKnownAdminTestErrors();

  final authVm = auth ?? MockAuthViewModel();
  if (auth == null) stubAuthViewModel(authVm);

  final notifVm = notifications ?? MockNotificationViewModel();
  if (notifications == null) stubNotificationViewModel(notifVm);

  final disputeVm = dispute ?? MockDisputeViewModel();
  if (dispute == null) stubDisputeViewModel(disputeVm);

  final subVm = subscription ?? MockSubscriptionViewModel();
  if (subscription == null) stubSubscriptionViewModel(subVm);

  final firestoreService = firestore ?? MockFirestoreService();
  if (firestore == null) {
    when(() => firestoreService.streamAuditLogs())
        .thenAnswer((_) => Stream<List<AuditLogModel>>.value(const []));
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
  }

  final txRepo = transactions ?? MockTransactionRepository();
  if (transactions == null) {
    when(() => txRepo.watchCommissionLedger()).thenAnswer(
      (_) => Stream<CommissionLedgerSnapshot>.value(
        CommissionLedgerSnapshot.empty,
      ),
    );
  }

  final userRepo = users ?? MockUserRepository();
  if (users == null) {
    when(() => userRepo.updateUserDoc(any(), any())).thenAnswer((_) async {});
  }

  final page = wrapInScaffold ? Scaffold(body: child) : child;

  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('root-screen')),
        routes: [
          GoRoute(
            path: 'screen',
            builder: (_, __) => AdminTheme.wrap(page),
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.adminDisputes,
        builder: (_, __) => const Scaffold(body: Text('disputes-screen')),
      ),
      GoRoute(
        path: RouteNames.adminCategories,
        builder: (_, __) => const Scaffold(body: Text('categories-screen')),
      ),
      GoRoute(
        path: RouteNames.adminNotifications,
        builder: (_, __) => const Scaffold(body: Text('admin-notifications')),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, __) => const Scaffold(body: Text('login-screen')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthViewModel>.value(value: authVm),
        Provider<AdminViewModel>.value(value: admin),
        Provider<NotificationViewModel>.value(value: notifVm),
        Provider<DisputeViewModel>.value(value: disputeVm),
        Provider<SubscriptionViewModel>.value(value: subVm),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<TransactionRepository>.value(value: txRepo),
        Provider<UserRepository>.value(value: userRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  drainIgnorableExceptions(tester);
}
