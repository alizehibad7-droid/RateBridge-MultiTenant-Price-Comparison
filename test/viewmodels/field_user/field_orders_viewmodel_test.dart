import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/constants/app_constants.dart';
import 'package:ratebridge/constants/route_names.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/material_listing.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/models/supplier_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/field_user/field_orders_viewmodel.dart';
import 'package:ratebridge/views/field_user/orders/field_order_status.dart';

import '../../mocks/mocks.dart';

class FakeBuildContext extends Fake implements BuildContext {}

OrderModel _order({
  String orderId = 'order-1',
  String status = 'pending',
  double quantity = 10,
  double unitPrice = 100,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 4, 1);
  return OrderModel(
    orderId: orderId,
    companyId: 'co-1',
    fieldUserUid: 'field-1',
    supplierId: 'sup-1',
    materialId: 'mat-1',
    materialName: 'OPC Cement',
    supplierName: 'Cement House',
    fieldUserName: 'Ali Raza',
    quantity: quantity,
    unit: 'bag',
    unitPrice: unitPrice,
    totalAmount: quantity * unitPrice,
    commissionAmount: quantity * unitPrice * 0.02,
    supplierEarning: quantity * unitPrice * 0.98,
    deliveryAddress: 'Site 12, Lahore',
    status: status,
    createdAt: created,
    updatedAt: created,
  );
}

MaterialModel _material({double price = 100}) {
  return MaterialModel(
    id: 'mat-1',
    name: 'OPC Cement',
    category: 'Cement',
    pricePerUnit: price,
    unit: 'bag',
    specifications: '53',
    qualityGrade: 'OPC 53',
    supplierId: 'sup-1',
    supplierName: 'Cement House',
    isCertified: true,
    originCity: 'Lahore',
  );
}

MaterialListing _listing({double price = 100}) {
  return MaterialListing(
    id: 'mat-1',
    materialName: 'OPC Cement',
    supplierName: 'Cement House',
    supplierId: 'sup-1',
    pricePerUnit: price,
    unit: 'bag',
    category: 'Cement',
    city: 'Lahore',
  );
}

CompanyModel _company({double autoApprovalThreshold = 0}) {
  return CompanyModel(
    id: 'co-1',
    name: 'Acme Builders',
    registrationNumber: 'REG-1',
    address: 'Site 1',
    city: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
    autoApprovalThreshold: autoApprovalThreshold,
  );
}

SupplierModel _supplier({String status = 'Active'}) {
  return SupplierModel(
    id: 'sup-1',
    name: 'Cement House',
    email: 'steel@co.test',
    materialType: 'Cement',
    contact: '0300',
    status: status,
    rating: 4.5,
    activeContracts: 1,
    contractValue: 1000,
    leadTimeDays: 3,
    city: 'Lahore',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final order = _order();
  final material = _material();
  final listing = _listing();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0.0);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(order);
    registerFallbackValue(material);
    registerFallbackValue(listing);
    registerFallbackValue(DateTime.utc(2026, 5, 1));
  });

  late MockOrderRepository orderRepo;
  late MockTransactionRepository transactionRepo;
  late MockCompanyRepository companyRepo;
  late MockMaterialRepository materialRepo;
  late MockNotificationService notifications;
  late StreamController<List<OrderModel>> ordersStream;
  late FieldOrdersViewModel viewModel;

  String? navigatedPath;
  Map<String, String>? navigatedQuery;
  MaterialListing? navigatedListing;
  String? reorderError;
  Exception? capacityError;

  void createViewModel() {
    viewModel = FieldOrdersViewModel(
      orderRepo,
      transactionRepo,
      companyRepo,
      materialRepo,
      notifications,
      ensureActiveOrderCapacity: (companyId) async {
        if (capacityError != null) throw capacityError!;
      },
      navigateToPlaceOrder: ({
        required path,
        required queryParameters,
        required extra,
      }) {
        navigatedPath = path;
        navigatedQuery = queryParameters;
        navigatedListing = extra;
      },
      showReorderError: (message) => reorderError = message,
    );
  }

  setUp(() {
    orderRepo = MockOrderRepository();
    transactionRepo = MockTransactionRepository();
    companyRepo = MockCompanyRepository();
    materialRepo = MockMaterialRepository();
    notifications = MockNotificationService();
    ordersStream = StreamController<List<OrderModel>>.broadcast();
    navigatedPath = null;
    navigatedQuery = null;
    navigatedListing = null;
    reorderError = null;
    capacityError = null;

    when(() => orderRepo.watchFieldUserOrders(any(), any(), any()))
        .thenAnswer((_) => ordersStream.stream);
    when(() => orderRepo.submitOrder(any())).thenAnswer((_) async {});
    when(() => orderRepo.getOrderById(any())).thenAnswer((_) async => order);
    when(() => orderRepo.getSupplierById(any())).thenAnswer((_) async => _supplier());
    when(() => orderRepo.resolveCeoUid(any())).thenAnswer((_) async => 'ceo-1');
    when(() => orderRepo.updateStatus(any(), any(), any())).thenAnswer((_) async {});
    when(() => orderRepo.updateOrder(any(), any())).thenAnswer((_) async {});
    when(() => orderRepo.cancelOrder(any(), any())).thenAnswer((_) async {});
    when(() => orderRepo.submitWeightReport(any(), any(), remarks: any(named: 'remarks')))
        .thenAnswer((_) async {});
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
    when(() => orderRepo.hasRatingForOrder(any(), any())).thenAnswer((_) async => false);
    when(() => orderRepo.hasRatingForOrderByUser(any(), any()))
        .thenAnswer((_) async => false);
    when(() => companyRepo.getCompanyById(any())).thenAnswer((_) async => _company());
    when(() => companyRepo.isSupplierLinked(any(), any())).thenAnswer((_) async => true);
    when(() => materialRepo.getMaterialById(any())).thenAnswer((_) async => material);
    when(
      () => notifications.notifyNewOrder(
        supplierId: any(named: 'supplierId'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        fieldUserName: any(named: 'fieldUserName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.notifyOrderAutoApproved(
        ceoUid: any(named: 'ceoUid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        totalAmount: any(named: 'totalAmount'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.notifyOrderPendingApproval(
        ceoUid: any(named: 'ceoUid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        fieldUserName: any(named: 'fieldUserName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.notifyDeliveryConfirmed(
        supplierId: any(named: 'supplierId'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        fieldUserName: any(named: 'fieldUserName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.notifyOrderCancelled(
        supplierId: any(named: 'supplierId'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        fieldUserName: any(named: 'fieldUserName'),
      ),
    ).thenAnswer((_) async {});

    createViewModel();
  });

  tearDown(() async {
    viewModel.dispose();
    if (!ordersStream.isClosed) await ordersStream.close();
  });

  Future<bool> placeDefaultOrder({double quantity = 10}) {
    return viewModel.placeOrder(
      companyId: 'co-1',
      fieldUserUid: 'field-1',
      fieldUserName: 'Ali Raza',
      fieldUserPhone: '0300',
      material: material,
      quantity: quantity,
      siteLocation: 'Site 12, Lahore',
      requiredDate: DateTime.utc(2026, 5, 1),
      notes: 'Urgent',
    );
  }

  group('FieldOrdersViewModel.watchOrders', () {
    test('stores streamed orders and derived counts', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoadingOrders;
      });

      viewModel.watchOrders('field-1', 'co-1');
      expect(loadingOnFirst, isTrue);
      verify(() => orderRepo.watchFieldUserOrders('field-1', 'co-1', 'All'))
          .called(1);

      ordersStream.add([
        _order(orderId: 'p1', status: 'pending_approval'),
        _order(orderId: 'a1', status: 'accepted'),
        _order(orderId: 'd1', status: 'delivered'),
        _order(orderId: 'c1', status: 'confirmed'),
        _order(orderId: 'x1', status: 'cancelled'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoadingOrders, isFalse);
      expect(viewModel.orders, hasLength(5));
      expect(viewModel.pendingCount, 1);
      expect(viewModel.activeCount, 1);
      expect(viewModel.deliveredCount, 2);
      expect(viewModel.historyCount, 3);
      expect(viewModel.activeOrders.single.orderId, 'a1');
      expect(viewModel.recentOrders, hasLength(5));
      expect(viewModel.ordersForTab(FieldOrderTab.pending).single.orderId, 'p1');
      expect(viewModel.ordersForTab(FieldOrderTab.active).single.orderId, 'a1');
      expect(viewModel.ordersForTab(FieldOrderTab.history), hasLength(3));
    });

    test('later emissions replace orders; stream errors set AppException message',
        () async {
      viewModel.watchOrders('field-1', 'co-1');
      ordersStream.add([_order()]);
      await Future<void>.delayed(Duration.zero);

      ordersStream.add(const []);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.orders, isEmpty);

      ordersStream.addError(AppException('orders offline'));
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.errorMessage, 'orders offline');
      expect(viewModel.isLoadingOrders, isFalse);
    });
  });

  group('FieldOrdersViewModel tabs', () {
    test('requestOrdersSubTab clamps and consume clears it', () {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.requestOrdersSubTab(9);
      expect(viewModel.hasPendingOrdersSubTab, isTrue);
      expect(viewModel.consumeRequestedOrdersSubTab(), 3);
      expect(viewModel.hasPendingOrdersSubTab, isFalse);
      expect(viewModel.consumeRequestedOrdersSubTab(), isNull);
      expect(notifies, 1);
    });
  });

  group('FieldOrdersViewModel.fetch helpers', () {
    test('findOrder returns cache hits and null otherwise', () async {
      viewModel.watchOrders('field-1', 'co-1');
      ordersStream.add([_order()]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.findOrder('order-1')?.materialName, 'OPC Cement');
      expect(viewModel.findOrder('missing'), isNull);
    });

    test('fetchOrder uses cache and fetchOrderFromServer hits the repo',
        () async {
      viewModel.watchOrders('field-1', 'co-1');
      ordersStream.add([_order()]);
      await Future<void>.delayed(Duration.zero);

      expect(await viewModel.fetchOrder('order-1'), isNotNull);
      verifyNever(() => orderRepo.getOrderById(any()));

      when(() => orderRepo.getOrderById('order-9'))
          .thenAnswer((_) async => _order(orderId: 'order-9'));
      expect((await viewModel.fetchOrder('order-9'))?.orderId, 'order-9');
    });

    test('fetchOrderFromServer failure sets error and returns null', () async {
      when(() => orderRepo.getOrderById(any()))
          .thenThrow(AppException('not found'));

      expect(await viewModel.fetchOrderFromServer('x'), isNull);
      expect(viewModel.errorMessage, 'not found');
    });

    test('fetchSupplier success and failure', () async {
      expect((await viewModel.fetchSupplier('sup-1'))?.name, 'Cement House');

      when(() => orderRepo.getSupplierById(any()))
          .thenThrow(Exception('supplier down'));
      expect(await viewModel.fetchSupplier('sup-1'), isNull);
      expect(viewModel.errorMessage, contains('supplier down'));
    });

    test('hasRating helpers return repo values and false on failure', () async {
      when(() => orderRepo.hasRatingForOrder(any(), any()))
          .thenAnswer((_) async => true);
      when(() => orderRepo.hasRatingForOrderByUser(any(), any()))
          .thenAnswer((_) async => true);

      expect(await viewModel.hasRatingForOrder('order-1', 'co-1'), isTrue);
      expect(await viewModel.hasUserRatedOrder('order-1', 'field-1'), isTrue);

      when(() => orderRepo.hasRatingForOrder(any(), any()))
          .thenThrow(Exception('rating down'));
      expect(await viewModel.hasRatingForOrder('order-1', 'co-1'), isFalse);
      expect(viewModel.errorMessage, contains('rating down'));
    });
  });

  group('FieldOrdersViewModel.placeOrder', () {
    test('pending-approval path notifies the CEO', () async {
      var notifies = 0;
      var submittingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) submittingOnFirst = viewModel.isSubmitting;
      });

      final ok = await placeDefaultOrder();

      expect(ok, isTrue);
      expect(submittingOnFirst, isTrue);
      expect(viewModel.isSubmitting, isFalse);
      expect(notifies, 2);

      final submitted = verify(() => orderRepo.submitOrder(captureAny()))
          .captured
          .single as OrderModel;
      expect(submitted.status, AppConstants.statusPendingApproval);
      expect(submitted.totalAmount, 1000);
      expect(submitted.commissionAmount, 20);
      expect(submitted.supplierEarning, 980);
      expect(submitted.notes, 'Urgent');
      verify(
        () => notifications.notifyOrderPendingApproval(
          ceoUid: 'ceo-1',
          orderId: submitted.orderId,
          companyId: 'co-1',
          materialName: 'OPC Cement',
          fieldUserName: 'Ali Raza',
        ),
      ).called(1);
    });

    test('auto-approval notifies supplier and CEO', () async {
      when(() => companyRepo.getCompanyById(any()))
          .thenAnswer((_) async => _company(autoApprovalThreshold: 5000));

      final ok = await placeDefaultOrder();
      expect(ok, isTrue);

      final submitted = verify(() => orderRepo.submitOrder(captureAny()))
          .captured
          .single as OrderModel;
      expect(submitted.status, AppConstants.statusPending);
      verify(
        () => notifications.notifyNewOrder(
          supplierId: 'sup-1',
          orderId: submitted.orderId,
          companyId: 'co-1',
          materialName: 'OPC Cement',
          fieldUserName: 'Ali Raza',
        ),
      ).called(1);
      verify(
        () => notifications.notifyOrderAutoApproved(
          ceoUid: 'ceo-1',
          orderId: submitted.orderId,
          companyId: 'co-1',
          materialName: 'OPC Cement',
          totalAmount: 1000,
        ),
      ).called(1);
    });

    test('missing CEO falls back to pending and notifies the supplier',
        () async {
      when(() => orderRepo.resolveCeoUid(any())).thenAnswer((_) async => null);

      await placeDefaultOrder();

      final submitted = verify(() => orderRepo.submitOrder(captureAny()))
          .captured
          .single as OrderModel;
      verify(
        () => orderRepo.updateStatus(
          submitted.orderId,
          'co-1',
          AppConstants.statusPending,
        ),
      ).called(1);
      verify(
        () => notifications.notifyNewOrder(
          supplierId: 'sup-1',
          orderId: submitted.orderId,
          companyId: 'co-1',
          materialName: 'OPC Cement',
          fieldUserName: 'Ali Raza',
        ),
      ).called(1);
    });

    test('plan-limit failure returns false with AppException message', () async {
      capacityError = AppException('Active order limit reached', 'limit_reached');

      final ok = await placeDefaultOrder();

      expect(ok, isFalse);
      expect(viewModel.isSubmitting, isFalse);
      expect(viewModel.errorMessage, 'Active order limit reached');
      verifyNever(() => orderRepo.submitOrder(any()));
    });

    test('placeOrderFromListing delegates to placeOrder', () async {
      final ok = await viewModel.placeOrderFromListing(
        companyId: 'co-1',
        fieldUserUid: 'field-1',
        fieldUserName: 'Ali Raza',
        material: listing,
        quantity: 10,
        deliveryAddress: 'Site 12, Lahore',
        requiredDate: DateTime.utc(2026, 5, 1),
      );

      expect(ok, isTrue);
      verify(() => orderRepo.submitOrder(any())).called(1);
    });
  });

  group('FieldOrdersViewModel.confirmDelivery', () {
    test('success from cache updates status and notifies supplier', () async {
      viewModel.watchOrders('field-1', 'co-1');
      ordersStream.add([_order(status: 'delivered')]);
      await Future<void>.delayed(Duration.zero);

      final ok = await viewModel.confirmDelivery(
        orderId: 'order-1',
        companyId: 'co-1',
      );

      expect(ok, isTrue);
      verify(
        () => orderRepo.updateStatus(
          'order-1',
          'co-1',
          AppConstants.statusConfirmed,
        ),
      ).called(1);
      final orderUpdate = verify(() => orderRepo.updateOrder('order-1', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(orderUpdate.containsKey('commissionDeducted'), isFalse);
      verify(
        () => transactionRepo.createUnsettledCommissionTransaction(
          orderId: 'order-1',
          companyId: 'co-1',
          supplierUid: 'sup-1',
          totalAmount: 1000,
          commissionAmount: 20,
          supplierEarning: 980,
        ),
      ).called(1);
      verify(
        () => notifications.notifyDeliveryConfirmed(
          supplierId: 'sup-1',
          orderId: 'order-1',
          companyId: 'co-1',
          materialName: 'OPC Cement',
          fieldUserName: 'Ali Raza',
        ),
      ).called(1);
    });

    test('wrong status and missing order are failures', () async {
      viewModel.watchOrders('field-1', 'co-1');
      ordersStream.add([_order(status: 'accepted')]);
      await Future<void>.delayed(Duration.zero);

      expect(
        await viewModel.confirmDelivery(orderId: 'order-1', companyId: 'co-1'),
        isFalse,
      );
      expect(
        viewModel.errorMessage,
        contains('marked as delivered'),
      );

      when(() => orderRepo.getOrderById('missing')).thenAnswer((_) async => null);
      expect(
        await viewModel.confirmDelivery(orderId: 'missing', companyId: 'co-1'),
        isFalse,
      );
      expect(viewModel.errorMessage, 'Order not found');
    });
  });

  group('FieldOrdersViewModel.submitWeightReport', () {
    test('success and failure toggle submitting', () async {
      expect(
        await viewModel.submitWeightReport(
          orderId: 'order-1',
          companyId: 'co-1',
          actualWeight: 9.5,
          remarks: 'short',
        ),
        isTrue,
      );
      verify(
        () => orderRepo.submitWeightReport('order-1', 9.5, remarks: 'short'),
      ).called(1);

      when(
        () => orderRepo.submitWeightReport(
          any(),
          any(),
          remarks: any(named: 'remarks'),
        ),
      ).thenThrow(AppException('report denied'));

      expect(
        await viewModel.submitWeightReport(
          orderId: 'order-1',
          companyId: 'co-1',
          actualWeight: 1,
        ),
        isFalse,
      );
      expect(viewModel.errorMessage, 'report denied');
      expect(viewModel.isSubmitting, isFalse);
    });
  });

  group('FieldOrdersViewModel.cancelOrder', () {
    test('notifies the supplier when the order can be loaded', () async {
      expect(await viewModel.cancelOrder('order-1', 'co-1'), isTrue);
      verify(() => orderRepo.cancelOrder('order-1', 'co-1')).called(1);
      verify(
        () => notifications.notifyOrderCancelled(
          supplierId: 'sup-1',
          orderId: 'order-1',
          companyId: 'co-1',
          materialName: 'OPC Cement',
          fieldUserName: 'Ali Raza',
        ),
      ).called(1);
    });

    test('skips notify when the order cannot be loaded and still succeeds',
        () async {
      when(() => orderRepo.getOrderById(any())).thenAnswer((_) async => null);

      expect(await viewModel.cancelOrder('order-9', 'co-1'), isTrue);
      verifyNever(
        () => notifications.notifyOrderCancelled(
          supplierId: any(named: 'supplierId'),
          orderId: any(named: 'orderId'),
          companyId: any(named: 'companyId'),
          materialName: any(named: 'materialName'),
          fieldUserName: any(named: 'fieldUserName'),
        ),
      );
    });

    test('repository failure returns false', () async {
      when(() => orderRepo.cancelOrder(any(), any()))
          .thenThrow(AppException('Cannot cancel order in delivered status'));

      expect(await viewModel.cancelOrder('order-1', 'co-1'), isFalse);
      expect(
        viewModel.errorMessage,
        'Cannot cancel order in delivered status',
      );
    });
  });

  group('FieldOrdersViewModel.reorder', () {
    test('navigates with address and quantity when supplier is linked',
        () async {
      await viewModel.reorder(FakeBuildContext(), _order(quantity: 12));

      expect(viewModel.isSubmitting, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(navigatedPath, RouteNames.fieldPlaceOrder);
      expect(navigatedQuery?['address'], 'Site 12, Lahore');
      expect(navigatedQuery?['quantity'], '12.0');
      expect(navigatedListing?.id, 'mat-1');
    });

    test('missing material, inactive supplier, and unlinked company fail',
        () async {
      when(() => materialRepo.getMaterialById(any())).thenAnswer((_) async => null);
      await viewModel.reorder(FakeBuildContext(), order);
      expect(
        viewModel.errorMessage,
        'This material is no longer available from the supplier.',
      );
      expect(reorderError, viewModel.errorMessage);

      when(() => materialRepo.getMaterialById(any()))
          .thenAnswer((_) async => material);
      when(() => orderRepo.getSupplierById(any()))
          .thenAnswer((_) async => _supplier(status: 'Suspended'));
      await viewModel.reorder(FakeBuildContext(), order);
      expect(
        viewModel.errorMessage,
        'The supplier is no longer active on the platform.',
      );

      when(() => orderRepo.getSupplierById(any()))
          .thenAnswer((_) async => _supplier());
      when(() => companyRepo.isSupplierLinked(any(), any()))
          .thenAnswer((_) async => false);
      await viewModel.reorder(FakeBuildContext(), order);
      expect(
        viewModel.errorMessage,
        'This supplier is no longer linked to your company.',
      );
      expect(navigatedPath, isNull);
    });
  });

  group('FieldOrdersViewModel.clearError', () {
    test('clears errorMessage', () async {
      capacityError = AppException('limit');
      await placeDefaultOrder();
      expect(viewModel.errorMessage, isNotNull);

      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });
  });
}
