import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/supplier_model.dart';
import 'package:ratebridge/repositories/supplier_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';

SupplierModel _supplier({
  String id = 'sup-1',
  String name = 'Cement House',
  String city = 'Lahore',
}) {
  return SupplierModel(
    id: id,
    name: name,
    email: '$id@co.test',
    materialType: 'Cement',
    contact: '03001234567',
    status: 'Active',
    rating: 4.5,
    activeContracts: 2,
    contractValue: 10000,
    leadTimeDays: 3,
    city: city,
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
  late SupplierRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = SupplierRepository(FirestoreService(firestore: fake));
  });

  group('SupplierRepository', () {
    test('registerSupplier writes the supplier document', () async {
      await repo.registerSupplier(_supplier());

      final doc = await fake.collection('suppliers').doc('sup-1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'Cement House');
      expect(doc.data()?['city'], 'Lahore');
      expect(doc.data()?['email'], 'sup-1@co.test');
    });

    test('getSuppliers emits an empty list then registered suppliers', () async {
      final events = <List<SupplierModel>>[];
      final sub = repo.getSuppliers().listen(events.add);

      await _waitUntil(() => events.isNotEmpty, because: 'no suppliers snapshot');
      expect(events.last, isEmpty);

      await repo.registerSupplier(_supplier());
      await _waitUntil(
        () => events.any((e) => e.any((s) => s.id == 'sup-1')),
        because: 'registerSupplier did not emit',
      );
      expect(events.last.single.name, 'Cement House');

      await repo.registerSupplier(_supplier(id: 'sup-2', name: 'Steel Mills'));
      await _waitUntil(
        () => events.any((e) => e.length == 2),
        because: 'second supplier did not emit',
      );
      expect(events.last.map((s) => s.id).toSet(), {'sup-1', 'sup-2'});

      await sub.cancel();
    });
  });
}
