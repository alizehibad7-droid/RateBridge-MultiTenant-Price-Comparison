import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/construction_categories_seed.dart';

/// Writes the permanent construction category catalog when Firestore is empty.
class CategorySeedService {
  final FirebaseFirestore _db;

  CategorySeedService(this._db);

  /// Seeds all categories if the collection has zero documents.
  /// Requires an authenticated Firestore session (project security rules).
  Future<void> seedIfEmpty() async {
    try {
      final probe = await _db.collection('categories').limit(1).get();
      if (probe.docs.isNotEmpty) return;

      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      for (final entry in kConstructionCategorySeeds) {
        final ref = _db.collection('categories').doc(entry.id);
        batch.set(ref, {
          ...entry.toFirestoreMap(),
          'createdAt': now,
        });
      }

      await batch.commit();
      debugPrint(
        'ConstructionCategoriesSeed: seeded ${kConstructionCategorySeeds.length} '
        'categories into Firestore',
      );
    } catch (e, stack) {
      debugPrint('ConstructionCategoriesSeed: skipped ($e)');
      if (kDebugMode) {
        debugPrint(stack.toString());
      }
    }
  }
}
