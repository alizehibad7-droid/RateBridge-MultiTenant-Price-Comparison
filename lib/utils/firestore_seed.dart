import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time dev seed for Firestore test data (categories, materials, etc.).
///
/// ## Field User panel — required Firestore composite indexes
/// Create in Firebase Console → Firestore → Indexes → Composite (or deploy
/// [firestore.indexes.json]). Wait 2–3 minutes after creating each index.
///
/// 1. **orders** — `fieldUserUid` ASC, `companyId` ASC
///    (optional third field: `status` ASC when filtering by status)
/// 2. **notifications** — `userId` ASC, `isRead` ASC
/// 3. **chats** — `isThread` ASC, `companyId` ASC, `fieldUserId` ASC,
///    `lastMessageAt` DESC (field-user thread list)
/// 4. **chats** — `isThread` ASC, `supplierId` ASC, `lastMessageAt` DESC
///    (supplier thread list)
/// 5. **materials** — `supplierId` ASC, `category` ASC (company category browse)
/// 6. **materials** — `category` ASC, `pricePerUnit` ASC/DESC (global sort)
/// 7. **ratings** — `supplierUid` ASC, `createdAt` DESC
class FirestoreSeed {  FirestoreSeed._();

  static const _testSupplier2 = 'test_supplier_2';
  static const _welcomeTitle = 'Welcome to RateBridge';

  static const _materialCementAli = 'seed_mat_cement_ali';
  static const _materialCementKhan = 'seed_mat_cement_khan';
  static const _materialSteelAli = 'seed_mat_steel_ali';

  static const _categories = <(String id, String name, String unit)>[
    ('cement', 'Cement', 'bag'),
    ('steel', 'Steel', 'ft'),
    ('bricks', 'Bricks', '1000 pcs'),
    ('sand', 'Sand', 'trolley'),
    ('pipes', 'Pipes', 'piece'),
    ('timber', 'Timber', 'cft'),
  ];

  /// Seeds realistic test data for the Field User panel.
  ///
  /// [supplierUid] — primary supplier for materials 1 & 3 (e.g. `seed_supplier_ali`).
  /// [fieldUserUid] — current field user; receives the welcome notification.
  ///
  /// Idempotent: skips docs that already exist.
  static Future<String> seed(
    FirebaseFirestore db,
    String companyId,
    String supplierUid, {
    required String fieldUserUid,
  }) async {
    final now = DateTime.now();
    final steps = <String>[];

    await _seedCategories(db, now, steps);
    await _linkSupplierToCompany(db, companyId, supplierUid, now, steps);
    await _linkSupplierToCompany(db, companyId, _testSupplier2, now, steps);
    await _seedSupplierProfiles(db, supplierUid, steps);
    final material1Id = await _seedMaterials(db, supplierUid, now, steps);
    if (material1Id != null) {
      await _seedPriceHistory(db, material1Id, supplierUid, now, steps);
      await _seedCompanyPriceHistory(
        db,
        companyId,
        material1Id,
        supplierUid,
        now,
        steps,
      );
    }
    await _seedWelcomeNotification(db, fieldUserUid, now, steps);

    return steps.isEmpty ? 'Seed data already present' : steps.join('\n');  }

  static Future<void> _seedCategories(
    FirebaseFirestore db,
    DateTime now,
    List<String> steps,
  ) async {
    for (final (id, name, unit) in _categories) {
      final ref = db.collection('categories').doc(id);
      try {
        final existing = await ref.get();
        if (existing.exists) continue;

        await ref.set({
          'id': id,
          'name': name,
          'unit': unit,
          'brands': <String>[],
          'grades': <String>[],
          'createdAt': Timestamp.fromDate(now),
        });
        steps.add('Created category: $name');
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          steps.add(
            'Categories skipped (admin-only write); home chips use material categories',
          );
          return;
        }
        rethrow;
      }
    }
  }

  static bool _isActiveSupplierStatus(dynamic status) {
    final normalized = (status as String?)?.toLowerCase() ?? '';
    return normalized == 'active' || normalized == 'approved';
  }
  static Future<void> _linkSupplierToCompany(
    FirebaseFirestore db,
    String companyId,
    String supplierId,
    DateTime now,
    List<String> steps,
  ) async {
    final ref = db
        .collection('companies')
        .doc(companyId)
        .collection('suppliers')
        .doc(supplierId);
    final existing = await ref.get();
    final wasActive =
        existing.exists && _isActiveSupplierStatus(existing.data()?['status']);

    // Always merge so compare/home queries see linked suppliers (status: active).
    await ref.set({
      'status': 'active',
      'joinedAt': existing.data()?['joinedAt'] ?? Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    if (!existing.exists) {
      steps.add('Linked supplier $supplierId to company');
    } else if (!wasActive) {
      steps.add('Updated supplier $supplierId link to active');
    }  }

  static Future<void> _seedSupplierProfiles(
    FirebaseFirestore db,
    String supplierUid,
    List<String> steps,
  ) async {
    final profiles = <String, Map<String, dynamic>>{
      supplierUid: {
        'id': supplierUid,
        'uid': supplierUid,
        'name': 'Ali Construction Store',
        'city': 'Lahore',
        'contact': '03009876543',
      },
      _testSupplier2: {
        'id': _testSupplier2,
        'uid': _testSupplier2,
        'name': 'Khan Materials',
        'city': 'Rawalpindi',
        'contact': '03001234567',
      },
    };

    for (final entry in profiles.entries) {
      final ref = db.collection('suppliers').doc(entry.key);
      final existing = await ref.get();
      if (existing.exists) continue;

      await ref.set(entry.value, SetOptions(merge: true));
      steps.add('Created supplier profile: ${entry.value['name']}');
    }
  }

  static Future<String?> _seedMaterials(
    FirebaseFirestore db,
    String supplierUid,
    DateTime now,
    List<String> steps,
  ) async {
    final materials = <String, Map<String, dynamic>>{
      _materialCementAli: {
        'id': _materialCementAli,
        'name': 'DG Khan Cement 50kg',
        'supplierId': supplierUid,
        'supplierUid': supplierUid,
        'supplierName': 'Ali Construction Store',
        'category': 'Cement',
        'unit': 'bag',
        'pricePerUnit': 1450,
        'createdAt': Timestamp.fromDate(now),
      },
      _materialCementKhan: {
        'id': _materialCementKhan,
        'name': 'DG Khan Cement 50kg',
        'supplierId': _testSupplier2,
        'supplierUid': _testSupplier2,
        'supplierName': 'Khan Materials',
        'category': 'Cement',
        'unit': 'bag',
        'pricePerUnit': 1380,
        'createdAt': Timestamp.fromDate(now),
      },
      _materialSteelAli: {
        'id': _materialSteelAli,
        'name': 'TMT Steel Rod 40ft',
        'supplierId': supplierUid,
        'supplierUid': supplierUid,
        'supplierName': 'Ali Construction Store',
        'category': 'Steel',
        'unit': 'ft',
        'pricePerUnit': 185,
        'createdAt': Timestamp.fromDate(now),
      },    };

    String? cementAliId;
    for (final entry in materials.entries) {
      final ref = db.collection('materials').doc(entry.key);
      final existing = await ref.get();
      if (existing.exists) {
        if (entry.key == _materialCementAli) cementAliId = entry.key;
        continue;
      }

      await ref.set(entry.value, SetOptions(merge: true));
      steps.add('Created material: ${entry.value['name']}');
      if (entry.key == _materialCementAli) cementAliId = entry.key;
    }

    return cementAliId;
  }

  static Future<void> _seedPriceHistory(
    FirebaseFirestore db,
    String materialId,
    String supplierUid,
    DateTime now,
    List<String> steps,
  ) async {
    final historyRef =
        db.collection('materials').doc(materialId).collection('priceHistory');

    final existing = await historyRef.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final entries = <(String id, int monthsAgo, double price)>[
      ('seed_ph_6mo', 6, 1350),
      ('seed_ph_4mo', 4, 1400),
      ('seed_ph_2mo', 2, 1420),
      ('seed_ph_today', 0, 1450),
    ];

    final batch = db.batch();
    for (final (id, monthsAgo, price) in entries) {
      final timestamp = Timestamp.fromDate(
        now.subtract(Duration(days: monthsAgo * 30)),
      );
      batch.set(historyRef.doc(id), {
        'materialId': materialId,
        'supplierUid': supplierUid,
        'price': price,
        'timestamp': timestamp,
        'recordedAt': timestamp,
      });
    }
    await batch.commit();
    steps.add('Created price history for DG Khan Cement (4 points)');
  }

  /// Mirrors price history under the company material path used by chart queries.
  static Future<void> _seedCompanyPriceHistory(
    FirebaseFirestore db,
    String companyId,
    String materialId,
    String supplierUid,
    DateTime now,
    List<String> steps,
  ) async {
    final historyRef = db
        .collection('companies')
        .doc(companyId)
        .collection('materials')
        .doc(materialId)
        .collection('priceHistory');

    final existing = await historyRef.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final entries = <(String id, int monthsAgo, double price)>[
      ('seed_co_ph_6mo', 6, 1350),
      ('seed_co_ph_4mo', 4, 1400),
      ('seed_co_ph_2mo', 2, 1420),
      ('seed_co_ph_today', 0, 1450),
    ];

    final batch = db.batch();
    for (final (id, monthsAgo, price) in entries) {
      final timestamp = Timestamp.fromDate(
        now.subtract(Duration(days: monthsAgo * 30)),
      );
      batch.set(historyRef.doc(id), {
        'materialId': materialId,
        'supplierUid': supplierUid,
        'price': price,
        'timestamp': timestamp,
        'recordedAt': timestamp,
      });
    }
    await batch.commit();
    steps.add('Created company-scoped price history for trends chart');
  }
  static Future<void> _seedWelcomeNotification(
    FirebaseFirestore db,
    String fieldUserUid,
    DateTime now,
    List<String> steps,
  ) async {
    final notifId = 'seed_welcome_$fieldUserUid';
    final existing = await db.collection('notifications').doc(notifId).get();
    if (existing.exists) return;

    await db.collection('notifications').doc(notifId).set({
      'userId': fieldUserUid,
      'title': _welcomeTitle,
      'body': 'Your account is active. Start comparing material prices.',
      'type': 'system',
      'isRead': false,
      'data': <String, dynamic>{},
      'createdAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
    steps.add('Created welcome notification');
  }

  static const tmtSteelRodName = 'TMT Steel Rod 40ft';

  /// PKR per foot — nominal Jan–Jun 2025 Pakistan steel market prices.
  static const List<double> _tmtSteelRodMonthlyPrices = [
    2800,
    2750,
    2900,
    3050,
    2980,
    3100,
  ];

  /// Seeds six monthly price points for [materialId] on every path read by
  /// [FieldTrendsViewModel]. Uses rolling first-of-month dates so data stays
  /// inside the 6-month lookback.
  static Future<String> seedMaterialPriceTrend(
    FirebaseFirestore db, {
    required String companyId,
    required String materialId,
    required String supplierUid,
  }) async {
    final materialDoc = await db.collection('materials').doc(materialId).get();
    if (!materialDoc.exists) {
      return 'Material not found: $materialId';
    }

    final data = materialDoc.data()!;
    final resolvedSupplier = _resolveSupplierUid(supplierUid, data);
    if (resolvedSupplier == null) {
      return 'No supplier id found for this material';
    }

    final materialName = (data['name'] as String?) ?? materialId;
    final prices = _monthlyPricesForMaterial(materialName, data);
    final entries = _rollingMonthlyTrendEntries(prices);

    final batch = db.batch();
    var writeCount = 0;

    for (final entry in entries) {
      final payload = {
        'materialId': materialId,
        'supplierId': resolvedSupplier,
        'supplierUid': resolvedSupplier,
        'price': entry.price,
        'recordedAt': Timestamp.fromDate(entry.recordedAt),
        'timestamp': Timestamp.fromDate(entry.recordedAt),
      };

      final paths = [
        db
            .collection('materials')
            .doc(materialId)
            .collection('priceHistory')
            .doc('seed_trend_${entry.docKey}'),
        db
            .collection('companies')
            .doc(companyId)
            .collection('materials')
            .doc(materialId)
            .collection('priceHistory')
            .doc('seed_trend_${entry.docKey}'),
        db
            .collection('suppliers')
            .doc(resolvedSupplier)
            .collection('materials')
            .doc(materialId)
            .collection('priceHistory')
            .doc('seed_trend_${entry.docKey}'),
      ];

      for (final ref in paths) {
        batch.set(ref, payload, SetOptions(merge: true));
        writeCount++;
      }
    }

    await batch.commit();
    return 'Seeded $writeCount price history docs for $materialName '
        '($materialId)';
  }

  /// Backward-compatible helper for TMT steel rod test data.
  static Future<String> seedTmtSteelRodPriceTrend(
    FirebaseFirestore db, {
    required String companyId,
  }) async {
    final resolved = await _resolveTmtSteelRodMaterial(db);
    if (resolved == null) {
      return 'Material not found: $tmtSteelRodName';
    }
    return seedMaterialPriceTrend(
      db,
      companyId: companyId,
      materialId: resolved.materialId,
      supplierUid: resolved.supplierId,
    );
  }

  static String? _resolveSupplierUid(
    String supplierUid,
    Map<String, dynamic> materialData,
  ) {
    if (supplierUid.isNotEmpty &&
        supplierUid != '_' &&
        supplierUid != 'all') {
      return supplierUid;
    }
    return _readSupplierId(materialData);
  }

  static List<double> _monthlyPricesForMaterial(
    String materialName,
    Map<String, dynamic> data,
  ) {
    if (materialName == tmtSteelRodName) {
      return _tmtSteelRodMonthlyPrices;
    }
    if (materialName.contains('Cement')) {
      return const [1320, 1350, 1380, 1400, 1420, 1450];
    }
    final current = (data['pricePerUnit'] as num?)?.toDouble() ?? 1000;
    return List.generate(
      6,
      (index) => double.parse(
        (current * (0.9 + index * 0.04)).toStringAsFixed(0),
      ),
    );
  }

  static List<({DateTime recordedAt, double price, String docKey})>
      _rollingMonthlyTrendEntries(List<double> prices) {
    final anchor = DateTime(DateTime.now().year, DateTime.now().month, 1);
    return List.generate(prices.length, (index) {
      final monthsBack = prices.length - 1 - index;
      final date = DateTime(anchor.year, anchor.month - monthsBack, 1);
      return (
        recordedAt: date,
        price: prices[index],
        docKey: '${date.year}_${date.month.toString().padLeft(2, '0')}',
      );
    });
  }

  static Future<({String materialId, String supplierId})?> _resolveTmtSteelRodMaterial(
    FirebaseFirestore db,
  ) async {
    final byName = await db
        .collection('materials')
        .where('name', isEqualTo: tmtSteelRodName)
        .limit(10)
        .get();

    for (final doc in byName.docs) {
      final supplierId = _readSupplierId(doc.data());
      if (supplierId != null) {
        return (materialId: doc.id, supplierId: supplierId);
      }
    }

    final fallback = await db.collection('materials').doc(_materialSteelAli).get();
    if (!fallback.exists) return null;
    final supplierId = _readSupplierId(fallback.data()!);
    if (supplierId == null) return null;
    return (materialId: _materialSteelAli, supplierId: supplierId);
  }

  static String? _readSupplierId(Map<String, dynamic> data) {
    final supplierId = data['supplierId'] as String?;
    if (supplierId != null && supplierId.isNotEmpty) return supplierId;
    final supplierUid = data['supplierUid'] as String?;
    if (supplierUid != null && supplierUid.isNotEmpty) return supplierUid;
    return null;
  }
}
