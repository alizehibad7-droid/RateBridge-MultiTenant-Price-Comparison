const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Daily scheduled function to remind CEOs of orders pending approval.
 * Also alerts Admins if an order is stuck for more than 48 hours.
 */
exports.scheduledOrderApprovalReminders = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const now = Date.now();
    const oneDayMs = 24 * 60 * 60 * 1000;
    const twoDaysMs = 48 * 60 * 60 * 1000;

    try {
      // Collection group query handles orders living in per-company sub-collections.
      const pendingOrdersSnap = await db.collectionGroup('orders')
        .where('status', '==', 'pending_approval')
        .get();

      if (pendingOrdersSnap.empty) {
        console.log('No pending orders found.');
        return null;
      }

      // Helper to get all Admin UIDs
      const adminQuery = await db.collection('users')
        .where('role', 'in', ['admin', 'Admin', 'administrator', 'Administrator'])
        .get();
      const adminUids = adminQuery.docs.map(doc => doc.id);

      for (const orderDoc of pendingOrdersSnap.docs) {
        const order = orderDoc.data();
        if (!order.createdAt) continue;
        
        const createdAt = order.createdAt.toMillis();
        const pendingDurationMs = now - createdAt;
        const companyId = order.companyId || orderDoc.ref.parent.parent?.id;

        if (!companyId) continue;

        // Check if lastReminderSentAt was today (to avoid spamming)
        const lastReminder = order.lastReminderSentAt ? order.lastReminderSentAt.toMillis() : 0;
        const sentToday = (now - lastReminder) < oneDayMs;
        if (sentToday) continue;

        const companyDoc = await db.collection('companies').doc(companyId).get();
        const companyName = companyDoc.data()?.name || companyId;
        const ceoUid = companyDoc.data()?.ceoUid;

        // 1. Notify CEO for 24h+ and 48h+
        if (pendingDurationMs >= oneDayMs && ceoUid) {
          const durationText = pendingDurationMs >= twoDaysMs ? '48 hours' : '24 hours';
          
          await db.collection(`companies/${companyId}/notifications`).add({
            userId: ceoUid,
            type: 'orderUpdate',
            title: 'Order Awaiting Approval',
            body: `Order for ${order.materialName} has been pending for more than ${durationText}. Please review.`,
            data: { 
                orderId: orderDoc.id, 
                companyId,
                screen: 'order_details' 
            },
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // 2. Notify Admin for 48h+ (Critical Escalation)
        if (pendingDurationMs >= twoDaysMs) {
          for (const adminUid of adminUids) {
            await db.collection('adminNotifications').add({
              userId: adminUid,
              type: 'orderUpdate',
              title: 'Stuck Order — Action Required',
              body: `Order ${orderDoc.id} (${companyName}) has been pending approval for 48+ hours.`,
              data: { 
                  orderId: orderDoc.id, 
                  companyId,
                  screen: 'order_details' 
              },
              isRead: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }

        // Update order with lastReminderSentAt
        await orderDoc.ref.update({
          lastReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

    } catch (error) {
      console.error('scheduledOrderApprovalReminders error:', error);
    }

    return null;
  });
