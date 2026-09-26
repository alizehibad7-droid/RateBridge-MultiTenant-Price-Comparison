import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/repositories/company_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';

CompanyModel _company({
  String id = 'co-1',
  String name = 'Acme Builders',
  String plan = 'free',
}) {
  return CompanyModel(
    id: id,
    name: name,
    registrationNumber: 'REG-1',
    address: 'Site 1',
    city: 'Lahore',
    status: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
    plan: plan,
  );
}

void main() {
  late FakeFirebaseFirestore fake;
  late CompanyRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = CompanyRepository(FirestoreService(firestore: fake));
  });

  group('CompanyRepository', () {
    test('createCompany then getCompanyById returns the document', () async {
      await repo.createCompany(_company());

      final loaded = await repo.getCompanyById('co-1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Acme Builders');
      expect(loaded.plan, 'free');
      expect(loaded.city, 'Lahore');
    });

    test('getCompanyById returns null when missing', () async {
      expect(await repo.getCompanyById('missing'), isNull);
    });

    test('getAllCompanies returns every saved company', () async {
      await repo.createCompany(_company());
      await repo.createCompany(_company(id: 'co-2', name: 'Beta Builders'));

      final all = await repo.getAllCompanies();
      expect(all.map((c) => c.id).toSet(), {'co-1', 'co-2'});
    });

    test('isSupplierLinked is true only for active or approved links', () async {
      expect(await repo.isSupplierLinked('co-1', 'sup-1'), isFalse);

      await fake
          .collection('companies')
          .doc('co-1')
          .collection('suppliers')
          .doc('sup-1')
          .set({'status': 'pending'});
      expect(await repo.isSupplierLinked('co-1', 'sup-1'), isFalse);

      await fake
          .collection('companies')
          .doc('co-1')
          .collection('suppliers')
          .doc('sup-1')
          .set({'status': 'active'});
      expect(await repo.isSupplierLinked('co-1', 'sup-1'), isTrue);

      await fake
          .collection('companies')
          .doc('co-1')
          .collection('suppliers')
          .doc('sup-2')
          .set({'status': 'approved'});
      expect(await repo.isSupplierLinked('co-1', 'sup-2'), isTrue);
    });
  });
}
