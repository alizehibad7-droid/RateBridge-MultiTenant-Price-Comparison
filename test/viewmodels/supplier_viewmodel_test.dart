import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/constants/app_constants.dart';
import 'package:ratebridge/constants/firestore_paths.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/models/partnership_request_model.dart';
import 'package:ratebridge/models/rating_model.dart';
import 'package:ratebridge/models/transaction_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/supplier_viewmodel.dart';

import '../mocks/mocks.dart';

class MockAuthViewModel extends Mock implements AuthViewModel {}

class MockXFile extends Mock implements XFile {}

UserModel _user({
  String uid = 'sup-1',
  String status = 'active',
  String? rejectionReason,
}) {
  return UserModel(
    uid: uid,
    email: 'steel@co.test',
    name: 'Steel Co',
    role: 'Supplier',
    companyId: '',
    phone: '03001234567',
    city: 'Lahore',
    status: status,
    rejectionReason: rejectionReason,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

CompanyModel _company({
  String id = 'co-1',
  String name = 'Acme Builders',
  String city = 'Lahore',
  String status = 'active',
  String? companyType = 'Contractor',
}) {
  return CompanyModel(
    id: id,
    name: name,
    registrationNumber: 'REG-1',
    address: 'Site 1',
    city: city,
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    companyType: companyType,
  );
}

OrderModel _order({
  String orderId = 'order-1',
  String companyId = 'co-1',
  String status = 'pending',
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 4, 1);
  return OrderModel(
    orderId: orderId,
    companyId: companyId,
    fieldUserUid: 'field-1',
    supplierId: 'sup-1',
    materialId: 'mat-1',
    materialName: 'OPC Cement',
    supplierName: 'Steel Co',
    fieldUserName: 'Ali Raza',
    quantity: 10,
    unit: 'bag',
    unitPrice: 100,
    totalAmount: 1000,
    deliveryAddress: 'Lahore',
    status: status,
    createdAt: created,
    updatedAt: created,
  );
}

MaterialModel _material({String id = 'mat-1', double price = 1250}) {
  return MaterialModel(
    id: id,
    name: 'OPC Cement',
    category: 'Cement',
    pricePerUnit: price,
    unit: 'bag',
    specifications: '53',
    qualityGrade: 'OPC 53',
    supplierId: 'sup-1',
    supplierName: 'Steel Co',
    isCertified: true,
    originCity: 'Lahore',
    createdAt: DateTime.utc(2026, 3, 1),
  );
}

PartnershipRequestModel _request({
  String requestId = 'req-1',
  String companyId = 'co-1',
  String status = 'pending',
  String initiatedBy = 'ceo',
  DateTime? createdAt,
  DateTime? respondedAt,
  String? rejectionReason,
}) {
  return PartnershipRequestModel(
    requestId: requestId,
    companyId: companyId,
    companyName: 'Acme Builders',
    supplierId: 'sup-1',
    supplierName: 'Steel Co',
    initiatedBy: initiatedBy,
    status: status,
    rejectionReason: rejectionReason,
    createdAt: createdAt ?? DateTime.utc(2026, 4, 1),
    respondedAt: respondedAt,
  );
}

Future<void> _waitUntil(bool Function() test, {String because = 'timed out'}) async {
  for (var i = 0; i < 50; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail(because);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = _user();
  final company = _company();
  final order = _order();
  final material = _material();

  setUpAll(() {
    registerFallbackValue(user);
    registerFallbackValue(material);
    registerFallbackValue(order);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(0.0);
    registerFallbackValue('');
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

  late FakeFirebaseFirestore fake;
  late MockMaterialRepository materialRepo;
  late MockOrderRepository orderRepo;
  late MockTransactionRepository transactionRepo;
  late MockStorageService storageService;
  late MockPriceHistoryRepository priceHistoryRepo;
  late MockCloudFunctionService cloudFunctions;
  late MockUserRepository userRepo;
  late MockCompanyRepository companyRepo;
  late MockPartnershipRequestRepository partnershipRepo;
  late MockNotificationService notificationService;
  late MockAuthViewModel auth;
  late SupplierViewModel viewModel;
  late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> bidJobsSub;
  String? uploadResult;
  bool failRfqBidJobs = false;

  void stubDefaults() {
    when(() => userRepo.watchUserDoc(any())).thenAnswer(
      (_) => Stream<UserModel>.value(user),
    );
    when(() => userRepo.getUserDoc(any())).thenAnswer((_) async => user);
    when(() => userRepo.updateUserDoc(any(), any())).thenAnswer((_) async {});
    when(() => userRepo.cachedUser).thenReturn(user);
    when(() => companyRepo.getCompanyById(any())).thenAnswer((_) async => company);
    when(() => companyRepo.getAllCompanies()).thenAnswer((_) async => [company]);
    when(() => orderRepo.getOrdersForSupplier(any())).thenAnswer(
      (_) => Stream.value([order]),
    );
    when(() => orderRepo.updateStatus(any(), any(), any())).thenAnswer((_) async {});
    when(
      () => orderRepo.updateStatus(
        any(),
        any(),
        any(),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => orderRepo.updateStatus(
        any(),
        any(),
        any(),
        deliveredAt: any(named: 'deliveredAt'),
      ),
    ).thenAnswer((_) async {});
    when(() => transactionRepo.getMonthlyEarningsSummary(any(), any()))
        .thenAnswer((_) async => const []);
    when(
      () => transactionRepo.createUnsettledCommissionTransaction(
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        supplierUid: any(named: 'supplierUid'),
        totalAmount: any(named: 'totalAmount'),
        commissionAmount: any(named: 'commissionAmount'),
        supplierEarning: any(named: 'supplierEarning'),
      ),
    ).thenAnswer((_) async {});
    when(() => materialRepo.getMaterialById(any())).thenAnswer((_) async => material);
    when(() => materialRepo.removeMaterial(any())).thenAnswer((_) async {});
    when(
      () => materialRepo.recordInitialMaterialPrice(
        materialId: any(named: 'materialId'),
        price: any(named: 'price'),
        supplierUid: any(named: 'supplierUid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => materialRepo.archiveMaterialPriceChange(
        materialId: any(named: 'materialId'),
        previousPrice: any(named: 'previousPrice'),
        newPrice: any(named: 'newPrice'),
        supplierUid: any(named: 'supplierUid'),
      ),
    ).thenAnswer((_) async {});
    when(() => cloudFunctions.callFunction(any(), any()))
        .thenAnswer((_) async => null);
    when(
      () => notificationService.notifyOrderAccepted(
        fieldUserUid: any(named: 'fieldUserUid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        supplierName: any(named: 'supplierName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notificationService.notifyOrderRejected(
        fieldUserUid: any(named: 'fieldUserUid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        supplierName: any(named: 'supplierName'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notificationService.notifyOrderDelivered(
        fieldUserUid: any(named: 'fieldUserUid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        supplierName: any(named: 'supplierName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => partnershipRepo.createRequest(
        companyId: any(named: 'companyId'),
        companyName: any(named: 'companyName'),
        supplierId: any(named: 'supplierId'),
        supplierName: any(named: 'supplierName'),
        initiatedBy: any(named: 'initiatedBy'),
        message: any(named: 'message'),
        supplierEmail: any(named: 'supplierEmail'),
        supplierCity: any(named: 'supplierCity'),
        supplierCategories: any(named: 'supplierCategories'),
        supplierRating: any(named: 'supplierRating'),
      ),
    ).thenAnswer((_) async => 'req-1');
    when(() => partnershipRepo.acceptRequest(any())).thenAnswer((_) async {});
    when(() => partnershipRepo.rejectRequest(any(), any())).thenAnswer((_) async {});
    when(() => partnershipRepo.withdrawRequest(any())).thenAnswer((_) async {});
    when(
      () => partnershipRepo.removePartnership(
        companyId: any(named: 'companyId'),
        supplierId: any(named: 'supplierId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => storageService.uploadFile(
        path: any(named: 'path'),
        file: any(named: 'file'),
      ),
    ).thenAnswer((_) async => 'https://cdn/appeal.jpg');
  }

  SupplierViewModel createVm() {
    return SupplierViewModel(
      materialRepo,
      orderRepo,
      transactionRepo,
      storageService,
      priceHistoryRepo,
      cloudFunctions,
      userRepo,
      companyRepo,
      partnershipRepo,
      notificationService,
      firestore: fake,
      uploadImageBytes: ({
        required List<int> bytes,
        required String folder,
        String filename = 'upload.jpg',
      }) async =>
          uploadResult,
    );
  }

  Future<void> signIn() async {
    when(() => auth.user).thenReturn(user);
    viewModel.updateAuth(auth);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    fake = FakeFirebaseFirestore();
    materialRepo = MockMaterialRepository();
    orderRepo = MockOrderRepository();
    transactionRepo = MockTransactionRepository();
    storageService = MockStorageService();
    priceHistoryRepo = MockPriceHistoryRepository();
    cloudFunctions = MockCloudFunctionService();
    userRepo = MockUserRepository();
    companyRepo = MockCompanyRepository();
    partnershipRepo = MockPartnershipRequestRepository();
    notificationService = MockNotificationService();
    auth = MockAuthViewModel();
    uploadResult = 'https://cdn.example/proof.jpg';
    failRfqBidJobs = false;
    stubDefaults();
    bidJobsSub = fake.collection('rfq_bid_jobs').snapshots().listen((snap) {
      for (final doc in snap.docs) {
        if (doc.data()['status'] != 'pending') continue;
        if (failRfqBidJobs) {
          doc.reference.update({
            'status': 'error',
            'error': 'bid failed',
          });
        } else {
          doc.reference.update({'status': 'complete'});
        }
      }
    });
    viewModel = createVm();
  });

  tearDown(() async {
    await bidJobsSub.cancel();
    viewModel.dispose();
  });

  group('SupplierViewModel helpers', () {
    test('monthKey formats YYYY-MM', () {
      expect(
        SupplierViewModel.monthKey(DateTime.utc(2026, 9, 2)),
        '2026-09',
      );
    });

    test('materialById returns null for empty or unknown ids', () {
      expect(viewModel.materialById(''), isNull);
      expect(viewModel.materialById('mat-1'), isNull);
    });

    test('fetchMaterialById returns null for empty id without hitting repo', () async {
      expect(await viewModel.fetchMaterialById(''), isNull);
      verifyNever(() => materialRepo.getMaterialById(any()));
    });

    test('fetchMaterialById delegates to the repository', () async {
      expect(await viewModel.fetchMaterialById('mat-1'), same(material));
      verify(() => materialRepo.getMaterialById('mat-1')).called(1);
    });

    test('interestCategoriesFor uses companyType', () {
      expect(viewModel.interestCategoriesFor(company), ['Contractor']);
    });

    test('pastRequestStatusLabel maps removed and rejected states', () {
      expect(
        viewModel.pastRequestStatusLabel(_request(status: 'removed')),
        'Removed',
      );
      expect(
        viewModel.pastRequestStatusLabel(
          _request(status: 'rejected', initiatedBy: 'supplier'),
        ),
        'Declined by Them',
      );
      expect(
        viewModel.pastRequestStatusLabel(
          _request(status: 'rejected', initiatedBy: 'ceo'),
        ),
        'You Declined',
      );
    });

    test('companyNameFor is null until linked companies load', () {
      expect(viewModel.companyNameFor('co-1'), isNull);
    });
  });

  group('SupplierViewModel.updateAuth', () {
    test('loads the supplier session and profile', () async {
      await signIn();

      expect(viewModel.supplierUid, 'sup-1');
      expect(viewModel.profile?.name, 'Steel Co');
      expect(viewModel.status, 'active');
      verify(() => userRepo.watchUserDoc('sup-1')).called(1);
    });

    test('same uid updates profile without restarting session', () async {
      await signIn();
      clearInteractions(userRepo);
      when(() => auth.user).thenReturn(_user(status: 'pending'));

      viewModel.updateAuth(auth);

      expect(viewModel.status, 'pending');
      verifyNever(() => userRepo.watchUserDoc(any()));
    });

    test('null user clears supplier state', () async {
      await signIn();
      when(() => auth.user).thenReturn(null);

      viewModel.updateAuth(auth);

      expect(viewModel.supplierUid, isNull);
      expect(viewModel.companies, isEmpty);
      expect(viewModel.selectedCompanyId, isNull);
    });
  });

  group('SupplierViewModel notifications', () {
    test('saveNotificationPreferences fails when signed out', () async {
      expect(
        await viewModel.saveNotificationPreferences({'pushEnabled': false}),
        'Not signed in',
      );
    });

    test('saveNotificationPreferences success writes the user doc', () async {
      await signIn();
      final prefs = {'pushEnabled': false, 'newOrders': true};

      var savingOnFirst = false;
      var notifies = 0;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) savingOnFirst = viewModel.notificationPrefsSaving;
      });

      expect(await viewModel.saveNotificationPreferences(prefs), isNull);
      expect(savingOnFirst, isTrue);
      expect(viewModel.notificationPrefsSaving, isFalse);
      expect(viewModel.notificationPrefs['pushEnabled'], isFalse);
      verify(
        () => userRepo.updateUserDoc('sup-1', {'notificationPreferences': prefs}),
      ).called(1);
    });

    test('saveNotificationPreferences failure returns the error', () async {
      await signIn();
      when(() => userRepo.updateUserDoc(any(), any())).thenThrow(
        Exception('prefs write failed'),
      );

      expect(
        await viewModel.saveNotificationPreferences({'pushEnabled': true}),
        'Exception: prefs write failed',
      );
      expect(viewModel.notificationPrefsSaving, isFalse);
    });

    test('loadNotificationPreferences reads stored flags', () async {
      await fake.collection('users').doc('sup-1').set({
        'notificationPreferences': {'pushEnabled': false, 'newOrders': true},
      });
      await signIn();
      await viewModel.loadNotificationPreferences();

      expect(viewModel.notificationPrefsLoaded, isTrue);
      expect(viewModel.notificationPrefs['pushEnabled'], isFalse);
      expect(viewModel.notificationPrefs['newOrders'], isTrue);
    });
  });

  group('SupplierViewModel profile', () {
    test('loadProfile success stores the user', () async {
      await signIn();
      await viewModel.loadProfile();
      expect(viewModel.profile?.email, 'steel@co.test');
      verify(() => userRepo.getUserDoc('sup-1')).called(1);
    });

    test('updateProfile writes fields and refreshes from cache', () async {
      await signIn();
      await viewModel.updateProfile({'city': 'Karachi'});
      verify(() => userRepo.updateUserDoc('sup-1', {'city': 'Karachi'})).called(1);
    });
  });

  group('SupplierViewModel invitations', () {
    test('acceptInvitation success selects the company', () async {
      await signIn();
      await viewModel.acceptInvitation('invite-1', 'co-1');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.selectedCompanyId, 'co-1');
      expect(viewModel.error, isNull);
      verify(
        () => cloudFunctions.callFunction('onInviteAccepted', {
          'token': 'invite-1',
          'companyId': 'co-1',
          'supplierUid': 'sup-1',
        }),
      ).called(1);
    });

    test('acceptInvitation failure sets error', () async {
      await signIn();
      when(() => cloudFunctions.callFunction(any(), any())).thenThrow(
        Exception('invite failed'),
      );

      await viewModel.acceptInvitation('invite-1', 'co-1');

      expect(viewModel.error, 'Exception: invite failed');
      expect(viewModel.isLoading, isFalse);
    });

    test('rejectInvitation updates the invitation document', () async {
      await fake.collection('invitations').doc('invite-1').set({
        'status': 'pending',
        'supplierUid': 'sup-1',
        'companyId': 'co-1',
      });
      await signIn();
      await viewModel.rejectInvitation('invite-1');

      final snap = await fake.collection('invitations').doc('invite-1').get();
      expect(snap.data()?['status'], 'rejected');
    });
  });

  group('SupplierViewModel materials', () {
    test('addMaterial success writes both copies and records price', () async {
      await signIn();
      await viewModel.addMaterial(material, null, 'co-1');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      final root = await fake.collection('materials').doc('mat-1').get();
      final nested = await fake
          .collection('companies')
          .doc('co-1')
          .collection('materials')
          .doc('mat-1')
          .get();
      expect(root.exists, isTrue);
      expect(nested.exists, isTrue);
      verify(
        () => materialRepo.recordInitialMaterialPrice(
          materialId: 'mat-1',
          price: 1250,
          supplierUid: 'sup-1',
        ),
      ).called(1);
    });

    test('addMaterial failure sets error', () async {
      await signIn();
      when(
        () => materialRepo.recordInitialMaterialPrice(
          materialId: any(named: 'materialId'),
          price: any(named: 'price'),
          supplierUid: any(named: 'supplierUid'),
        ),
      ).thenThrow(Exception('price archive failed'));

      await viewModel.addMaterial(material, null, 'co-1');
      expect(viewModel.error, 'Exception: price archive failed');
      expect(viewModel.isLoading, isFalse);
    });

    test('updateMaterial archives a price change then updates both docs', () async {
      await fake.collection('materials').doc('mat-1').set({
        'pricePerUnit': 1250,
      });
      await fake
          .collection('companies')
          .doc('co-1')
          .collection('materials')
          .doc('mat-1')
          .set({'pricePerUnit': 1250});
      await signIn();

      await viewModel.updateMaterial(
        'mat-1',
        {'pricePerUnit': 1400, 'name': 'OPC Cement'},
        null,
        'co-1',
      );

      verify(
        () => materialRepo.archiveMaterialPriceChange(
          materialId: 'mat-1',
          previousPrice: 1250,
          newPrice: 1400,
          supplierUid: 'sup-1',
        ),
      ).called(1);
      expect(viewModel.error, isNull);
      final root = await fake.collection('materials').doc('mat-1').get();
      expect(root.data()?['pricePerUnit'], 1400);
    });

    test('deleteMaterial archives listing when no active orders', () async {
      await fake.collection('materials').doc('mat-1').set({'name': 'OPC Cement'});
      await fake
          .collection('companies')
          .doc('co-1')
          .collection('materials')
          .doc('mat-1')
          .set({'name': 'OPC Cement'});
      await signIn();

      await viewModel.deleteMaterial('mat-1', 'co-1');

      final root = await fake.collection('materials').doc('mat-1').get();
      expect(root.data()?['archived'], true);
      final nested = await fake
          .collection('companies')
          .doc('co-1')
          .collection('materials')
          .doc('mat-1')
          .get();
      expect(nested.data()?['archived'], true);
    });

    test('deleteMaterial blocks when active orders exist', () async {
      await fake.collection('orders').doc('o-1').set({
        'materialId': 'mat-1',
        'supplierId': 'sup-1',
        'status': 'accepted',
      });
      await signIn();

      expect(
        () => viewModel.deleteMaterial('mat-1', 'co-1'),
        throwsA(isA<AppException>()),
      );
    });

    test('loadMaterials emits supplier listings for the company', () async {
      await fake
          .collection('companies')
          .doc('co-1')
          .collection('materials')
          .doc('mat-1')
          .set(material.toMap());
      await signIn();
      await viewModel.loadMaterials('co-1');
      await _waitUntil(
        () => viewModel.materials.any((m) => m.id == 'mat-1'),
        because: 'materials stream did not emit',
      );
      expect(viewModel.materialById('mat-1')?.name, 'OPC Cement');
    });
  });

  group('SupplierViewModel orders', () {
    test('loadOrders filters the supplier stream by company', () async {
      await signIn();
      await viewModel.loadOrders('co-1', null);
      await _waitUntil(() => viewModel.orders.isNotEmpty);
      expect(viewModel.orders.single.orderId, 'order-1');
      verify(() => orderRepo.getOrdersForSupplier('sup-1')).called(1);
    });

    test('acceptOrder updates status and notifies the field user', () async {
      await signIn();
      await viewModel.loadOrders('co-1', null);
      await _waitUntil(() => viewModel.orders.isNotEmpty);

      await viewModel.acceptOrder('order-1', 'co-1');

      expect(viewModel.isLoading, isFalse);
      verify(() => orderRepo.updateStatus('order-1', 'co-1', 'accepted')).called(1);
      verify(
        () => notificationService.notifyOrderAccepted(
          fieldUserUid: 'field-1',
          orderId: 'order-1',
          companyId: 'co-1',
          materialName: 'OPC Cement',
          supplierName: 'Steel Co',
        ),
      ).called(1);
    });

    test('rejectOrder sends the reason to repo and notifications', () async {
      await signIn();
      await viewModel.loadOrders('co-1', null);
      await _waitUntil(() => viewModel.orders.isNotEmpty);

      await viewModel.rejectOrder('order-1', 'co-1', 'Out of stock');

      verify(
        () => orderRepo.updateStatus(
          'order-1',
          'co-1',
          'rejected',
          reason: 'Out of stock',
        ),
      ).called(1);
      verify(
        () => notificationService.notifyOrderRejected(
          fieldUserUid: 'field-1',
          orderId: 'order-1',
          companyId: 'co-1',
          materialName: 'OPC Cement',
          supplierName: 'Steel Co',
          reason: 'Out of stock',
        ),
      ).called(1);
    });

    test('markDelivered stamps deliveredAt', () async {
      await signIn();
      await viewModel.loadOrders('co-1', null);
      await _waitUntil(() => viewModel.orders.isNotEmpty);

      await viewModel.markDelivered('order-1', 'co-1');

      verify(
        () => orderRepo.updateStatus(
          'order-1',
          'co-1',
          'delivered',
          deliveredAt: any(named: 'deliveredAt'),
        ),
      ).called(1);
    });

    test('acceptOrder swallows errors and clears loading', () async {
      await signIn();
      when(() => orderRepo.updateStatus(any(), any(), any())).thenThrow(
        Exception('status failed'),
      );

      await viewModel.acceptOrder('missing', 'co-1');
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('SupplierViewModel earnings and directory', () {
    test('loadEarnings asks the transaction repo for a 6-month summary', () async {
      await signIn();
      const summary = [
        MonthlyEarning(
          month: '2026-04',
          gross: 1000,
          commission: 20,
          net: 980,
          orderCount: 1,
        ),
      ];
      when(() => transactionRepo.getMonthlyEarningsSummary('sup-1', 6))
          .thenAnswer((_) async => summary);

      await viewModel.loadEarnings('2026-04');
      await viewModel.changeMonth('2026-04');

      expect(viewModel.monthlyEarnings, summary);
      verify(() => transactionRepo.getMonthlyEarningsSummary('sup-1', 6))
          .called(2);
    });

    test('loadCompanyDirectory keeps only active companies', () async {
      when(() => companyRepo.getAllCompanies()).thenAnswer(
        (_) async => [
          company,
          _company(id: 'co-pending', name: 'Pending Co', status: 'pending'),
        ],
      );
      await signIn();
      await viewModel.loadCompanyDirectory();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.companyDirectory.map((c) => c.id), ['co-1']);
    });

    test('searchCompanies and city filter shrink the directory', () async {
      when(() => companyRepo.getAllCompanies()).thenAnswer(
        (_) async => [
          company,
          _company(id: 'co-khi', name: 'Karachi Cement', city: 'Karachi'),
        ],
      );
      await signIn();
      await viewModel.searchCompanies('Karachi');
      expect(viewModel.companyDirectory.single.id, 'co-khi');

      viewModel.filterCompanyDirectoryByCity('Lahore');
      expect(viewModel.companyDirectory, isEmpty);
    });
  });

  group('SupplierViewModel partnerships', () {
    test('sendPartnershipRequest success creates a supplier-initiated request',
        () async {
      await signIn();
      final ok = await viewModel.sendPartnershipRequest(
        'co-1',
        message: 'Let us supply steel',
      );

      expect(ok, isTrue);
      expect(viewModel.isLoading, isFalse);
      verify(
        () => partnershipRepo.createRequest(
          companyId: 'co-1',
          companyName: 'Acme Builders',
          supplierId: 'sup-1',
          supplierName: 'Steel Co',
          initiatedBy: 'supplier',
          message: 'Let us supply steel',
          supplierEmail: 'steel@co.test',
          supplierCity: 'Lahore',
          supplierCategories: <String>[],
          supplierRating: 0,
        ),
      ).called(1);
    });

    test('sendPartnershipRequest returns false when the company is missing',
        () async {
      await signIn();
      when(() => companyRepo.getCompanyById('missing')).thenAnswer((_) async => null);

      expect(await viewModel.sendPartnershipRequest('missing'), isFalse);
      verifyNever(
        () => partnershipRepo.createRequest(
          companyId: any(named: 'companyId'),
          companyName: any(named: 'companyName'),
          supplierId: any(named: 'supplierId'),
          supplierName: any(named: 'supplierName'),
          initiatedBy: any(named: 'initiatedBy'),
          message: any(named: 'message'),
          supplierEmail: any(named: 'supplierEmail'),
          supplierCity: any(named: 'supplierCity'),
          supplierCategories: any(named: 'supplierCategories'),
          supplierRating: any(named: 'supplierRating'),
        ),
      );
    });

    test('sendPartnershipRequest failure sets error', () async {
      await signIn();
      when(
        () => partnershipRepo.createRequest(
          companyId: any(named: 'companyId'),
          companyName: any(named: 'companyName'),
          supplierId: any(named: 'supplierId'),
          supplierName: any(named: 'supplierName'),
          initiatedBy: any(named: 'initiatedBy'),
          message: any(named: 'message'),
          supplierEmail: any(named: 'supplierEmail'),
          supplierCity: any(named: 'supplierCity'),
          supplierCategories: any(named: 'supplierCategories'),
          supplierRating: any(named: 'supplierRating'),
        ),
      ).thenThrow(Exception('already exists'));

      expect(await viewModel.sendPartnershipRequest('co-1', message: 'Hi'), isFalse);
      expect(viewModel.error, 'Exception: already exists');
    });

    test('acceptPartnershipRequest returns the company name', () async {
      await fake.collection(FirestorePaths.partnershipRequestsCol).doc('req-1').set({
        'companyId': 'co-1',
        'companyName': 'Acme Builders',
        'supplierId': 'sup-1',
        'supplierName': 'Steel Co',
        'initiatedBy': 'ceo',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });
      await signIn();
      viewModel.ensurePartnershipStatusWatch();
      await _waitUntil(() => viewModel.partnershipListsReady);

      expect(await viewModel.acceptPartnershipRequest('req-1'), 'Acme Builders');
      verify(() => partnershipRepo.acceptRequest('req-1')).called(1);
    });

    test('acceptPartnershipRequest failure returns null', () async {
      await signIn();
      when(() => partnershipRepo.acceptRequest(any())).thenThrow(
        Exception('accept failed'),
      );

      expect(await viewModel.acceptPartnershipRequest('req-1'), isNull);
      expect(viewModel.error, 'Exception: accept failed');
    });

    test('rejectPartnershipRequest success and failure', () async {
      await signIn();
      expect(await viewModel.rejectPartnershipRequest('req-1', 'Busy'), isTrue);
      verify(() => partnershipRepo.rejectRequest('req-1', 'Busy')).called(1);

      when(() => partnershipRepo.rejectRequest(any(), any())).thenThrow(
        Exception('reject failed'),
      );
      expect(await viewModel.rejectPartnershipRequest('req-1', 'Busy'), isFalse);
      expect(viewModel.error, 'Exception: reject failed');
    });

    test('withdrawPartnershipRequest calls the repository', () async {
      await signIn();
      await viewModel.withdrawPartnershipRequest('req-1');
      expect(viewModel.isLoading, isFalse);
      verify(() => partnershipRepo.withdrawRequest('req-1')).called(1);
    });

    test('removePartnership returns the company name', () async {
      await signIn();
      expect(await viewModel.removePartnership('co-1'), 'Acme Builders');
      verify(
        () => partnershipRepo.removePartnership(
          companyId: 'co-1',
          supplierId: 'sup-1',
        ),
      ).called(1);
    });

    test('partnershipStatusFor and directoryActionFor follow request state',
        () async {
      await fake.collection(FirestorePaths.partnershipRequestsCol).doc('req-1').set({
        'companyId': 'co-1',
        'companyName': 'Acme Builders',
        'supplierId': 'sup-1',
        'supplierName': 'Steel Co',
        'initiatedBy': 'supplier',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });
      await signIn();
      viewModel.ensurePartnershipStatusWatch();
      await _waitUntil(() => viewModel.partnershipListsReady);

      expect(viewModel.partnershipStatusFor('co-1'), 'Request Pending');
      expect(viewModel.directoryActionFor('co-1'), 'Pending');
      expect(viewModel.partnershipRejectionReasonFor('co-1'), isNull);
      expect(viewModel.canReapplyToCompany('co-1'), isFalse);
    });

    test('canReapplyToCompany is true 7 days after rejection', () async {
      final closed = DateTime.now().subtract(const Duration(days: 8));
      await fake.collection(FirestorePaths.partnershipRequestsCol).doc('req-1').set({
        'companyId': 'co-1',
        'companyName': 'Acme Builders',
        'supplierId': 'sup-1',
        'initiatedBy': 'supplier',
        'status': 'rejected',
        'rejectionReason': 'Not now',
        'createdAt': Timestamp.fromDate(closed),
        'respondedAt': Timestamp.fromDate(closed),
      });
      await signIn();
      viewModel.ensurePartnershipStatusWatch();
      await _waitUntil(() => viewModel.partnershipListsReady);

      expect(viewModel.canReapplyToCompany('co-1'), isTrue);
      expect(viewModel.partnershipRejectionReasonFor('co-1'), 'Not now');
      expect(viewModel.directoryActionFor('co-1'), 'Request Again');
    });
  });

  group('SupplierViewModel dashboard and RFQ', () {
    test('switchCompany and openCompanyContext select a company', () async {
      await signIn();
      viewModel.switchCompany('co-1');
      expect(viewModel.selectedCompanyId, 'co-1');
      expect(viewModel.isDashboardLoading, isTrue);

      viewModel.openCompanyContext('co-1');
      expect(viewModel.selectedCompanyId, 'co-1');

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(viewModel.isDashboardLoading, isFalse);
    });

    test('loadDashboard returns immediately without a company', () async {
      await viewModel.loadDashboard();
      expect(viewModel.isDashboardLoading, isFalse);
    });

    test('retryInitialLoad no-ops when signed out', () async {
      await viewModel.retryInitialLoad();
      expect(viewModel.supplierUid, isNull);
    });

    test('retryInitialLoad restarts session watches', () async {
      await signIn();
      await viewModel.retryInitialLoad();
      verify(() => userRepo.watchUserDoc('sup-1')).called(greaterThan(0));
    });

    test('submitRfqBid success sets a message', () async {
      await signIn();
      await viewModel.submitRfqBid(
        rfqId: 'rfq-1',
        bidPrice: 99,
        deliveryTime: '3 days',
        note: 'Ready',
      );

      expect(viewModel.successMessage, 'Bid submitted.');
      expect(viewModel.isLoading, isFalse);
      verifyNever(() => cloudFunctions.callFunction('submitRfqBid', any()));
      final jobs = await fake.collection('rfq_bid_jobs').get();
      expect(jobs.docs, hasLength(1));
      expect(jobs.docs.first.data()['rfqId'], 'rfq-1');
      expect(jobs.docs.first.data()['bidPrice'], 99);
    });

    test('submitRfqBid failure sets error', () async {
      failRfqBidJobs = true;
      await signIn();
      await viewModel.submitRfqBid(
        rfqId: 'rfq-1',
        bidPrice: 99,
        deliveryTime: '3 days',
      );
      expect(viewModel.error, 'bid failed');
    });

    test('getMyBid returns null when missing and a model when present', () async {
      await signIn();
      expect(await viewModel.getMyBid('rfq-1'), isNull);

      await fake.collection('rfqs').doc('rfq-1').collection('bids').doc('sup-1').set({
        'rfqId': 'rfq-1',
        'supplierId': 'sup-1',
        'supplierName': 'Steel Co',
        'bidPrice': 88,
        'estimatedDeliveryTime': '2 days',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });

      final bid = await viewModel.getMyBid('rfq-1');
      expect(bid?.bidPrice, 88);
    });

    test('streamOpenRfqsForSupplier emits open RFQs', () async {
      await fake.collection('rfqs').doc('rfq-1').set({
        'status': 'open',
        'companyName': 'Acme',
        'requiredByDate': Timestamp.fromDate(DateTime.utc(2026, 5, 1)),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });
      await signIn();

      final events = <List<dynamic>>[];
      final sub = viewModel.streamOpenRfqsForSupplier().listen(events.add);
      await _waitUntil(() => events.any((e) => e.isNotEmpty));
      expect(events.last.first.id, 'rfq-1');
      await sub.cancel();
    });

    test('streamOpenRfqsForSupplier is empty when signed out', () async {
      expect(await viewModel.streamOpenRfqsForSupplier().first, isEmpty);
    });
  });

  group('SupplierViewModel commission payment', () {
    test('rejects invalid amounts', () async {
      await signIn();
      final file = MockXFile();
      when(() => file.readAsBytes()).thenAnswer((_) async => Uint8List(1));

      expect(
        await viewModel.submitCommissionPayment(
          amount: 0,
          method: 'bank',
          screenshotFile: file,
        ),
        isFalse,
      );
      expect(viewModel.error, 'Invalid amount');
    });

    test('success uploads proof and writes payment_proofs', () async {
      await fake.collection('transactions').doc('tx-1').set({
        'supplierUid': 'sup-1',
        'orderId': 'order-1',
        'companyId': 'co-1',
        'totalAmount': 1000,
        'commissionAmount': 50,
        'supplierEarning': 950,
        'status': 'unsettled',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });
      await signIn();
      await _waitUntil(() => viewModel.commissionOwed > 0);

      final file = MockXFile();
      when(() => file.readAsBytes()).thenAnswer(
        (_) async => Uint8List.fromList([1, 2, 3]),
      );

      expect(
        await viewModel.submitCommissionPayment(
          amount: 50,
          method: 'bank',
          screenshotFile: file,
        ),
        isTrue,
      );
      expect(viewModel.successMessage, 'Payment submitted.');
      final proofs = await fake.collection('payment_proofs').get();
      expect(proofs.docs, hasLength(1));
      expect(proofs.docs.first.data()['amount'], 50);
      expect(proofs.docs.first.data()['type'], 'commission');
    });

    test('failure when upload returns null', () async {
      await fake.collection('transactions').doc('tx-1').set({
        'supplierUid': 'sup-1',
        'commissionAmount': 50,
        'status': 'unsettled',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });
      await signIn();
      await _waitUntil(() => viewModel.commissionOwed > 0);
      uploadResult = null;
      final file = MockXFile();
      when(() => file.readAsBytes()).thenAnswer((_) async => Uint8List(1));

      expect(
        await viewModel.submitCommissionPayment(
          amount: 10,
          method: 'bank',
          screenshotFile: file,
        ),
        isFalse,
      );
      expect(viewModel.error, 'Exception: Upload failed');
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('SupplierViewModel appeal', () {
    test('submitAppeal success without a file', () async {
      await signIn();
      await viewModel.submitAppeal('Please review', null, '03001112222');

      expect(viewModel.appealSubmitted, isTrue);
      expect(viewModel.isLoading, isFalse);
      final appeals = await fake.collection('appeals').get();
      expect(appeals.docs.single.data()['message'], 'Please review');
    });
  });

  group('SupplierViewModel aggregates', () {
    test('partnerStatsFor uses loaded hub data', () async {
      await fake.collection('orders').doc('order-1').set({
        'companyId': 'co-1',
        'supplierId': 'sup-1',
        'fieldUserUid': 'field-1',
        'materialId': 'mat-1',
        'materialName': 'OPC Cement',
        'supplierName': 'Steel Co',
        'fieldUserName': 'Ali',
        'quantity': 10,
        'unit': 'bag',
        'unitPrice': 100,
        'totalAmount': 1000,
        'deliveryAddress': 'Lahore',
        'status': 'confirmed',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });
      await fake.collection('transactions').doc('tx-1').set({
        'companyId': 'co-1',
        'supplierId': 'sup-1',
        'supplierUid': 'sup-1',
        'supplierEarning': 980,
        'commissionAmount': 20,
        'totalAmount': 1000,
        'status': 'unsettled',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });
      await fake.collection('ratings').doc('r-1').set({
        'orderId': 'order-1',
        'supplierUid': 'sup-1',
        'rating': 5,
        'userId': 'field-1',
        'userName': 'Ali',
        'materialId': 'mat-1',
        'materialName': 'OPC Cement',
        'comment': 'Good',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 2)),
      });
      await signIn();
      await viewModel.loadPartnershipHubData();

      final stats = viewModel.partnerStatsFor('co-1');
      expect(stats.totalOrders, 1);
      expect(stats.totalEarnings, 980);
      expect(stats.avgRating, 5);
      expect(viewModel.partnershipHubDataLoaded, isTrue);
    });

    test('netEarnings applies the commission rate to confirmed orders', () async {
      when(() => orderRepo.getOrdersForSupplier(any())).thenAnswer(
        (_) => Stream.value([_order(status: 'confirmed')]),
      );
      await signIn();
      await viewModel.loadOrders('co-1', null);
      await _waitUntil(() => viewModel.orders.isNotEmpty);

      expect(viewModel.totalEarnings, 1000);
      expect(viewModel.netEarnings, 1000 * (1 - AppConstants.commissionRate));
    });

    test('opening the supplier session queues a commission ensure job', () async {
      await signIn();
      await Future<void>.delayed(Duration.zero);
      final job =
          await fake.collection('commission_ensure_jobs').doc('sup-1').get();
      expect(job.exists, isTrue);
      expect(job.data()?['uid'], 'sup-1');
      expect(job.data()?['status'], 'pending');
    });

    test('backfills commission transactions for confirmed orders', () async {
      await fake.collection('orders').doc('order-99').set({
        'supplierId': 'sup-1',
        'companyId': 'co-1',
        'status': 'confirmed',
        'totalAmount': 5000,
      });
      await signIn();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      verify(
        () => transactionRepo.createUnsettledCommissionTransaction(
          orderId: 'order-99',
          companyId: 'co-1',
          supplierUid: 'sup-1',
          totalAmount: 5000,
          commissionAmount: 100,
          supplierEarning: 4900,
        ),
      ).called(1);
    });

    test('commission owed is generated commission minus settled proofs', () async {
      await fake.collection('transactions').doc('comm_order-1').set({
        'supplierUid': 'sup-1',
        'orderId': 'order-1',
        'commissionAmount': 240,
        'status': 'unsettled',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
      });
      await fake.collection('payment_proofs').doc('pay-1').set({
        'payerId': 'sup-1',
        'type': 'commission',
        'amount': 40,
        'status': 'settled',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 2)),
      });
      await signIn();
      await _waitUntil(() => viewModel.commissionOwed == 200);
      expect(viewModel.totalCommissionGenerated, 240);
      expect(viewModel.totalCommissionPaid, 40);
    });
  });
}
