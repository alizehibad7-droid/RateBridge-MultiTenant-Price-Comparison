import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/constants/construction_categories_seed.dart';
import 'package:ratebridge/services/category_seed_service.dart';

const _denyWrites = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
''';

void main() {
  group('CategorySeedService.seedIfEmpty', () {
    test('writes every catalog entry when the collection is empty', () async {
      final fake = FakeFirebaseFirestore();
      final service = CategorySeedService(fake);

      await service.seedIfEmpty();

      final snap = await fake.collection('categories').get();
      expect(snap.docs, hasLength(kConstructionCategorySeeds.length));

      final cement = await fake.collection('categories').doc('cement').get();
      expect(cement.exists, isTrue);
      expect(cement.data()?['name'], 'Cement');
      expect(cement.data()?['unit'], 'bag');
      expect(cement.data()?['active'], isTrue);
      expect(cement.data()?['brands'], contains('Lucky'));
      expect(cement.data()?['grades'], contains('OPC'));

      final steel = await fake.collection('categories').doc('steel').get();
      expect(steel.data()?['name'], 'Steel / TMT Bars');
    });

    test('is a no-op when any category document already exists', () async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('categories').doc('cement').set({
        'name': 'Existing Cement',
        'active': true,
      });

      await CategorySeedService(fake).seedIfEmpty();

      final snap = await fake.collection('categories').get();
      expect(snap.docs, hasLength(1));
      expect(
        (await fake.collection('categories').doc('cement').get()).data()?['name'],
        'Existing Cement',
      );
    });

    test('swallows write failures and leaves the collection empty', () async {
      final fake = FakeFirebaseFirestore(securityRules: _denyWrites);
      final service = CategorySeedService(fake);

      await service.seedIfEmpty();

      final snap = await fake.collection('categories').get();
      expect(snap.docs, isEmpty);
    });
  });
}
