import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/models/supplier_model.dart';
import 'package:ratebridge/repositories/material_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';

MaterialModel _material({
  String id = 'mat-1',
  String name = 'OPC Cement',
  String category = 'Cement',
  String supplierId = 'supplier-1',
  double price = 1250,
  DateTime? createdAt,
}) {
  return MaterialModel(
    id: id,
    name: name,
    category: category,
    pricePerUnit: price,
    unit: 'bag',
    specifications: '53 grade',
    qualityGrade: 'OPC 53',
    supplierId: supplierId,
    supplierName: 'Cement House',
    isCertified: true,
    originCity: 'Lahore',
    brand: 'Lucky',
    createdAt: createdAt ?? DateTime.utc(2026, 4, 1),
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
  late MaterialRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = MaterialRepository(
      FirestoreService(firestore: fake),
      firestore: fake,
    );
  });

  group('MaterialRepository CRUD', () {
    test('saveMaterial then getMaterialById returns the document', () async {
      final material = _material();
      await repo.saveMaterial(material);

      final loaded = await repo.getMaterialById(material.id);
      expect(loaded, isNotNull);
      expect(loaded!.name, 'OPC Cement');
      expect(loaded.pricePerUnit, 1250);
      expect(loaded.supplierId, 'supplier-1');
    });

    test('getMaterialById returns null when missing', () async {
      expect(await repo.getMaterialById('missing'), isNull);
    });

    test('removeMaterial deletes the document', () async {
      await repo.saveMaterial(_material());
      await repo.removeMaterial('mat-1');
      expect(await repo.getMaterialById('mat-1'), isNull);
    });

    test('saveMaterialWithCompany writes root and company copies', () async {
      final material = _material(id: 'mat-co');
      await repo.saveMaterialWithCompany(material, 'company-1');

      final root = await fake.collection('materials').doc('mat-co').get();
      final nested = await fake
          .collection('companies')
          .doc('company-1')
          .collection('materials')
          .doc('mat-co')
          .get();

      expect(root.exists, isTrue);
      expect(nested.exists, isTrue);
      expect(root.data()?['name'], 'OPC Cement');
      expect(nested.data()?['name'], 'OPC Cement');
    });

    test('updateMaterialFields patches both material copies', () async {
      await repo.saveMaterialWithCompany(_material(), 'company-1');
      await repo.updateMaterialFields('mat-1', 'company-1', {
        'pricePerUnit': 1400,
        'brand': 'DG Khan',
      });

      final root = await repo.getMaterialById('mat-1');
      final nested = await fake
          .collection('companies')
          .doc('company-1')
          .collection('materials')
          .doc('mat-1')
          .get();

      expect(root!.pricePerUnit, 1400);
      expect(root.brand, 'DG Khan');
      expect(nested.data()?['pricePerUnit'], 1400);
      expect(nested.data()?['brand'], 'DG Khan');
    });

    test('getMaterialsByIds returns an empty list for no ids', () async {
      expect(await repo.getMaterialsByIds([]), isEmpty);
    });

    test('getMaterialsByIds returns matching documents', () async {
      await repo.saveMaterial(_material(id: 'a', name: 'Steel Bar'));
      await repo.saveMaterial(_material(id: 'b', name: 'Sand'));
      await repo.saveMaterial(_material(id: 'c', name: 'Crush'));

      final loaded = await repo.getMaterialsByIds(['a', 'c']);
      expect(loaded.map((m) => m.id).toSet(), {'a', 'c'});
    });

    test('searchMaterials matches a name prefix', () async {
      await repo.saveMaterial(_material(name: 'OPC Cement'));
      await repo.saveMaterial(_material(id: 'mat-2', name: 'Steel Bar'));

      final hits = await repo.searchMaterials('OPC');
      expect(hits, hasLength(1));
      expect(hits.single.name, 'OPC Cement');
    });

    test('getPopularMaterials returns saved materials when no company', () async {
      await repo.saveMaterial(_material());
      final popular = await repo.getPopularMaterials();
      expect(popular, isNotEmpty);
      expect(popular.first.id, 'mat-1');
    });

    test('getCategories returns active categories sorted by name', () async {
      await fake.collection('categories').doc('steel').set({
        'name': 'Steel',
        'unit': 'ton',
        'active': true,
        'brands': ['Amreli'],
        'grades': ['60'],
      });
      await fake.collection('categories').doc('cement').set({
        'name': 'Cement',
        'unit': 'bag',
        'active': true,
      });
      await fake.collection('categories').doc('hidden').set({
        'name': 'Hidden',
        'unit': 'kg',
        'active': false,
      });

      final categories = await repo.getCategories();
      expect(categories.map((c) => c.name), ['Cement', 'Steel']);
    });

    test('getCompanyMaterialsBySupplier returns linked supplier stock', () async {
      await fake
          .collection('companies')
          .doc('company-1')
          .collection('suppliers')
          .doc('supplier-1')
          .set({'status': 'active'});
      await fake.collection('suppliers').doc('supplier-1').set({
        'id': 'supplier-1',
        'name': 'Cement House',
        'commissionRestricted': false,
      });
      await repo.saveMaterial(_material());
      await repo.saveMaterial(
        _material(id: 'mat-other', supplierId: 'supplier-2'),
      );

      final materials = await repo.getCompanyMaterialsBySupplier(
        'company-1',
        'supplier-1',
      );
      expect(materials.map((m) => m.id), ['mat-1']);
    });
  });

  group('MaterialRepository streams', () {
    test('getMaterials emits when a material is added then updated', () async {
      final events = <List<MaterialModel>>[];
      final sub = repo.getMaterials().listen(events.add);

      await _waitUntil(() => events.isNotEmpty, because: 'no materials snapshot');
      expect(events.last, isEmpty);

      await repo.saveMaterial(_material());
      await _waitUntil(
        () => events.any((e) => e.any((m) => m.id == 'mat-1')),
        because: 'saveMaterial did not emit',
      );
      expect(events.last.single.name, 'OPC Cement');

      await repo.saveMaterial(_material(price: 1300));
      await _waitUntil(
        () => events.any((e) => e.any((m) => m.pricePerUnit == 1300)),
        because: 'price update did not emit',
      );

      await sub.cancel();
    });

    test('getCompanyMaterials emits linked-supplier materials', () async {
      await fake
          .collection('companies')
          .doc('company-1')
          .collection('suppliers')
          .doc('supplier-1')
          .set({'status': 'active'});
      await fake.collection('suppliers').doc('supplier-1').set(
        SupplierModel(
          id: 'supplier-1',
          name: 'Cement House',
          email: 'c@co.test',
          materialType: 'Cement',
          contact: '03001112222',
          status: 'Active',
          rating: 4,
          activeContracts: 1,
          contractValue: 1,
          leadTimeDays: 1,
          city: 'Lahore',
        ).toMap(),
      );
      await repo.saveMaterial(_material());

      final events = <List<MaterialModel>>[];
      final sub = repo.getCompanyMaterials('company-1').listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.any((m) => m.id == 'mat-1')),
        because: 'company materials stream did not emit the linked listing',
      );
      expect(events.last.single.name, 'OPC Cement');

      await repo.saveMaterial(_material(id: 'mat-2', name: 'Sand'));
      await fake.collection('suppliers').doc('supplier-1').update({
        'commissionRestricted': false,
      });

      await _waitUntil(
        () => events.any((e) => e.length == 2),
        because: 'company materials stream did not emit the second listing',
      );

      await sub.cancel();
    });
  });
}
