import '../constants/app_constants.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

/// Central helper for creating in-app notifications (FCM is sent server-side
/// when a notification document is created).
class NotificationService {
  final NotificationRepository _repo;

  NotificationService(this._repo);

  static const typeChat = 'chat';
  static const typeOrderUpdate = 'orderUpdate';
  static const typeNewOrder = 'newOrder';
  static const typePayment = 'payment';
  static const typeCommission = 'commission';
  static const typePartnership = 'partnership';

  Future<void> _create({
    required String userId,
    required String type,
    required String title,
    required String body,
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
    );
  }

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
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': AppConstants.statusPendingApproval,
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
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': 'pending',
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
    final reasonText =
        reason.trim().isEmpty ? '' : ': ${reason.trim()}';
    await _create(
      userId: fieldUserUid,
      type: typeOrderUpdate,
      title: 'Order rejected',
      body: '$supplierName rejected your order for $materialName$reasonText',
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
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': 'delivered',
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
      data: {
        'orderId': orderId,
        'companyId': companyId,
        'status': 'cancelled',
      },
    );
  }

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
    await _create(
      userId: recipientUserId,
      type: typeChat,
      title: senderName,
      body: preview,
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

  Future<void> notifySubscriptionPaymentSubmitted({
    required String adminUserId,
    required String companyName,
  }) async {
    await _create(
      userId: adminUserId,
      type: typePayment,
      title: 'New subscription payment',
      body: 'New subscription payment from $companyName',
      data: {'companyName': companyName},
    );
  }

  Future<void> notifySubscriptionDecision({
    required String ceoUid,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    await _create(
      userId: ceoUid,
      type: typePayment,
      title: title,
      body: body,
      data: data,
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
      data: {
        'outstandingAmount': outstandingAmount,
        'threshold': threshold,
      },
    );
  }

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
      body:
          '✅ $companyName accepted your partnership request! You can now supply to their team.',
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
      body:
          '❌ $companyName declined your partnership request. You can send a new request after 7 days.',
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
      body:
          '⚠️ $companyName has removed the partnership. Your materials are no longer visible to their field team.',
      data: {
        'companyId': companyId,
        'companyName': companyName,
        'event': 'removed',
      },
    );
  }
}
