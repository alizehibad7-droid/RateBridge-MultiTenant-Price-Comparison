import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/models/rating_model.dart';
import 'package:ratebridge/models/supplier_model.dart';
import 'package:ratebridge/repositories/order_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';
import 'package:ratebridge/utils/app_exception.dart';

OrderModel _order({
  String orderId = 'order-1',
  String companyId = 'company-1',
  String supplierId = 'supplier-1',
  String fieldUserUid = 'field-1',
  String status = 'pending',
  DateTime? createdAt,
  double quantity = 10,
  double unitPrice = 100,
}) {
  final created = createdAt ?? DateTime.utc(2026, 4, 1, 10);
  return OrderModel(
    orderId: orderId,
    companyId: companyId,
    fieldUserUid: fieldUserUid,
    supplierId: supplierId,
    materialId: 'mat-1',
    materialName: 'OPC Cement',
    supplierName: 'Steel Co',
    fieldUserName: 'Ali Raza',
    quantity: quantity,
    unit: 'bag',
    unitPrice: unitPrice,
    totalAmount: quantity * unitPrice,
    deliveryAddress: 'Site 12, Lahore',
    status: status,
    createdAt: created,
    updatedAt: created,
  );
}

RatingModel _rating({
  String id = 'rating-1',
  String orderId = 'order-1',
  String supplierUid = 'supplier-1',
  String userId = 'field-1',
  double rating = 4,
}) {
  return RatingModel(
    id: id,
    orderId: orderId,
    supplierUid: supplierUid,
    userId: userId,
    userName: 'Ali Raza',
    materialId: 'mat-1',
    materialName: 'OPC Cement',
    rating: rating,
    comment: 'Good delivery',
    createdAt: DateTime.utc(2026, 4, 2),
  );
}

SupplierModel _supplier({String id = 'supplier-1'}) {
  return SupplierModel(
    id: id,
    name: 'Steel Co',
    email: 'steel@co.test',
    materialType: 'Steel',
    contact: '03001234567',
    status: 'Active',
    rating: 4.2,
    activeContracts: 3,
    contractValue: 100000,
    leadTimeDays: 2,
    city: 'Lahore',
  );
}

Future<void> _waitUntil(
  bool Function() test, {
  String because = 'condition never became true',
}) async {
  for (var i = 0; i < 50; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail(because);
}

void main() {
  late FakeFirebaseFirestore fake;
  late OrderRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = OrderRepository(
      FirestoreService(firestore: fake),
      firestore: fake,
    );
  });

  group('OrderRepository CRUD', () {
    test('createOrder then getOrderById returns the saved order', () async {
      final order = _order();
      await repo.createOrder(order);

      final loaded = await repo.getOrderById(order.orderId);
      expect(loaded, isNotNull);
      expect(loaded!.orderId, order.orderId);
      expect(loaded.companyId, order.companyId);
      expect(loaded.materialName, 'OPC Cement');
      expect(loaded.totalAmount, 1000);
    });

    test('submitOrder writes the same document as createOrder', () async {
      final order = _order(orderId: 'order-submit');
      await repo.submitOrder(order);

      final loaded = await repo.getOrderById('order-submit');
      expect(loaded?.supplierId, 'supplier-1');
    });

    test('getOrderById returns null when the document is missing', () async {
      expect(await repo.getOrderById('missing'), isNull);
    });

    test('updateOrder patches fields on the existing document', () async {
      await repo.createOrder(_order());
      await repo.updateOrder('order-1', {'notes': 'Call on arrival'});

      final loaded = await repo.getOrderById('order-1');
      expect(loaded!.notes, 'Call on arrival');
    });

    test('updateStatus lowercases status and stores rejection reason', () async {
      await repo.createOrder(_order());
      await repo.updateStatus(
        'order-1',
        'company-1',
        'Rejected',
        reason: 'Out of stock',
      );

      final loaded = await repo.getOrderById('order-1');
      expect(loaded!.status, 'rejected');
      expect(loaded.rejectionReason, 'Out of stock');
    });

    test('submitWeightReport marks the order delivered', () async {
      await repo.createOrder(_order(status: 'accepted'));
      await repo.submitWeightReport('order-1', 9.5, remarks: 'Short by 0.5');

      final snap = await fake.collection('orders').doc('order-1').get();
      final data = snap.data()!;
      expect(data['status'], 'delivered');
      expect(data['actualWeight'], 9.5);
      expect(data['weightReportRemarks'], 'Short by 0.5');
    });

    test('cancelOrder succeeds for pending orders', () async {
      await repo.createOrder(_order(status: 'pending'));
      await repo.cancelOrder('order-1', 'company-1');

      final loaded = await repo.getOrderById('order-1');
      expect(loaded!.status, 'cancelled');
    });

    test('cancelOrder throws when the order is already delivered', () async {
      await repo.createOrder(_order(status: 'delivered'));

      expect(
        () => repo.cancelOrder('order-1', 'company-1'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Cannot cancel order'),
          ),
        ),
      );
    });

    test('resolveCeoUid reads ceoUid from the company document', () async {
      await fake.collection('companies').doc('company-1').set({
        'ceoUid': 'ceo-99',
      });

      expect(await repo.resolveCeoUid('company-1'), 'ceo-99');
      expect(await repo.resolveCeoUid('missing'), isNull);
    });

    test('getRecentFieldOrders returns newest orders first', () async {
      await repo.createOrder(
        _order(orderId: 'older', createdAt: DateTime.utc(2026, 1, 1)),
      );
      await repo.createOrder(
        _order(orderId: 'newer', createdAt: DateTime.utc(2026, 6, 1)),
      );

      final recent = await repo.getRecentFieldOrders(1);
      expect(recent, hasLength(1));
      expect(recent.first.orderId, 'newer');
    });

    test('getSupplierById loads the supplier through FirestoreService', () async {
      final supplier = _supplier();
      await fake.collection('suppliers').doc(supplier.id).set(supplier.toMap());

      final loaded = await repo.getSupplierById(supplier.id);
      expect(loaded?.name, 'Steel Co');
      expect(loaded?.city, 'Lahore');
    });
  });

  group('OrderRepository streams', () {
    test('watchCompanyOrders emits when an order is added then updated', () async {
      final events = <List<OrderModel>>[];
      final sub = repo.watchCompanyOrders('company-1', 'All').listen(events.add);

      await _waitUntil(() => events.isNotEmpty, because: 'no initial snapshot');
      expect(events.last, isEmpty);

      await repo.createOrder(_order());
      await _waitUntil(
        () => events.any((e) => e.any((o) => o.orderId == 'order-1')),
        because: 'create did not emit',
      );
      expect(events.last.single.companyId, 'company-1');

      await repo.updateStatus('order-1', 'company-1', 'accepted');
      await _waitUntil(
        () => events.any((e) => e.any((o) => o.status == 'accepted')),
        because: 'status update did not emit',
      );

      await sub.cancel();
    });

    test('watchCompanyOrders status filter only includes matching orders', () async {
      await repo.createOrder(_order(orderId: 'pending-1', status: 'pending'));
      await repo.createOrder(_order(orderId: 'accepted-1', status: 'accepted'));

      final events = <List<OrderModel>>[];
      final sub =
          repo.watchCompanyOrders('company-1', 'accepted').listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.isNotEmpty),
        because: 'filtered snapshot never arrived',
      );
      expect(events.last.map((o) => o.orderId), ['accepted-1']);

      await sub.cancel();
    });

    test('getOrdersForSupplier emits the supplier orders newest first', () async {
      await repo.createOrder(
        _order(
          orderId: 'old',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await repo.createOrder(
        _order(
          orderId: 'new',
          createdAt: DateTime.utc(2026, 5, 1),
        ),
      );
      await repo.createOrder(
        _order(orderId: 'other-supplier', supplierId: 'supplier-2'),
      );

      final events = <List<OrderModel>>[];
      final sub = repo.getOrdersForSupplier('supplier-1').listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.length == 2),
        because: 'supplier stream did not emit both orders',
      );
      expect(events.last.map((o) => o.orderId), ['new', 'old']);

      await sub.cancel();
    });

    test('watchSupplierOrders scopes to company and supplier', () async {
      await repo.createOrder(_order());
      await repo.createOrder(_order(orderId: 'other-co', companyId: 'company-2'));

      final events = <List<OrderModel>>[];
      final sub = repo
          .watchSupplierOrders('supplier-1', 'company-1', 'All')
          .listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.isNotEmpty),
        because: 'supplier+company snapshot never arrived',
      );
      expect(events.last.map((o) => o.orderId), ['order-1']);

      await sub.cancel();
    });

    test('watchFieldUserOrders emits field-user orders for the company', () async {
      await repo.createOrder(_order());
      await repo.createOrder(
        _order(orderId: 'other-field', fieldUserUid: 'field-2'),
      );

      final events = <List<OrderModel>>[];
      final sub = repo
          .watchFieldUserOrders('field-1', 'company-1', null)
          .listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.isNotEmpty),
        because: 'field-user snapshot never arrived',
      );
      expect(events.last.single.orderId, 'order-1');

      await sub.cancel();
    });

    test('watchSupplierRatings emits after submitRating', () async {
      final events = <List<RatingModel>>[];
      final sub = repo.watchSupplierRatings('supplier-1').listen(events.add);

      await _waitUntil(() => events.isNotEmpty, because: 'no ratings snapshot');
      expect(events.last, isEmpty);

      await repo.submitRating('order-1', 'company-1', _rating());
      await _waitUntil(
        () => events.any((e) => e.isNotEmpty),
        because: 'submitRating did not emit',
      );
      expect(events.last.single.supplierUid, 'supplier-1');
      expect(events.last.single.comment, 'Good delivery');

      await sub.cancel();
    });
  });

  group('OrderRepository ratings', () {
    test('hasRatingForOrder is false until a rating exists', () async {
      expect(await repo.hasRatingForOrder('order-1', 'company-1'), isFalse);

      await repo.submitRating('order-1', 'company-1', _rating());

      expect(await repo.hasRatingForOrder('order-1', 'company-1'), isTrue);
    });

    test('hasRatingForOrderByUser matches userId or fieldUserId', () async {
      await fake.collection('ratings').add({
        'orderId': 'order-1',
        'fieldUserId': 'field-1',
        'rating': 5,
      });

      expect(await repo.hasRatingForOrderByUser('order-1', 'field-1'), isTrue);
      expect(await repo.hasRatingForOrderByUser('order-1', 'field-2'), isFalse);
    });

    test('updateSupplierAvgRating writes the mean score', () async {
      await repo.submitRating(
        'order-1',
        'company-1',
        _rating(rating: 5),
      );
      await repo.submitRating(
        'order-2',
        'company-1',
        _rating(id: 'rating-2', orderId: 'order-2', rating: 3),
      );

      await repo.updateSupplierAvgRating('supplier-1');

      final snap = await fake.collection('suppliers').doc('supplier-1').get();
      expect(snap.data()?['rating'], 4.0);
    });
  });
}
