import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../constants/firestore_paths.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../repositories/notification_repository.dart';

/// Central helper for creating in-app notifications.
/// FCM pushes are triggered server-side via Cloud Functions when these docs are created.
class NotificationService {
  final NotificationRepository _repo;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  NotificationService(this._repo);

  static const typeChat = 'chat';
  static const typeOrderUpdate = 'orderUpdate';
  static const typeNewOrder = 'newOrder';
  static const typePayment = 'payment';
  static const typeCommission = 'commission';
  static const typePartnership = 'partnership';
  static const typeRFQ = 'rfq';
  static const typeDispute = 'dispute';
  static const typeApproval = 'approval';

  Future<void> _create({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? path,
    Map<String, dynamic> data = const {},
  }) async {
    final id = '${userId}_${DateTime.now().microsecondsSinceEpoch}';
    await _repo.createNotification(
      NotificationModel(
        notifId: id,
        userId: userId,
        type: type,
        title: title,
        body: body,
        data: data,
        isRead: false,
        createdAt: DateTime.now(),
      ),
      path: path,
    );
  }

  /// Helper to determine notification path based on user role and company.
  Future<String?> _getPathForUser(String userId) async {
    try {
      final doc = await _db.collection(FirestorePaths.usersCol).doc(userId).get();
      if (!doc.exists) return null;
      final user = UserModel.fromMap(doc.data()!);
      
      final role = user.role.toLowerCase();
      if (role == 'admin' || role == 'administrator') return FirestorePaths.adminNotificationsCol;
      if (role == 'supplier') return FirestorePaths.supplierNotificationsCol(userId);
      if (user.companyId.isNotEmpty) return FirestorePaths.companyNotificationsCol(user.companyId);
    } catch (_) {}
    return null;
  }

  // --- Order & Delivery Notifications ---

  Future<void> notifyOrderPendingApproval({
    required String ceoUid,
    required String orderId,
    required String companyId,
    required String materialName,
    required String fieldUserName,
  }) async {
    await _create(
      userId: ceoUid,
      type: typeOrderUpdate,
      title: 'Order awaiting approval',
      body: '$fieldUserName requested $materialName — review and approve',
      path: FirestorePaths.companyNotificationsCol(companyId),
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': AppConstants.statusPendingApproval,
      },
    );
  }

  Future<void> notifyOrderAutoApproved({
    required String ceoUid,
    required String orderId,
    required String companyId,
    required String materialName,
    required double totalAmount,
  }) async {
    await _create(
      userId: ceoUid,
      type: typeOrderUpdate,
      title: 'Order Auto-Approved',
      body:
          'Order for $materialName (Rs. ${totalAmount.toStringAsFixed(0)}) was auto-approved per your threshold.',
      path: FirestorePaths.companyNotificationsCol(companyId),
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': AppConstants.statusPending,
      },
    );
  }

  Future<void> notifyOrderAccepted({
    required String fieldUserUid,
    required String orderId,
    required String companyId,
    required String materialName,
    required String supplierName,
  }) async {
    await _create(
      userId: fieldUserUid,
      type: typeOrderUpdate,
      title: 'Order accepted',
      body: '$supplierName accepted your order for $materialName',
      path: FirestorePaths.companyNotificationsCol(companyId),
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': 'accepted',
      },
    );
  }

  Future<void> notifyOrderRejected({
    required String fieldUserUid,
    required String orderId,
    required String companyId,
    required String materialName,
    required String supplierName,
    required String reason,
  }) async {
    final reasonText = reason.trim().isEmpty ? '' : ': ${reason.trim()}';
    await _create(
      userId: fieldUserUid,
      type: typeOrderUpdate,
      title: 'Order rejected',
      body: '$supplierName rejected your order for $materialName$reasonText',
      path: FirestorePaths.companyNotificationsCol(companyId),
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': 'rejected',
        if (reason.trim().isNotEmpty) 'rejectionReason': reason.trim(),
      },
    );
  }

  Future<void> notifyOrderDelivered({
    required String fieldUserUid,
    required String orderId,
    required String companyId,
    required String materialName,
    required String supplierName,
  }) async {
    await _create(
      userId: fieldUserUid,
      type: typeOrderUpdate,
      title: 'Order delivered',
      body: 'Your order has been delivered. Please confirm.',
      path: FirestorePaths.companyNotificationsCol(companyId),
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': 'delivered',
      },
    );
  }

  Future<void> notifyNewOrder({
    required String supplierId,
    required String orderId,
    required String companyId,
    required String materialName,
    required String fieldUserName,
  }) async {
    await _create(
      userId: supplierId,
      type: typeNewOrder,
      title: 'New order received',
      body: '$fieldUserName ordered $materialName',
      path: FirestorePaths.supplierNotificationsCol(supplierId),
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': 'pending',
      },
    );
  }

  Future<void> notifyDeliveryConfirmed({
    required String supplierId,
    required String orderId,
    required String companyId,
    required String materialName,
    required String fieldUserName,
  }) async {
    await _create(
      userId: supplierId,
      type: typeOrderUpdate,
      title: 'Delivery confirmed',
      body: '$fieldUserName confirmed delivery of $materialName',
      path: FirestorePaths.supplierNotificationsCol(supplierId),
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': 'confirmed',
      },
    );
  }

  Future<void> notifyOrderCancelled({
    required String supplierId,
    required String orderId,
    required String companyId,
    required String materialName,
    required String fieldUserName,
  }) async {
    await _create(
      userId: supplierId,
      type: typeOrderUpdate,
      title: 'Order cancelled',
      body: '$fieldUserName cancelled the order for $materialName',
      path: FirestorePaths.supplierNotificationsCol(supplierId),
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': 'cancelled',
      },
    );
  }

  // --- Admin Notifications ---

  Future<void> notifyNewRegistration({
    required String adminUid,
    required String name,
    required String role,
    required String targetUid,
  }) async {
    await _create(
      userId: adminUid,
      type: typeApproval,
      title: 'New $role Registration',
      body: '$name is awaiting approval',
      path: FirestorePaths.adminNotificationsCol,
      data: {'uid': targetUid, 'role': role},
    );
  }

  Future<void> notifyAllAdminsOfNewRegistration({
    required String name,
    required String role,
    required String targetUid,
  }) async {
    try {
      final query = await _db
          .collection(FirestorePaths.usersCol)
          .where('role', whereIn: ['Admin', 'admin', 'Administrator', 'administrator'])
          .get();
      
      for (var doc in query.docs) {
        await notifyNewRegistration(
          adminUid: doc.id,
          name: name,
          role: role,
          targetUid: targetUid,
        );
      }
    } catch (e) {
      print('Error notifying admins: $e');
    }
  }

  Future<void> notifyDisputeRaised({
    required String adminUid,
    required String orderId,
    required String companyId,
    required String raisedByRole,
  }) async {
    await _create(
      userId: adminUid,
      type: typeDispute,
      title: 'New Dispute Raised',
      body: 'A dispute was raised for order $orderId by a $raisedByRole.',
      path: FirestorePaths.adminNotificationsCol,
      data: {
        'orderId': orderId,
        'companyId': companyId,
      },
    );
  }

  Future<void> notifySubscriptionPaymentSubmitted({
    required String adminUserId,
    required String companyName,
  }) async {
    await _create(
      userId: adminUserId,
      type: typePayment,
      title: 'New subscription payment',
      body: 'New subscription payment from $companyName',
      path: FirestorePaths.adminNotificationsCol,
      data: {'companyName': companyName},
    );
  }

  Future<void> notifyCommissionThreshold({
    required String adminUserId,
    required double outstandingAmount,
    required double threshold,
  }) async {
    await _create(
      userId: adminUserId,
      type: typeCommission,
      title: 'Commission threshold exceeded',
      body:
          'Outstanding commission Rs. ${outstandingAmount.toStringAsFixed(0)} exceeds threshold of Rs. ${threshold.toStringAsFixed(0)}',
      path: FirestorePaths.adminNotificationsCol,
      data: {
        'outstandingAmount': outstandingAmount,
        'threshold': threshold,
      },
    );
  }

  // --- Partnership Notifications ---

  Future<void> notifyPartnershipInvitation({
    required String supplierId,
    required String companyName,
    required String requestId,
    required String companyId,
  }) async {
    await _create(
      userId: supplierId,
      type: typePartnership,
      title: 'Partnership invitation',
      body: '📩 $companyName has sent you a partnership invitation. Tap to respond.',
      path: FirestorePaths.supplierNotificationsCol(supplierId),
      data: {
        'requestId': requestId,
        'companyId': companyId,
        'companyName': companyName,
        'event': 'invitation_received',
      },
    );
  }

  Future<void> notifyPartnershipAccepted({
    required String supplierId,
    required String companyName,
    required String companyId,
  }) async {
    await _create(
      userId: supplierId,
      type: typePartnership,
      title: 'Partnership accepted',
      body: '✅ $companyName accepted your partnership request! You can now supply to their team.',
      path: FirestorePaths.supplierNotificationsCol(supplierId),
      data: {
        'companyId': companyId,
        'companyName': companyName,
        'event': 'accepted',
      },
    );
  }

  Future<void> notifyPartnershipDeclined({
    required String supplierId,
    required String companyName,
    required String companyId,
  }) async {
    await _create(
      userId: supplierId,
      type: typePartnership,
      title: 'Partnership declined',
      body: '❌ $companyName declined your partnership request. You can send a new request after 7 days.',
      path: FirestorePaths.supplierNotificationsCol(supplierId),
      data: {
        'companyId': companyId,
        'companyName': companyName,
        'event': 'declined',
      },
    );
  }

  Future<void> notifyPartnershipRemoved({
    required String supplierId,
    required String companyName,
    required String companyId,
  }) async {
    await _create(
      userId: supplierId,
      type: typePartnership,
      title: 'Partnership removed',
      body: '⚠️ $companyName has removed the partnership. Your materials are no longer visible to their field team.',
      path: FirestorePaths.supplierNotificationsCol(supplierId),
      data: {
        'companyId': companyId,
        'companyName': companyName,
        'event': 'removed',
      },
    );
  }

  // --- RFQ Notifications ---

  Future<void> notifyNewRfqAvailable({
    required String supplierId,
    required String rfqId,
    required String category,
    required String companyName,
  }) async {
    await _create(
      userId: supplierId,
      type: typeRFQ,
      title: 'New RFQ Available',
      body: '$companyName is looking for $category. Submit your bid now!',
      path: FirestorePaths.supplierNotificationsCol(supplierId),
      data: {
        'rfqId': rfqId,
        'companyName': companyName,
      },
    );
  }

  Future<void> notifyNewBidReceived({
    required String ceoUid,
    required String rfqId,
    required String supplierName,
    required String category,
    required String companyId,
  }) async {
    await _create(
      userId: ceoUid,
      type: typeRFQ,
      title: 'New Bid for $category',
      body: '$supplierName has submitted a bid for your quote request.',
      path: FirestorePaths.companyNotificationsCol(companyId),
      data: {
        'rfqId': rfqId,
        'supplierName': supplierName,
      },
    );
  }

  Future<void> notifyRfqClosed({
    required String supplierId,
    required String rfqId,
    required String category,
    required String companyName,
    required bool awarded,
  }) async {
    await _create(
      userId: supplierId,
      type: typeRFQ,
      title: awarded ? 'RFQ Awarded! ✅' : 'RFQ Closed',
      body: awarded
          ? 'Congratulations! $companyName has awarded you the contract for $category.'
          : 'The RFQ for $category from $companyName has been closed.',
      path: FirestorePaths.supplierNotificationsCol(supplierId),
      data: {
        'rfqId': rfqId,
        'awarded': awarded.toString(),
      },
    );
  }

  // --- Payment/Subscription Triggers for CEO ---

  Future<void> notifySubscriptionDecision({
    required String ceoUid,
    required String title,
    required String body,
    required String companyId,
    Map<String, dynamic> data = const {},
  }) async {
    await _create(
      userId: ceoUid,
      type: typePayment,
      title: title,
      body: body,
      path: FirestorePaths.companyNotificationsCol(companyId),
      data: data,
    );
  }

  // --- Chat Notifications ---

  Future<void> notifyChatMessage({
    required String recipientUserId,
    required String senderName,
    required String preview,
    required String chatId,
    required String companyId,
    required String fieldUserId,
    required String fieldUserName,
    required String supplierId,
    required String supplierName,
    String? orderId,
  }) async {
    final path = await _getPathForUser(recipientUserId);
    await _create(
      userId: recipientUserId,
      type: typeChat,
      title: senderName,
      body: preview,
      path: path,
      data: {
        'chatId': chatId,
        'companyId': companyId,
        'fieldUserId': fieldUserId,
        'fieldUserName': fieldUserName,
        'supplierUid': supplierId,
        'supplierId': supplierId,
        'supplierName': supplierName,
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
      },
    );
  }
}
