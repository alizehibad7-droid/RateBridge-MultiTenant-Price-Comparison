import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../models/supplier_model.dart';
import '../models/material_model.dart';
import '../models/order_model.dart';
import '../models/chat_message_model.dart';
import '../models/rating_model.dart';
import '../models/subscription_model.dart';
import '../models/chat_thread_model.dart';
import '../models/price_history_model.dart';
import '../models/invitation_model.dart';
import '../models/join_request_model.dart';
import '../models/notification_model.dart';
import '../models/category_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> _requireDocData(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Document ${doc.reference.path} has no data');
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Map<String, dynamic> _queryDocData(QueryDocumentSnapshot doc) {
    return Map<String, dynamic>.from(doc.data() as Map);
  }

  // --- Users ---
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(_requireDocData(doc));
    }
    return null;
  }

  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // --- Companies ---
  Future<CompanyModel?> getCompany(String companyId) async {
    final doc = await _db.collection('companies').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      final data = _requireDocData(doc);
      if (data['id'] == null || (data['id'] as String).isEmpty) {
        data['id'] = doc.id;
      }
      return CompanyModel.fromMap(data);
    }
    return null;
  }

  Future<List<CompanyModel>> getCompanies() async {
    final snap = await _db.collection('companies').get();
    return snap.docs.map((doc) {
      final data = doc.data();
      if (data['id'] == null || (data['id'] as String).isEmpty) {
        data['id'] = doc.id;
      }
      return CompanyModel.fromMap(data);
    }).toList();
  }

  Future<void> saveCompany(CompanyModel company) async {
    await _db.collection('companies').doc(company.id).set(company.toMap());
  }

  // --- Suppliers ---
  Stream<List<SupplierModel>> streamSuppliers() {
    return _db.collection('suppliers').snapshots().map((snap) =>
        snap.docs.map((doc) => SupplierModel.fromMap(doc.data())).toList());
  }

  Future<void> saveSupplier(SupplierModel supplier) async {
    await _db.collection('suppliers').doc(supplier.id).set(supplier.toMap());
  }

  Future<SupplierModel?> getSupplierById(String supplierUid) async {
    final doc = await _db.collection('suppliers').doc(supplierUid).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = _requireDocData(doc);
    return SupplierModel.fromMap({...data, 'id': doc.id});
  }

  // --- Materials ---
  Stream<List<MaterialModel>> streamMaterials() {
    return _db.collection('materials').snapshots().map((snap) =>
        snap.docs.map((doc) => MaterialModel.fromMap(doc.data())).toList());
  }

  Stream<List<MaterialModel>> streamCompanyMaterials(String companyId) {
    return _db.collection('companies').doc(companyId).collection('suppliers').snapshots().asyncMap((suppliersSnap) async {
      final supplierIds = suppliersSnap.docs
          .where((doc) => _isActiveSupplierLink(doc.data()))
          .map((doc) => doc.id)
          .toList();
      return _materialsForSupplierIds(supplierIds);
    });
  }

  Future<List<MaterialModel>> getRecentCompanyMaterials(
    String companyId, {
    int limit = 4,
  }) async {
    final supplierIds = await getCompanyLinkedSupplierIds(companyId);
    if (supplierIds.isEmpty) return [];

    final allMaterials = await _materialsForSupplierIds(supplierIds);

    allMaterials.sort((a, b) {
      final aDate = a.createdAt ?? _materialSortFallback(a.id);
      final bDate = b.createdAt ?? _materialSortFallback(b.id);
      return bDate.compareTo(aDate);
    });

    if (allMaterials.length <= limit) return allMaterials;
    return allMaterials.sublist(0, limit);
  }

  Future<List<MaterialModel>> _materialsForSupplierIds(
    List<String> supplierIds,
  ) async {
    if (supplierIds.isEmpty) return [];

    final chunks = <List<String>>[];
    for (var i = 0; i < supplierIds.length; i += 30) {
      chunks.add(
        supplierIds.sublist(
          i,
          i + 30 > supplierIds.length ? supplierIds.length : i + 30,
        ),
      );
    }

    final seenIds = <String>{};
    final allMaterials = <MaterialModel>[];

    void addFromDocs(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
      for (final doc in docs) {
        final material = _materialFromDoc(doc.id, doc.data());
        if (seenIds.add(material.id)) {
          allMaterials.add(material);
        }
      }
    }

    for (final chunk in chunks) {
      final bySupplierId = await _db
          .collection('materials')
          .where('supplierId', whereIn: chunk)
          .get();
      addFromDocs(bySupplierId.docs);

      final bySupplierUid = await _db
          .collection('materials')
          .where('supplierUid', whereIn: chunk)
          .get();
      addFromDocs(bySupplierUid.docs);
    }

    return allMaterials;
  }

  MaterialModel _materialFromDoc(String docId, Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    map['id'] = (map['id'] as String?)?.isNotEmpty == true ? map['id'] : docId;
    return MaterialModel.fromMap(map);
  }

  DateTime _materialSortFallback(String id) {
    final ms = int.tryParse(id);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<List<MaterialModel>> getPopularMaterials({String? companyId}) async {
    if (companyId != null && companyId.isNotEmpty) {
      return getRecentCompanyMaterials(companyId, limit: 10);
    }
    final snap = await _db.collection('materials').limit(10).get();
    return snap.docs
        .map((doc) => _materialFromDoc(doc.id, doc.data()))
        .toList();
  }

  Future<MaterialModel?> getMaterialById(String id) async {
    final doc = await _db.collection('materials').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return MaterialModel.fromMap(_requireDocData(doc));
  }

  Future<List<MaterialModel>> getMaterialsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final snap = await _db.collection('materials').where(FieldPath.documentId, whereIn: ids).get();
    return snap.docs.map((doc) => MaterialModel.fromMap(doc.data())).toList();
  }

  Future<List<MaterialModel>> searchMaterials(String query) async {
    final snap = await _db
        .collection('materials')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snap.docs.map((doc) => MaterialModel.fromMap(doc.data())).toList();
  }

  Stream<List<MaterialModel>> streamCategoryMaterials(String category, {String? companyId, Map<String, dynamic>? filters, String? sort}) {
    if (companyId != null) {
      return _db.collection('companies').doc(companyId).collection('suppliers').snapshots().asyncMap((suppliersSnap) async {
        final supplierIds = suppliersSnap.docs
            .where((doc) => _isActiveSupplierLink(doc.data()))
            .map((doc) => doc.id)
            .toList();
        if (supplierIds.isEmpty) return [];

        final chunks = <List<String>>[];
        for (var i = 0; i < supplierIds.length; i += 30) {
          chunks.add(supplierIds.sublist(i, i + 30 > supplierIds.length ? supplierIds.length : i + 30));
        }

        final filteredMaterials = <MaterialModel>[];
        for (final chunk in chunks) {
          Query query = _db.collection('materials')
              .where('supplierId', whereIn: chunk)
              .where('category', isEqualTo: category);
          
          if (filters != null) {
            filters.forEach((key, value) {
              if (value != null) query = query.where(key, isEqualTo: value);
            });
          }

          final materialsSnap = await query.get();
          filteredMaterials.addAll(
            materialsSnap.docs.map(
              (doc) => MaterialModel.fromMap(_queryDocData(doc)),
            ),
          );
        }
        
        if (sort == 'price_asc') {
          filteredMaterials.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
        } else if (sort == 'price_desc') {
          filteredMaterials.sort((a, b) => b.pricePerUnit.compareTo(a.pricePerUnit));
        }

        return filteredMaterials;
      });
    }

    Query query = _db.collection('materials').where('category', isEqualTo: category);
    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null) query = query.where(key, isEqualTo: value);
      });
    }
    if (sort != null) {
      if (sort == 'price_asc') {
        query = query.orderBy('pricePerUnit', descending: false);
      } else if (sort == 'price_desc') {
        query = query.orderBy('pricePerUnit', descending: true);
      }
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => MaterialModel.fromMap(_queryDocData(doc))).toList());
  }

  Future<List<MaterialModel>> getApprovedSuppliersForMaterial(String materialName) async {
    final snap = await _db.collection('materials').where('name', isEqualTo: materialName).get();
    return snap.docs.map((doc) => MaterialModel.fromMap(doc.data())).toList();
  }

  /// Linked supplier UIDs for a company (`companies/{id}/suppliers`, with
  /// optional fallback to `approvedSuppliers` on the company document).
  Future<List<String>> getCompanyLinkedSupplierIds(String companyId) async {
    final suppliersSnap = await _db
        .collection('companies')
        .doc(companyId)
        .collection('suppliers')
        .get();

    if (suppliersSnap.docs.isNotEmpty) {
      return suppliersSnap.docs
          .where((doc) => _isActiveSupplierLink(doc.data()))
          .map((doc) => doc.id)
          .toList();
    }

    final companyDoc = await _db.collection('companies').doc(companyId).get();
    final approved = companyDoc.data()?['approvedSuppliers'];
    if (approved is List) {
      return approved
          .map((entry) => entry.toString())
          .where((id) => id.isNotEmpty)
          .toList();
    }
    return [];
  }

  bool _isActiveSupplierLink(Map<String, dynamic> data) {
    final status = (data['status'] as String?)?.toLowerCase() ?? 'active';
    return status == 'active' || status == 'approved';
  }

  String _normalizeMaterialName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Materials matching [materialName] from suppliers linked to [companyId].
  Future<List<MaterialModel>> getCompanyMaterialsByName(
    String companyId,
    String materialName,
  ) async {
    return getMaterialsByNameForCompany(companyId, materialName);
  }

  /// Materials from company-linked suppliers whose name matches [name].
  Future<List<MaterialModel>> getMaterialsByNameForCompany(
    String companyId,
    String name,
  ) async {
    final nameLower = _normalizeMaterialName(name);
    if (nameLower.isEmpty) return [];

    final supplierIds = await getCompanyLinkedSupplierIds(companyId);
    if (supplierIds.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var i = 0; i < supplierIds.length; i += 30) {
      chunks.add(
        supplierIds.sublist(
          i,
          i + 30 > supplierIds.length ? supplierIds.length : i + 30,
        ),
      );
    }

    final matched = <MaterialModel>[];
    final seenIds = <String>{};

    void addMatches(Iterable<MaterialModel> items) {
      for (final material in items) {
        if (seenIds.add(material.id)) {
          matched.add(material);
        }
      }
    }

    for (final chunk in chunks) {
      final bySupplierId = await _db
          .collection('materials')
          .where('supplierId', whereIn: chunk)
          .get();
      addMatches(
        bySupplierId.docs
            .map((doc) => _materialFromDoc(doc.id, doc.data()))
            .where(
              (material) =>
                  _normalizeMaterialName(material.name) == nameLower,
            ),
      );

      final bySupplierUid = await _db
          .collection('materials')
          .where('supplierUid', whereIn: chunk)
          .get();
      addMatches(
        bySupplierUid.docs
            .map((doc) => _materialFromDoc(doc.id, doc.data()))
            .where(
              (material) =>
                  _normalizeMaterialName(material.name) == nameLower,
            ),
      );
    }
    return matched;
  }

  /// Materials from [supplierId] when that supplier is linked to [companyId].
  Future<List<MaterialModel>> getCompanyMaterialsBySupplier(
    String companyId,
    String supplierId,
  ) async {
    final link = await _db
        .collection('companies')
        .doc(companyId)
        .collection('suppliers')
        .doc(supplierId)
        .get();
    if (!link.exists) return [];
    final linkData = link.data();
    if (linkData == null || !_isActiveSupplierLink(linkData)) return [];

    final snap = await _db
        .collection('materials')
        .where('supplierId', isEqualTo: supplierId)
        .get();
    return snap.docs
        .map((doc) => MaterialModel.fromMap(doc.data()))
        .toList();
  }

  /// Average rating from the ratings collection, matching supplier_viewmodel logic.
  Future<double> getSupplierAverageRating(String supplierUid) async {
    final stats = await getSupplierRatingStats(supplierUid);
    return stats.average;
  }

  /// Aggregated rating + review count in a single ratings query.
  Future<({double average, int count})> getSupplierRatingStats(
    String supplierUid,
  ) async {
    final snap = await _db
        .collection('ratings')
        .where('supplierUid', isEqualTo: supplierUid)
        .get();
    if (snap.docs.isEmpty) {
      final supplierDoc = await _db.collection('suppliers').doc(supplierUid).get();
      return (
        average: (supplierDoc.data()?['rating'] as num?)?.toDouble() ?? 0.0,
        count: 0,
      );
    }
    final ratings = snap.docs
        .map((doc) => RatingModel.fromMap(doc.id, doc.data()));
    final sum = ratings.fold<double>(0, (acc, r) => acc + r.rating);
    return (average: sum / snap.docs.length, count: snap.docs.length);
  }

  /// Most recent priceHistory timestamp for a material listing.
  Future<DateTime?> getLatestMaterialPriceTimestamp(String materialId) async {
    final snap = await _db
        .collection('materials')
        .doc(materialId)
        .collection('priceHistory')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final ts = snap.docs.first.data()['timestamp'];
    if (ts is Timestamp) return ts.toDate();
    return DateTime.tryParse(ts?.toString() ?? '');
  }

  Future<void> saveMaterial(MaterialModel material) async {
    await _db.collection('materials').doc(material.id).set(material.toMap());
  }

  Future<void> deleteMaterial(String id) async {
    await _db.collection('materials').doc(id).delete();
  }

  // --- Categories ---
  Future<List<CategoryModel>> getCategories() async {
    final snap = await _db.collection('categories').get();
    final categories = snap.docs
        .map((doc) => CategoryModel.fromDoc(doc.id, doc.data()))
        .where((c) => c.id.isNotEmpty && c.name.isNotEmpty && c.isActive)
        .toList();
    categories.sort((a, b) => a.name.compareTo(b.name));
    return categories;
  }

  // --- Orders ---
  Stream<List<OrderModel>> streamOrdersByCompany(String companyId) {
    return _db
        .collection('orders')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<OrderModel>> streamOrdersBySupplier(String supplierId) {
    return _db
        .collection('orders')
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> saveOrder(OrderModel order) async {
    await _db.collection('orders').doc(order.orderId).set(order.toMap());
  }

  // --- Chat Messages ---
  Stream<List<ChatMessageModel>> streamChats(String uid1, String uid2) {
    return _db
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatMessageModel.fromMap(doc.data()))
            .where((msg) =>
                msg.content.isNotEmpty &&
                ((msg.senderId == uid1 && msg.receiverId == uid2) ||
                    (msg.senderId == uid2 && msg.receiverId == uid1)))
            .toList());
  }

  Stream<List<ChatThreadModel>> streamFieldUserChatThreads(
    String companyId,
    String fieldUserId,
  ) {
    return _db
        .collection('chats')
        .where('isThread', isEqualTo: true)
        .where('companyId', isEqualTo: companyId)
        .where('fieldUserId', isEqualTo: fieldUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                ChatThreadModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // REQUIRES Firestore index: chats
  // Fields: isThread ASC, supplierId ASC, lastMessageAt DESC
  // Create at Firebase Console → Firestore → Indexes
  Stream<List<ChatThreadModel>> streamSupplierChatThreads(
    String supplierId,
  ) {
    return _db
        .collection('chats')
        .where('isThread', isEqualTo: true)
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatThreadModel.fromMap(
                  doc.id,
                  doc.data(),
                ))
            .toList());
  }

  Future<void> markChatThreadReadForSupplier(String chatId) async {
    await _db.collection('chats').doc(chatId).set(
      {'unreadSupplier': 0},
      SetOptions(merge: true),
    );
  }

  Stream<List<ChatMessageModel>> streamChatMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatMessageModel.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                  'chatId': chatId,
                }))
            .toList());
  }

  Future<void> ensureChatThread(ChatThreadModel thread) async {
    final ref = _db.collection('chats').doc(thread.chatId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set(thread.toMap());
      return;
    }
    if (thread.fieldUserName.isNotEmpty) {
      final existing = doc.data()?['fieldUserName'] as String? ?? '';
      if (existing.isEmpty) {
        await ref.set(
          {'fieldUserName': thread.fieldUserName},
          SetOptions(merge: true),
        );
      }
    }
  }

  Future<String> saveChatMessage(ChatMessageModel message) async {
    final chatId = message.chatId;
    if (chatId == null || chatId.isEmpty) {
      throw ArgumentError('chatId is required to save a message');
    }
    final ref = _db.collection('chats').doc(chatId).collection('messages').doc();
    await ref.set(message.toMap());
    return ref.id;
  }

  Future<void> markChatMessagesRead(String chatId, String currentUserId) async {
    final snap = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    var pending = 0;
    for (final doc in snap.docs) {
      final senderId = doc.data()['senderId'] as String? ?? '';
      if (senderId != currentUserId) {
        batch.update(doc.reference, {'isRead': true});
        pending++;
      }
    }
    if (pending > 0) {
      await batch.commit();
    }
  }

  Future<void> updateChatThreadAfterMessage({
    required String chatId,
    required String companyId,
    required String lastMessage,
    required String lastSenderId,
    required String fieldUserId,
    required String supplierId,
    String? fieldUserName,
  }) async {
    final threadRef = _db.collection('chats').doc(chatId);
    final isFromFieldUser = lastSenderId == fieldUserId;
    await threadRef.set({
      'isThread': true,
      'chatId': chatId,
      'companyId': companyId,
      'fieldUserId': fieldUserId,
      'supplierId': supplierId,
      if (fieldUserName != null && fieldUserName.isNotEmpty)
        'fieldUserName': fieldUserName,
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': lastSenderId,
      if (isFromFieldUser)
        'unreadSupplier': FieldValue.increment(1)
      else
        'unreadFieldUser': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> markChatThreadReadForFieldUser(String chatId) async {
    await _db.collection('chats').doc(chatId).set({
      'unreadFieldUser': 0,
    }, SetOptions(merge: true));
  }

  // --- Ratings ---
  Stream<List<RatingModel>> streamSupplierRatings(String supplierId) {
    return _db
        .collection('ratings')
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RatingModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> saveRating(RatingModel rating) async {
    await _db.collection('ratings').doc(rating.id).set(rating.toMap());
  }

  // --- Subscriptions ---
  Future<SubscriptionModel?> getSubscription(String companyId) async {
    final doc = await _db.collection('subscriptions').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      return SubscriptionModel.fromMap(companyId, _requireDocData(doc));
    }
    return null;
  }

  Stream<SubscriptionModel?> streamSubscription(String companyId) {
    return _db.collection('subscriptions').doc(companyId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return SubscriptionModel.fromMap(companyId, _requireDocData(doc));
      }
      return null;
    });
  }

  Future<void> saveSubscription(SubscriptionModel sub) async {
    await _db.collection('subscriptions').doc(sub.companyId).set(sub.toMap(), SetOptions(merge: true));
  }

  Future<void> updateSubscriptionHistory(String companyId, SubscriptionHistoryEntry entry) async {
    await _db.collection('subscriptions').doc(companyId).update({
      'history': FieldValue.arrayUnion([entry.toMap()]),
    });
  }

  // --- Price Indices ---
  Stream<List<PriceHistoryModel>> streamPriceHistory() {
    return _db.collection('priceHistory').snapshots().map((snap) =>
        snap.docs.map((doc) => PriceHistoryModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> savePriceHistory(PriceHistoryModel price) async {
    await _db.collection('priceHistory').doc(price.histId).set(price.toMap());
  }

  // --- Invitations ---
  Future<InvitationModel?> getInvitationByCode(String code) async {
    final snap = await _db
        .collection('invitations')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return InvitationModel.fromMap(snap.docs.first.id, snap.docs.first.data());
    }
    return null;
  }

  Future<void> saveInvitation(InvitationModel invite) async {
    await _db.collection('invitations').doc(invite.token).set(invite.toMap());
  }

  // --- Join Requests ---
  Stream<List<JoinRequestModel>> streamJoinRequests(String companyId) {
    return _db
        .collection('joinRequests')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => JoinRequestModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> saveJoinRequest(JoinRequestModel req) async {
    await _db.collection('joinRequests').doc(req.reqId).set(req.toMap());
  }

  // --- Notifications ---
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => NotificationModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> saveNotification(NotificationModel notif) async {
    await _db.collection('notifications').doc(notif.notifId).set(notif.toMap());
  }

  /// Archives a price change under `materials/{materialId}/priceHistory`
  /// (same path used by the supplier panel when editing material prices).
  Future<void> archiveMaterialPriceChange({
    required String materialId,
    required double previousPrice,
    required double newPrice,
    String? supplierUid,
  }) async {
    final changePercent = previousPrice > 0
        ? ((newPrice - previousPrice) / previousPrice * 100)
        : 0.0;
    final payload = {
      'materialId': materialId,
      if (supplierUid != null) 'supplierUid': supplierUid,
      'price': newPrice,
      'previousPrice': previousPrice,
      'changePercent': double.parse(changePercent.toStringAsFixed(1)),
      'timestamp': FieldValue.serverTimestamp(),
      'recordedAt': FieldValue.serverTimestamp(),
    };

    await _db
        .collection('materials')
        .doc(materialId)
        .collection('priceHistory')
        .add(payload);

    if (supplierUid != null && supplierUid.isNotEmpty) {
      await _db
          .collection('suppliers')
          .doc(supplierUid)
          .collection('materials')
          .doc(materialId)
          .collection('priceHistory')
          .add({
        'price': newPrice,
        'recordedAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Initial price entry when a supplier first lists a material.
  Future<void> recordInitialMaterialPrice({
    required String materialId,
    required double price,
    String? supplierUid,
  }) async {
    final payload = {
      'materialId': materialId,
      if (supplierUid != null) 'supplierUid': supplierUid,
      'price': price,
      'timestamp': FieldValue.serverTimestamp(),
      'recordedAt': FieldValue.serverTimestamp(),
    };

    await _db
        .collection('materials')
        .doc(materialId)
        .collection('priceHistory')
        .add(payload);

    if (supplierUid != null && supplierUid.isNotEmpty) {
      await _db
          .collection('suppliers')
          .doc(supplierUid)
          .collection('materials')
          .doc(materialId)
          .collection('priceHistory')
          .add({
        'price': price,
        'recordedAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<List<PriceHistoryModel>> getMaterialPriceHistorySince(
    String materialId,
    DateTime since, {
    String? companyId,
    String? supplierUid,
  }) async {
    final entries = <PriceHistoryModel>[];
    final seen = <String>{};

    void addDoc(String id, Map<String, dynamic> data) {
      final key = '$id@${data['timestamp'] ?? data['recordedAt']}';
      if (!seen.add(key)) return;
      entries.add(PriceHistoryModel.fromMap(id, {
        ...data,
        'materialId': materialId,
        if (supplierUid != null && (data['supplierUid'] == null || data['supplierUid'] == ''))
          'supplierUid': supplierUid,
      }));
    }

    final materialSnap = await _db
        .collection('materials')
        .doc(materialId)
        .collection('priceHistory')
        .get();
    for (final doc in materialSnap.docs) {
      addDoc(doc.id, doc.data());
    }

    if (companyId != null && companyId.isNotEmpty) {
      final companySnap = await _db
          .collection('companies')
          .doc(companyId)
          .collection('materials')
          .doc(materialId)
          .collection('priceHistory')
          .get();
      for (final doc in companySnap.docs) {
        addDoc('company_${doc.id}', doc.data());
      }
    }

    if (supplierUid != null && supplierUid.isNotEmpty) {
      final supplierSnap = await _db
          .collection('suppliers')
          .doc(supplierUid)
          .collection('materials')
          .doc(materialId)
          .collection('priceHistory')
          .get();
      for (final doc in supplierSnap.docs) {
        addDoc('supplier_${doc.id}', doc.data());
      }
    }

    return entries
        .where((entry) => !entry.timestamp.isBefore(since))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Price history for a single material listing + supplier, last [months], ascending.
  Future<List<PriceHistoryModel>> getMaterialPriceHistoryForSupplier({
    required String materialId,
    required String supplierUid,
    int months = 6,
    String? companyId,
  }) async {
    final since = DateTime.now().subtract(Duration(days: months * 30));
    final entries = await getMaterialPriceHistorySince(
      materialId,
      since,
      companyId: companyId,
      supplierUid: supplierUid,
    );
    return entries
        .where((e) => e.supplierUid.isEmpty || e.supplierUid == supplierUid)
        .toList();
  }

  /// Merged price history across approved suppliers for [materialName], last [months].
  Future<List<PriceHistoryModel>> getCompanyMaterialPriceTrend({
    required String companyId,
    required String materialName,
    int months = 6,
  }) async {
    final materials = await getMaterialsByNameForCompany(companyId, materialName);
    if (materials.isEmpty) return [];

    final since = DateTime.now().subtract(Duration(days: months * 30));
    final all = <PriceHistoryModel>[];
    for (final material in materials) {
      all.addAll(
        await getMaterialPriceHistorySince(
          material.id,
          since,
          companyId: companyId,
          supplierUid: material.supplierId,
        ),
      );
    }
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }
}
