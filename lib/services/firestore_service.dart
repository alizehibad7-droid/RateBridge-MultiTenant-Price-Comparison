import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../models/supplier_model.dart';
import '../models/material_model.dart';
import '../models/order_model.dart';
import '../models/chat_message_model.dart';
import '../models/rating_model.dart';
import '../models/subscription_model.dart';
import '../models/price_history_model.dart';
import '../models/invitation_model.dart';
import '../models/join_request_model.dart';
import '../models/notification_model.dart';
import '../models/category_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Users ---
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
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
      final data = doc.data() as Map<String, dynamic>;
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
        snap.docs.map((doc) => SupplierModel.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> saveSupplier(SupplierModel supplier) async {
    await _db.collection('suppliers').doc(supplier.id).set(supplier.toMap());
  }

  // --- Materials ---
  Stream<List<MaterialModel>> streamMaterials() {
    return _db.collection('materials').snapshots().map((snap) =>
        snap.docs.map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Stream<List<MaterialModel>> streamCompanyMaterials(String companyId) {
    return _db.collection('companies').doc(companyId).collection('suppliers').snapshots().asyncMap((suppliersSnap) async {
      final supplierIds = suppliersSnap.docs.map((doc) => doc.id).toList();
      if (supplierIds.isEmpty) return [];

      final chunks = <List<String>>[];
      for (var i = 0; i < supplierIds.length; i += 30) {
        chunks.add(supplierIds.sublist(i, i + 30 > supplierIds.length ? supplierIds.length : i + 30));
      }

      final allMaterials = <MaterialModel>[];
      for (final chunk in chunks) {
        final materialsSnap = await _db.collection('materials')
            .where('supplierId', whereIn: chunk)
            .get();
        allMaterials.addAll(materialsSnap.docs.map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>)));
      }
      return allMaterials;
    });
  }

  Future<List<MaterialModel>> getPopularMaterials() async {
    final snap = await _db.collection('materials').limit(10).get();
    return snap.docs.map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  Future<List<MaterialModel>> getMaterialsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final snap = await _db.collection('materials').where(FieldPath.documentId, whereIn: ids).get();
    return snap.docs.map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  Future<List<MaterialModel>> searchMaterials(String query) async {
    final snap = await _db
        .collection('materials')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snap.docs.map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  Stream<List<MaterialModel>> streamCategoryMaterials(String category, {String? companyId, Map<String, dynamic>? filters, String? sort}) {
    if (companyId != null) {
      return _db.collection('companies').doc(companyId).collection('suppliers').snapshots().asyncMap((suppliersSnap) async {
        final supplierIds = suppliersSnap.docs.map((doc) => doc.id).toList();
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
          filteredMaterials.addAll(materialsSnap.docs.map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>)));
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
      if (sort == 'price_asc') query = query.orderBy('pricePerUnit', descending: false);
      else if (sort == 'price_desc') query = query.orderBy('pricePerUnit', descending: true);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Future<List<MaterialModel>> getApprovedSuppliersForMaterial(String materialName) async {
    final snap = await _db.collection('materials').where('name', isEqualTo: materialName).get();
    return snap.docs.map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
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
    return snap.docs.map((doc) => CategoryModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  // --- Orders ---
  Stream<List<OrderModel>> streamOrdersByCompany(String companyId) {
    return _db
        .collection('orders')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  Stream<List<OrderModel>> streamOrdersBySupplier(String supplierId) {
    return _db
        .collection('orders')
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
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
            .map((doc) => ChatMessageModel.fromMap(doc.data() as Map<String, dynamic>))
            .where((msg) =>
                (msg.senderId == uid1 && msg.receiverId == uid2) ||
                (msg.senderId == uid2 && msg.receiverId == uid1))
            .toList());
  }

  Future<void> saveChatMessage(ChatMessageModel message) async {
    await _db.collection('chats').doc(message.id).set(message.toMap());
  }

  // --- Ratings ---
  Stream<List<RatingModel>> streamSupplierRatings(String supplierId) {
    return _db
        .collection('ratings')
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RatingModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> saveRating(RatingModel rating) async {
    await _db.collection('ratings').doc(rating.id).set(rating.toMap());
  }

  // --- Subscriptions ---
  Future<SubscriptionModel?> getSubscription(String companyId) async {
    final doc = await _db.collection('subscriptions').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      return SubscriptionModel.fromMap(companyId, doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  Stream<SubscriptionModel?> streamSubscription(String companyId) {
    return _db.collection('subscriptions').doc(companyId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return SubscriptionModel.fromMap(companyId, doc.data() as Map<String, dynamic>);
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
        snap.docs.map((doc) => PriceHistoryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
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
      return InvitationModel.fromMap(snap.docs.first.id, snap.docs.first.data() as Map<String, dynamic>);
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
        .map((snap) => snap.docs.map((doc) => JoinRequestModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
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
        .map((snap) => snap.docs.map((doc) => NotificationModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> saveNotification(NotificationModel notif) async {
    await _db.collection('notifications').doc(notif.notifId).set(notif.toMap());
  }
}
