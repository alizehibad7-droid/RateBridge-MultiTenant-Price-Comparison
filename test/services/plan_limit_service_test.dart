import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/services/plan_limit_service.dart';
import 'package:ratebridge/utils/app_exception.dart';

void main() {
  late FakeFirebaseFirestore fake;

  setUp(() {
    fake = FakeFirebaseFirestore();
  });

  Future<void> seedCompany({
    String id = 'co-1',
    String plan = 'free',
  }) {
    return fake.collection('companies').doc(id).set({
      'name': 'Acme Builders',
      'status': 'active',
      'plan': plan,
    });
  }

  Future<void> seedOrders(
    int count, {
    String status = 'pending',
    String prefix = 'order',
  }) async {
    for (var i = 0; i < count; i++) {
      await fake.collection('orders').doc('$prefix-$i').set({
        'companyId': 'co-1',
        'status': status,
      });
    }
  }

  group('PlanLimitService.planForKey', () {
    test('defaults to free for null, empty, or unknown keys', () {
      expect(PlanLimitService.planForKey(null).planKey, 'free');
      expect(PlanLimitService.planForKey('').planKey, 'free');
      expect(PlanLimitService.planForKey('gold').planKey, 'free');
    });

    test('matches plan keys case-insensitively', () {
      expect(PlanLimitService.planForKey('PREMIUM').planKey, 'premium');
      expect(PlanLimitService.planForKey('Basic').maxActiveOrders, -1);
    });
  });

  group('PlanLimitService.companyPlan', () {
    test('uses the provided planKey without reading Firestore', () async {
      final plan = await PlanLimitService.companyPlan(
        fake,
        'missing',
        planKey: 'premium',
      );
      expect(plan.planKey, 'premium');
      expect(plan.maxSuppliers, -1);
    });

    test('throws when the company document is missing', () async {
      await expectLater(
        PlanLimitService.companyPlan(fake, 'missing'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Company not found'),
          ),
        ),
      );
    });

    test('reads the company plan when there is no subscription', () async {
      await seedCompany(plan: 'basic');
      final plan = await PlanLimitService.companyPlan(fake, 'co-1');
      expect(plan.planKey, 'basic');
    });

    test('defaults to free when the company has no plan field', () async {
      await fake.collection('companies').doc('co-1').set({'name': 'Acme'});
      final plan = await PlanLimitService.companyPlan(fake, 'co-1');
      expect(plan.planKey, 'free');
    });

    test('prefers an active unexpired subscription plan', () async {
      await seedCompany(plan: 'free');
      await fake.collection('subscriptions').doc('co-1').set({
        'plan': 'premium',
        'status': 'active',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 10)),
        ),
      });

      final plan = await PlanLimitService.companyPlan(fake, 'co-1');
      expect(plan.planKey, 'premium');
    });

    test('uses admin_granted subscriptions that have not expired', () async {
      await seedCompany(plan: 'free');
      await fake.collection('subscriptions').doc('co-1').set({
        'plan': 'basic',
        'status': 'admin_granted',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1)),
        ),
      });

      final plan = await PlanLimitService.companyPlan(fake, 'co-1');
      expect(plan.planKey, 'basic');
    });

    test('ignores expired or inactive subscriptions', () async {
      await seedCompany(plan: 'basic');
      await fake.collection('subscriptions').doc('co-1').set({
        'plan': 'premium',
        'status': 'active',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
      });

      expect(
        (await PlanLimitService.companyPlan(fake, 'co-1')).planKey,
        'basic',
      );

      await fake.collection('subscriptions').doc('co-1').set({
        'plan': 'premium',
        'status': 'cancelled',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 10)),
        ),
      });
      expect(
        (await PlanLimitService.companyPlan(fake, 'co-1')).planKey,
        'basic',
      );
    });

    test('rethrows when the company document cannot be read', () async {
      const denyReads = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
''';
      final locked = FakeFirebaseFirestore(securityRules: denyReads);

      await expectLater(
        PlanLimitService.companyPlan(locked, 'co-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('PlanLimitService.ensureActiveOrderCapacity', () {
    test('skips the count on unlimited plans', () async {
      await seedCompany(plan: 'premium');
      await seedOrders(20);
      await PlanLimitService.ensureActiveOrderCapacity(fake, 'co-1');
    });

    test('allows orders under the free-plan cap', () async {
      await seedCompany();
      await seedOrders(4);
      await PlanLimitService.ensureActiveOrderCapacity(fake, 'co-1');
    });

    test('throws limit_reached at the free-plan cap', () async {
      await seedCompany();
      await seedOrders(5);

      await expectLater(
        PlanLimitService.ensureActiveOrderCapacity(fake, 'co-1'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'limit_reached')
              .having((e) => e.message, 'message', contains('Active order limit')),
        ),
      );
    });

    test('does not count cancelled orders toward the cap', () async {
      await seedCompany();
      await seedOrders(4, status: 'pending');
      await seedOrders(3, status: 'cancelled', prefix: 'cancelled');
      await PlanLimitService.ensureActiveOrderCapacity(fake, 'co-1');
    });
  });

  group('PlanLimitService.ensureSupplierCapacity', () {
    test('returns immediately when the supplier is already linked', () async {
      await seedCompany();
      await fake
          .collection('companies')
          .doc('co-1')
          .collection('suppliers')
          .doc('sup-1')
          .set({'status': 'active'});
      for (var i = 0; i < 3; i++) {
        await fake
            .collection('companies')
            .doc('co-1')
            .collection('suppliers')
            .doc('other-$i')
            .set({'status': 'active'});
      }

      await PlanLimitService.ensureSupplierCapacity(
        fake,
        'co-1',
        supplierId: 'sup-1',
      );
    });

    test('skips the count on unlimited plans', () async {
      await seedCompany(plan: 'premium');
      await PlanLimitService.ensureSupplierCapacity(fake, 'co-1');
    });

    test('allows linking under the free-plan cap', () async {
      await seedCompany();
      await fake
          .collection('companies')
          .doc('co-1')
          .collection('suppliers')
          .doc('sup-1')
          .set({'status': 'active'});

      await PlanLimitService.ensureSupplierCapacity(fake, 'co-1');
    });

    test('throws limit_reached at the free-plan supplier cap', () async {
      await seedCompany();
      for (var i = 0; i < 3; i++) {
        await fake
            .collection('companies')
            .doc('co-1')
            .collection('suppliers')
            .doc('sup-$i')
            .set({'status': i == 0 ? 'approved' : 'active'});
      }

      await expectLater(
        PlanLimitService.ensureSupplierCapacity(fake, 'co-1'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'limit_reached')
              .having((e) => e.message, 'message', contains('Supplier limit')),
        ),
      );
    });

    test('pending supplier links do not consume capacity', () async {
      await seedCompany();
      for (var i = 0; i < 3; i++) {
        await fake
            .collection('companies')
            .doc('co-1')
            .collection('suppliers')
            .doc('pending-$i')
            .set({'status': 'pending'});
      }

      await PlanLimitService.ensureSupplierCapacity(fake, 'co-1');
    });
  });

  group('PlanLimitService.ensureFieldUserCapacity', () {
    test('uses planKey to skip the company lookup on unlimited plans', () async {
      await PlanLimitService.ensureFieldUserCapacity(
        fake,
        'missing',
        planKey: 'premium',
      );
    });

    test('throws when the company is missing and no planKey is given',
        () async {
      await expectLater(
        PlanLimitService.ensureFieldUserCapacity(fake, 'missing'),
        throwsA(isA<AppException>()),
      );
    });

    test('allows team members under the free-plan cap', () async {
      await seedCompany();
      await fake
          .collection('companies')
          .doc('co-1')
          .collection('fieldUsers')
          .doc('u-1')
          .set({'status': 'active'});

      await PlanLimitService.ensureFieldUserCapacity(fake, 'co-1');
    });

    test('throws limit_reached at the free-plan team cap', () async {
      await seedCompany();
      for (var i = 0; i < 3; i++) {
        await fake
            .collection('companies')
            .doc('co-1')
            .collection('fieldUsers')
            .doc('u-$i')
            .set({'status': 'active'});
      }

      await expectLater(
        PlanLimitService.ensureFieldUserCapacity(fake, 'co-1'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'limit_reached')
              .having((e) => e.message, 'message', contains('Team size limit')),
        ),
      );
    });

    test('inactive field users do not consume team capacity', () async {
      await seedCompany();
      for (var i = 0; i < 3; i++) {
        await fake
            .collection('companies')
            .doc('co-1')
            .collection('fieldUsers')
            .doc('u-$i')
            .set({'status': 'inactive'});
      }

      await PlanLimitService.ensureFieldUserCapacity(fake, 'co-1');
    });
  });
}
