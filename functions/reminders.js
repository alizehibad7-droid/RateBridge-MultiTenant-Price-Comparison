const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Daily scheduled function to remind CEOs of orders pending approval.
 * Runs once a day.
 */
exports.scheduledOrderApprovalReminders = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const now = Date.now();
    const oneDayMs = 24 * 60 * 60 * 1000;
    const twoDaysMs = 48 * 60 * 60 * 1000;

    try {
      // Orders live at companies/{companyId}/orders (see FirestorePaths.companyOrdersCol),
      // not a top-level `orders` collection. Collection group query is required.
      // Requires a COLLECTION_GROUP index on orders.status (see firestore.indexes.json
      // fieldOverrides). If deploy/runtime fails, Cloud Functions logs include a
      // one-time Firestore URL to auto-create the missing index.
      const pendingOrdersSnap = await db.collectionGroup('orders')
        .where('status', '==', 'pending_approval')
        .get();

      if (pendingOrdersSnap.empty) {
        console.log('No pending orders found.');
        return null;
      }

      const reminders = [];

      for (const orderDoc of pendingOrdersSnap.docs) {
        const order = orderDoc.data();
        const createdAt = order.createdAt.toMillis();
        const pendingDurationMs = now - createdAt;

        // Prefer the companyId field on the order document (OrderModel stores it);
        // fall back to companies/{companyId}/orders/{orderId} via the parent doc.
        // Optional chain: a top-level orders/{id} doc has no parent.parent.
        const companyId = (typeof order.companyId === 'string' && order.companyId)
          ? order.companyId
          : orderDoc.ref.parent.parent?.id;

        if (!companyId) continue;

        // Check if lastReminderSentAt was today (to avoid spam)
        const lastReminder = order.lastReminderSentAt ? order.lastReminderSentAt.toMillis() : 0;
        const sentToday = (now - lastReminder) < oneDayMs;

        if (sentToday) continue;

        let reminderType = null;
        let durationText = '';

        if (pendingDurationMs >= twoDaysMs) {
          reminderType = 'over_48h';
          durationText = 'more than 48 hours';
        } else if (pendingDurationMs >= oneDayMs) {
          reminderType = 'over_24h';
          durationText = 'more than 24 hours';
        }

        if (reminderType) {
          reminders.push({
            orderId: orderDoc.id,
            companyId,
            materialName: order.materialName,
            durationText,
            orderRef: orderDoc.ref,
          });
        }
      }

      for (const r of reminders) {
        // Resolve CEO UID
        const companyDoc = await db.collection('companies').doc(r.companyId).get();
        const ceoUid = companyDoc.data()?.ceoUid;

        if (ceoUid) {
          // Create notification document (this triggers FCM via onNotificationCreated)
          await db.collection('notifications').add({
            userId: ceoUid,
            type: 'order_reminder',
            title: 'Approval Reminder',
            body: `Order for ${r.materialName} has been pending for ${r.durationText}. Please review and approve.`,
            data: {
              orderId: r.orderId,
              companyId: r.companyId,
            },
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Update order with lastReminderSentAt (must use the sub-collection doc ref)
          await r.orderRef.update({
            lastReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      console.log(`Sent ${reminders.length} reminders.`);
    } catch (error) {
      console.error('scheduledOrderApprovalReminders error:', error);
    }

    return null;
  });
