// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/rating_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_exception.dart';

class OrderRepository {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  OrderRepository(this._firestoreService);

  Future<void> createOrder(OrderModel order) async {
    try {
      await _db
          .collection('orders')
          .doc(order.orderId)
          .set(order.toMap());
    } on FirebaseException catch (e) {
      throw AppException('Failed to create order: ${e.message}');
    }
  }

  Future<void> submitOrder(OrderModel order) => createOrder(order);

  /// Updates an order with partial data
  Future<void> updateOrder(String orderId, Map<String, dynamic> updates) async {
    try {
      await _db.collection('orders').doc(orderId).update(updates);
    } on FirebaseException catch (e) {
      throw AppException('Failed to update order: ${e.message}');
    }
  }

  Stream<List<OrderModel>> watchCompanyOrders(
    String companyId,
    String? statusFilter, {
    DocumentSnapshot? startAfter,
  }) {
    Query query = _db
        .collection('orders')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null && statusFilter != 'all' && statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<OrderModel>> watchSupplierOrders(
    String supplierUid,
    String companyId,
    String? statusFilter,
  ) {
    Query query = _db
        .collection('orders')
        .where('supplierId', isEqualTo: supplierUid)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null && statusFilter != 'all' && statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    } else {
      query = query.where('status', isNotEqualTo: 'pending_approval');
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<OrderModel>> getOrdersForSupplier(String supplierUid) {
    return _db
        .collection('orders')
        .where('supplierId', isEqualTo: supplierUid)
        .where('status', isNotEqualTo: 'pending_approval')
        .orderBy('status')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<List<OrderModel>> watchFieldUserOrders(
    String fieldUserUid,
    String companyId,
    String? statusFilter,
  ) {
    Query query = _db
        .collection('orders')
        .where('fieldUserUid', isEqualTo: fieldUserUid)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null && statusFilter != 'all' && statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<List<OrderModel>> getRecentFieldOrders(int limit) async {
    final snap = await _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
  }

  Future<void> updateStatus(
    String orderId,
    String companyId,
    String status, {
    String? reason,
    DateTime? deliveredAt,
    DateTime? confirmedAt,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'status': status.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (reason != null) updates['rejectionReason'] = reason;
      if (deliveredAt != null) updates['deliveredAt'] = Timestamp.fromDate(deliveredAt);
      if (confirmedAt != null) updates['confirmedAt'] = Timestamp.fromDate(confirmedAt);

      await _db
          .collection('orders')
          .doc(orderId)
          .update(updates);
    } on FirebaseException catch (e) {
      throw AppException('Failed to update order status: ${e.message}');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
     await _db
          .collection('orders')
          .doc(orderId)
          .update({
            'status': status.toLowerCase(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
  }

  Future<void> cancelOrder(String orderId, String companyId) async {
    try {
      final doc = await _db
          .collection('orders')
          .doc(orderId)
          .get();
      if (!doc.exists) throw AppException('Order not found');
      
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String;
      
      if (status != 'pending' && status != 'accepted' && status != 'pending_approval') {
        throw AppException('Cannot cancel order in $status status');
      }
      await updateStatus(orderId, companyId, 'cancelled');
    } on FirebaseException catch (e) {
      throw AppException('Failed to cancel order: ${e.message}');
    }
  }

  Future<bool> hasRatingForOrder(String orderId, String companyId) async {
    final snapshot = await _db
        .collection('ratings')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> submitRating(String orderId, String companyId, RatingModel rating) async {
    try {
      await _db
          .collection('ratings')
          .doc(rating.id)
          .set(rating.toMap());
    } on FirebaseException catch (e) {
      throw AppException('Failed to submit rating: ${e.message}');
    }
  }

  Future<void> updateSupplierAvgRating(String supplierUid, RatingModel rating) async {
    try {
      await _db.runTransaction((transaction) async {
        final supplierRef = _db.collection('suppliers').doc(supplierUid);
        final supplierDoc = await transaction.get(supplierRef);
        
        if (supplierDoc.exists) {
          final data = supplierDoc.data()!;
          final double currentAvg = (data['rating'] as num?)?.toDouble() ?? 0.0;
          final int currentCount = (data['activeContracts'] as num?)?.toInt() ?? 0;
          
          final int newCount = currentCount + 1;
          final double newAvg = ((currentAvg * currentCount) + rating.rating) / newCount;
          
          transaction.update(supplierRef, {
            'rating': newAvg,
            'activeContracts': newCount,
          });
        }
      });
    } on FirebaseException catch (e) {
      throw AppException('Failed to update supplier rating: ${e.message}');
    }
  }

  Stream<List<RatingModel>> watchSupplierRatings(String supplierUid) {
    return _db
        .collection('ratings')
        .where('supplierUid', isEqualTo: supplierUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }
}
