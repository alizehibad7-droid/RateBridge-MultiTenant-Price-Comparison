import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_details_config.dart';
import '../models/subscription_model.dart';
import '../models/subscription_payment_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class SubscriptionPaymentRepository {
  final FirestoreService _firestore;
  final NotificationService _notifications;

  SubscriptionPaymentRepository(this._firestore, this._notifications);

  static const _paymentConfigPath = 'platform_config/payment_details';
  static const _paymentsCollection = 'subscription_payments';

  Future<PaymentDetailsConfig> getPaymentDetails() async {
    final snap = await FirebaseFirestore.instance.doc(_paymentConfigPath).get();
    return PaymentDetailsConfig.fromMap(snap.data());
  }

  Future<void> savePaymentDetails(PaymentDetailsConfig config) async {
    await FirebaseFirestore.instance.doc(_paymentConfigPath).set(
          config.toMap(),
          SetOptions(merge: true),
        );
  }

  Stream<List<SubscriptionPaymentModel>> watchPendingPayments() {
    return FirebaseFirestore.instance
        .collection(_paymentsCollection)
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SubscriptionPaymentModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<SubscriptionPaymentModel?> watchLatestCompanyPayment(String companyId) {
    return FirebaseFirestore.instance
        .collection(_paymentsCollection)
        .where('companyId', isEqualTo: companyId)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return SubscriptionPaymentModel.fromMap(doc.id, doc.data());
    });
  }

  Future<String> submitPayment(SubscriptionPaymentModel payment) async {
    final ref =
        FirebaseFirestore.instance.collection(_paymentsCollection).doc();
    await ref.set(payment.toMap());
    return ref.id;
  }

  Future<void> notifyAdminsNewPayment(String companyName) async {
    final admins = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['admin', 'Admin', 'administrator'])
        .get();

    for (final doc in admins.docs) {
      await _notifications.notifySubscriptionPaymentSubmitted(
        adminUserId: doc.id,
        companyName: companyName,
      );
    }
  }

  Future<void> notifyCeo({
    required String ceoUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _notifications.notifySubscriptionDecision(
      ceoUid: ceoUid,
      title: title,
      body: body,
      data: data ?? {},
    );
  }

  Future<String?> resolveCeoUid(String companyId) async {
    final company = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get();
    final ceoUid = company.data()?['ceoUid'] as String?;
    if (ceoUid != null && ceoUid.isNotEmpty) return ceoUid;

    final users = await FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'CEO')
        .limit(1)
        .get();
    if (users.docs.isEmpty) return null;
    return users.docs.first.id;
  }

  Future<void> approvePayment({
    required SubscriptionPaymentModel payment,
    required String adminUid,
    required PlanDefinition plan,
  }) async {
    final now = DateTime.now();
    final expiry = now.add(Duration(days: plan.durationDays));

    final subscription = SubscriptionModel(
      companyId: payment.companyId,
      plan: plan.planKey,
      status: 'active',
      startedAt: now,
      expiresAt: expiry,
      adminGranted: false,
    );
    await _firestore.saveSubscription(subscription);

    await _firestore.updateSubscriptionHistory(
      payment.companyId,
      SubscriptionHistoryEntry(
        plan: plan.planKey,
        action: 'purchased',
        date: now,
        amountPaid: payment.amount,
        note: 'Manual payment approved',
      ),
    );

    await FirebaseFirestore.instance
        .collection(_paymentsCollection)
        .doc(payment.id)
        .update({
      'status': 'approved',
      'reviewedByUid': adminUid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('companies')
        .doc(payment.companyId)
        .set({'plan': plan.planKey}, SetOptions(merge: true));

    final ceoUid = await resolveCeoUid(payment.companyId);
    if (ceoUid != null) {
      await notifyCeo(
        ceoUid: ceoUid,
        title: 'Subscription activated',
        body: 'Your ${plan.name} subscription is now active.',
        data: {'companyId': payment.companyId, 'plan': plan.planKey},
      );
    }
  }

  Future<void> rejectPayment({
    required SubscriptionPaymentModel payment,
    required String adminUid,
    required String reason,
  }) async {
    await FirebaseFirestore.instance
        .collection(_paymentsCollection)
        .doc(payment.id)
        .update({
      'status': 'rejected',
      'rejectionReason': reason.trim(),
      'reviewedByUid': adminUid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    final ceoUid = await resolveCeoUid(payment.companyId);
    if (ceoUid != null) {
      await notifyCeo(
        ceoUid: ceoUid,
        title: 'Subscription payment rejected',
        body: reason.trim().isEmpty
            ? 'Your subscription payment was rejected.'
            : reason.trim(),
        data: {
          'companyId': payment.companyId,
          'plan': payment.plan,
          'rejectionReason': reason.trim(),
        },
      );
    }
  }
}
