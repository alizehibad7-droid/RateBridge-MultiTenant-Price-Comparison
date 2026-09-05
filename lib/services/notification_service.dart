import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../repositories/notification_repository.dart';

/// Central helper for creating in-app notifications in the top-level 'notifications' collection.
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
  static const typeRating = 'rating';
  static const typeDispute = 'dispute';
  static const typeApproval = 'approval';

  Future<void> _create({
    required String recipientUserId,
    required String recipientRole,
    required String type,
    required String title,
    required String message,
    String? senderUserId,
    String? companyId,
    Map<String, dynamic> data = const {},
  }) async {
    final id = '${recipientUserId}_${DateTime.now().microsecondsSinceEpoch}';
    
    // Ensure data contains useful info for navigation
    final extendedData = Map<String, dynamic>.from(data);
    if (companyId != null) extendedData['companyId'] = companyId;
    if (senderUserId != null) extendedData['senderUserId'] = senderUserId;

    await _repo.createNotification(
      NotificationModel(
        notifId: id,
        recipientUserId: recipientUserId,
        recipientRole: recipientRole,
        type: type,
        title: title,
        message: message,
        data: extendedData,
        isRead: false,
        createdAt: DateTime.now(),
        senderUserId: senderUserId,
        companyId: companyId,
      ),
    );
  }

  /// Helper to get user info for notification delivery.
  Future<UserModel?> _getUser(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
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
      recipientUserId: ceoUid,
      recipientRole: 'CEO',
      type: typeOrderUpdate,
      title: 'Order awaiting approval',
      message: '$fieldUserName requested $materialName — review and approve',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'status': AppConstants.statusPendingApproval,
        'relatedId': orderId,
        'relatedCollection': 'orders',
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
      recipientUserId: ceoUid,
      recipientRole: 'CEO',
      type: typeOrderUpdate,
      title: 'Order Auto-Approved',
      message: 'Order for $materialName (Rs. ${totalAmount.toStringAsFixed(0)}) was auto-approved per your threshold.',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'status': AppConstants.statusPending,
        'relatedId': orderId,
        'relatedCollection': 'orders',
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
      recipientUserId: fieldUserUid,
      recipientRole: 'Field User',
      type: typeOrderUpdate,
      title: 'Order accepted',
      message: '$supplierName accepted your order for $materialName',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'status': 'accepted',
        'relatedId': orderId,
        'relatedCollection': 'orders',
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
      recipientUserId: fieldUserUid,
      recipientRole: 'Field User',
      type: typeOrderUpdate,
      title: 'Order rejected',
      message: '$supplierName rejected your order for $materialName$reasonText',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'status': 'rejected',
        'relatedId': orderId,
        'relatedCollection': 'orders',
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
      recipientUserId: fieldUserUid,
      recipientRole: 'Field User',
      type: typeOrderUpdate,
      title: 'Order delivered',
      message: 'Your order for $materialName has been delivered by $supplierName. Please confirm.',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'status': 'delivered',
        'relatedId': orderId,
        'relatedCollection': 'orders',
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
      recipientUserId: supplierId,
      recipientRole: 'Supplier',
      type: typeNewOrder,
      title: 'New order received',
      message: '$fieldUserName ordered $materialName',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'status': 'pending',
        'relatedId': orderId,
        'relatedCollection': 'orders',
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
      recipientUserId: supplierId,
      recipientRole: 'Supplier',
      type: typeOrderUpdate,
      title: 'Delivery confirmed',
      message: '$fieldUserName confirmed delivery of $materialName',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'status': 'confirmed',
        'relatedId': orderId,
        'relatedCollection': 'orders',
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
      recipientUserId: supplierId,
      recipientRole: 'Supplier',
      type: typeOrderUpdate,
      title: 'Order cancelled',
      message: '$fieldUserName cancelled the order for $materialName',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'status': 'cancelled',
        'relatedId': orderId,
        'relatedCollection': 'orders',
      },
    );
  }

  // --- Admin Notifications ---

  Future<void> notifyAllAdmins({
    required String title,
    required String message,
    String? type,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      // Expanded role matching to handle case variations in Firestore
      final query = await _db
          .collection('users')
          .where('role', whereIn: [
            'Admin', 'admin', 'ADMIN', 
            'Administrator', 'administrator', 'ADMINISTRATOR'
          ])
          .get();
      
      developer.log('Notifying ${query.docs.length} admins: $title');
      
      for (var doc in query.docs) {
        await _create(
          recipientUserId: doc.id,
          recipientRole: 'Admin',
          type: type ?? typeApproval,
          title: title,
          message: message,
          data: data,
        );
      }
    } catch (e) {
      developer.log('Error notifying all admins: $e');
    }
  }

  Future<void> notifyNewRegistration({
    required String adminUid,
    required String name,
    required String role,
    required String targetUid,
  }) async {
    await _create(
      recipientUserId: adminUid,
      recipientRole: 'Admin',
      type: typeApproval,
      title: 'New $role Registration',
      message: '$name is awaiting approval',
      data: {
        'uid': targetUid, 
        'role': role,
        'relatedId': targetUid,
        'relatedCollection': 'users',
      },
    );
  }

  Future<void> notifyAllAdminsOfNewRegistration({
    required String name,
    required String role,
    required String targetUid,
  }) async {
    await notifyAllAdmins(
      title: 'New $role Registration',
      message: '$name is awaiting approval',
      type: typeApproval,
      data: {
        'uid': targetUid, 
        'role': role,
        'relatedId': targetUid,
        'relatedCollection': 'users',
      },
    );
  }

  Future<void> notifyDisputeRaised({
    required String adminUid,
    required String orderId,
    required String companyId,
    required String raisedByRole,
  }) async {
    await _create(
      recipientUserId: adminUid,
      recipientRole: 'Admin',
      type: typeDispute,
      title: 'New Dispute Raised',
      message: 'A dispute was raised for order $orderId by a $raisedByRole.',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'relatedId': orderId,
        'relatedCollection': 'orders',
      },
    );
  }

  Future<void> notifyDisputeResolved({
    required String recipientUid,
    required String recipientRole,
    required String orderId,
    required String companyId,
    required String status,
    required String resolutionNotes,
  }) async {
    final rejected = status.trim().toLowerCase() == 'rejected';
    final outcome = rejected ? 'rejected' : 'resolved';
    final notes = resolutionNotes.trim();
    await _create(
      recipientUserId: recipientUid,
      recipientRole: recipientRole,
      type: typeDispute,
      title: rejected ? 'Dispute rejected' : 'Dispute resolved',
      message: notes.isEmpty
          ? 'Your dispute for order $orderId was $outcome.'
          : 'Your dispute for order $orderId was $outcome. $notes',
      companyId: companyId,
      data: {
        'orderId': orderId,
        'status': status,
        'relatedId': orderId,
        'relatedCollection': 'orders',
      },
    );
  }

  Future<void> notifySubscriptionPaymentSubmitted({
    required String adminUserId,
    required String companyName,
    required String companyId,
  }) async {
    await _create(
      recipientUserId: adminUserId,
      recipientRole: 'Admin',
      type: typePayment,
      title: 'New subscription payment',
      message: 'New subscription payment from $companyName',
      companyId: companyId,
      data: {
        'companyName': companyName,
        'relatedId': companyId,
        'relatedCollection': 'companies',
      },
    );
  }

  Future<void> notifyCommissionThreshold({
    required String adminUserId,
    required double outstandingAmount,
    required double threshold,
    required String supplierId,
  }) async {
    await _create(
      recipientUserId: adminUserId,
      recipientRole: 'Admin',
      type: typeCommission,
      title: 'Commission threshold exceeded',
      message: 'Outstanding commission Rs. ${outstandingAmount.toStringAsFixed(0)} exceeds threshold of Rs. ${threshold.toStringAsFixed(0)}',
      data: {
        'outstandingAmount': outstandingAmount,
        'threshold': threshold,
        'supplierId': supplierId,
        'relatedId': supplierId,
        'relatedCollection': 'suppliers',
      },
    );
  }

  // --- Partnership Notifications ---

  Future<void> notifyPartnershipInvitation({
    required String recipientUserId,
    required String companyName,
    required String requestId,
    required String companyId,
  }) async {
    final user = await _getUser(recipientUserId);
    await _create(
      recipientUserId: recipientUserId,
      recipientRole: user?.role ?? 'Supplier',
      type: typePartnership,
      title: 'Partnership invitation',
      message: '📩 $companyName has sent you a partnership invitation. Tap to respond.',
      companyId: companyId,
      data: {
        'requestId': requestId,
        'companyName': companyName,
        'event': 'invitation_received',
        'relatedId': requestId,
        'relatedCollection': 'partnershipRequests',
      },
    );
  }

  Future<void> notifyPartnershipAccepted({
    required String recipientUserId,
    required String senderName,
    required String companyId,
  }) async {
    final user = await _getUser(recipientUserId);
    await _create(
      recipientUserId: recipientUserId,
      recipientRole: user?.role ?? 'CEO',
      type: typePartnership,
      title: 'Partnership accepted',
      message: '✅ $senderName accepted your partnership request!',
      companyId: companyId,
      data: {
        'event': 'accepted',
        'senderName': senderName,
      },
    );
  }

  Future<void> notifyPartnershipDeclined({
    required String recipientUserId,
    required String senderName,
    required String companyId,
  }) async {
    final user = await _getUser(recipientUserId);
    await _create(
      recipientUserId: recipientUserId,
      recipientRole: user?.role ?? 'CEO',
      type: typePartnership,
      title: 'Partnership declined',
      message: '❌ $senderName declined your partnership request.',
      companyId: companyId,
      data: {
        'event': 'declined',
        'senderName': senderName,
      },
    );
  }

  Future<void> notifyPartnershipRemoved({
    required String recipientUserId,
    required String companyName,
    required String companyId,
  }) async {
    final user = await _getUser(recipientUserId);
    await _create(
      recipientUserId: recipientUserId,
      recipientRole: user?.role ?? 'Supplier',
      type: typePartnership,
      title: 'Partnership removed',
      message: 'The partnership with $companyName has been terminated.',
      companyId: companyId,
      data: {
        'event': 'removed',
        'companyName': companyName,
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
      recipientUserId: supplierId,
      recipientRole: 'Supplier',
      type: typeRFQ,
      title: 'New RFQ Available',
      message: '$companyName is looking for $category. Submit your bid now!',
      data: {
        'rfqId': rfqId,
        'companyName': companyName,
        'relatedId': rfqId,
        'relatedCollection': 'rfqs',
      },
    );
  }

  Future<void> notifySupplierNewRating({
    required String supplierId,
    required double rating,
    required String fieldUserName,
    required String materialName,
    required String orderId,
    String comment = '',
  }) async {
    final stars = rating == rating.roundToDouble()
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1);
    final excerpt = comment.trim();
    final excerptBit = excerpt.isEmpty
        ? ''
        : ' “${excerpt.length > 80 ? '${excerpt.substring(0, 80)}…' : excerpt}”';
    await _create(
      recipientUserId: supplierId,
      recipientRole: 'Supplier',
      type: typeRating,
      title: 'New rating received',
      message:
          '$fieldUserName rated you $stars/5 for $materialName.$excerptBit',
      data: {
        'orderId': orderId,
        'rating': rating,
        'materialName': materialName,
        'relatedId': orderId,
        'relatedCollection': 'orders',
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
      recipientUserId: ceoUid,
      recipientRole: 'CEO',
      type: typeRFQ,
      title: 'New Bid for $category',
      message: '$supplierName has submitted a bid for your quote request.',
      companyId: companyId,
      data: {
        'rfqId': rfqId,
        'supplierName': supplierName,
        'relatedId': rfqId,
        'relatedCollection': 'rfqs',
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
      recipientUserId: supplierId,
      recipientRole: 'Supplier',
      type: typeRFQ,
      title: awarded ? 'RFQ Awarded! ✅' : 'RFQ Closed',
      message: awarded
          ? 'Congratulations! $companyName has awarded you the contract for $category.'
          : 'The RFQ for $category from $companyName has been closed.',
      data: {
        'rfqId': rfqId,
        'awarded': awarded.toString(),
        'relatedId': rfqId,
        'relatedCollection': 'rfqs',
      },
    );
  }

  // --- Payment/Subscription Triggers for CEO ---

  Future<void> notifySubscriptionDecision({
    required String ceoUid,
    required String title,
    required String message,
    required String companyId,
    Map<String, dynamic> data = const {},
  }) async {
    await _create(
      recipientUserId: ceoUid,
      recipientRole: 'CEO',
      type: typePayment,
      title: title,
      message: message,
      companyId: companyId,
      data: data,
    );
  }

  Future<void> notifyPaymentStatus({
    required String userId,
    required String title,
    required String message,
    String? companyId,
    Map<String, dynamic> data = const {},
  }) async {
    final user = await _getUser(userId);
    await _create(
      recipientUserId: userId,
      recipientRole: user?.role ?? 'User',
      type: typePayment,
      title: title,
      message: message,
      companyId: companyId,
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
    final user = await _getUser(recipientUserId);
    await _create(
      recipientUserId: recipientUserId,
      recipientRole: user?.role ?? 'User',
      type: typeChat,
      title: senderName,
      message: preview,
      companyId: companyId,
      senderUserId: fieldUserId == recipientUserId ? supplierId : fieldUserId,
      data: {
        'chatId': chatId,
        'fieldUserId': fieldUserId,
        'fieldUserName': fieldUserName,
        'supplierUid': supplierId,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'relatedId': chatId,
        'relatedCollection': 'chats',
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
      },
    );
  }
}
