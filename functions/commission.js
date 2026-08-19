const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

const COMMISSION_RATE = 0.02;

exports.onOrderConfirmed = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger when status changes TO 'confirmed'
    if (before.status === after.status || after.status !== 'confirmed') {
      return null;
    }

    // Prevent double-processing
    if (after.commissionDeducted === true) return null;

    const { orderId } = context.params;
    const companyId = after.companyId;
    const totalAmount = after.totalAmount;
    const commissionAmount = parseFloat((totalAmount * COMMISSION_RATE).toFixed(2));
    const supplierEarning = parseFloat((totalAmount - commissionAmount).toFixed(2));
    const supplierUid = after.supplierId || after.supplierUid;
    const txId = db.collection('transactions').doc().id;
    const monthKey = new Date().toISOString().substring(0, 7); // YYYY-MM

    try {
      const batch = db.batch();

      // 1. Update order with commission details
      batch.update(change.after.ref, {
        commissionAmount,
        supplierEarning,
        commissionDeducted: true,
      });

      // 2. Create transaction record
      batch.set(db.collection('transactions').doc(txId), {
        orderId,
        companyId,
        supplierUid,
        totalAmount,
        commissionRate: COMMISSION_RATE,
        commissionAmount,
        supplierEarning,
        status: 'unsettled',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 3. Update supplier global earnings
      batch.update(db.collection('suppliers').doc(supplierUid), {
        totalEarnings: admin.firestore.FieldValue.increment(supplierEarning),
        totalOrders: admin.firestore.FieldValue.increment(1),
      });

      // 4. Update monthly earnings aggregate
      const earningsRef = db.collection('suppliers').doc(supplierUid)
        .collection('earnings').doc(monthKey);
      batch.set(earningsRef, {
        gross: admin.firestore.FieldValue.increment(totalAmount),
        commission: admin.firestore.FieldValue.increment(commissionAmount),
        net: admin.firestore.FieldValue.increment(supplierEarning),
        orderCount: admin.firestore.FieldValue.increment(1),
      }, { merge: true });

      await batch.commit();

      // 5. Send FCM notifications
      const supplierDoc = await db.collection('users').doc(supplierUid).get();
      const supplierData = supplierDoc.data();

      // Get admin UID
      const adminQuery = await db.collection('users').where('role', '==', 'admin').limit(1).get();
      const adminUid = adminQuery.empty ? null : adminQuery.docs[0].id;
      const adminData = adminQuery.empty ? null : adminQuery.docs[0].data();

      const notificationBatch = db.batch();

      // Notify supplier
      if (supplierData?.fcmToken) {
        await admin.messaging().send({
          token: supplierData.fcmToken,
          notification: {
            title: 'Order Confirmed — Commission Deducted',
            body: `Rs. ${commissionAmount.toLocaleString()} commission deducted. Net earnings: Rs. ${supplierEarning.toLocaleString()}`,
          },
          data: { type: 'commission', orderId, companyId },
          android: { channelId: 'payments_channel' },
        });
      }

      const supplierNotifRef = db.collection('companies').doc(companyId)
        .collection('notifications').doc();
      notificationBatch.set(supplierNotifRef, {
        userId: supplierUid,
        type: 'commission',
        title: 'Commission Deducted',
        body: `Order confirmed. Net: Rs. ${supplierEarning.toLocaleString()}`,
        data: { orderId, companyId, txId },
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify admin
      if (adminUid && adminData?.fcmToken) {
        await admin.messaging().send({
          token: adminData.fcmToken,
          notification: {
            title: 'Commission Received',
            body: `Rs. ${commissionAmount.toLocaleString()} commission from order ${orderId}`,
          },
          data: { type: 'commission', orderId, txId },
          android: { channelId: 'payments_channel' },
        });

        const adminNotifRef = db.collection('companies').doc(companyId)
          .collection('notifications').doc();
        notificationBatch.set(adminNotifRef, {
          userId: adminUid,
          type: 'commission',
          title: 'Commission Received',
          body: `Rs. ${commissionAmount.toLocaleString()} from order ${orderId}`,
          data: { orderId, companyId, txId },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await notificationBatch.commit();
      return { success: true };

    } catch (error) {
      console.error('Commission processing error:', error);
      throw error;
    }
  });
