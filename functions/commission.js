const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();
const { evaluateSupplierCommissionStatus } = require('./commission_restrictions');

const COMMISSION_RATE = 0.02;

async function findAdminUsers() {
  const adminQuery = await db
    .collection('users')
    .where('role', 'in', ['admin', 'Admin', 'administrator'])
    .limit(5)
    .get();
  return adminQuery.docs;
}

async function sendCommissionNotifications({
  supplierUid,
  adminDocs,
  orderId,
  companyId,
  txId,
  commissionAmount,
  supplierEarning,
}) {
  const batch = db.batch();

  const supplierNotifRef = db.collection('notifications').doc();
  batch.set(supplierNotifRef, {
    userId: supplierUid,
    type: 'commission',
    title: 'Commission Deducted',
    body: `Order confirmed. Rs. ${commissionAmount.toLocaleString()} commission deducted. Net: Rs. ${supplierEarning.toLocaleString()}`,
    data: { orderId, companyId, txId },
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  for (const adminDoc of adminDocs) {
    const adminNotifRef = db.collection('notifications').doc();
    batch.set(adminNotifRef, {
      userId: adminDoc.id,
      type: 'commission',
      title: 'Commission Received',
      body: `Rs. ${commissionAmount.toLocaleString()} commission from order ${orderId}`,
      data: { orderId, companyId, txId },
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
}

exports.onOrderConfirmed = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger when status changes TO 'confirmed'
    if (before.status === after.status || after.status !== 'confirmed') {
      return null;
    }

    const { orderId } = context.params;
    const orderRef = change.after.ref;

    // Fresh live read — do not rely on the stale event snapshot for idempotency.
    const liveOrderSnap = await orderRef.get();
    if (!liveOrderSnap.exists) return null;
    const liveOrder = liveOrderSnap.data();
    if (liveOrder.commissionDeducted === true) return null;

    const existingTx = await db
      .collection('transactions')
      .where('orderId', '==', orderId)
      .limit(1)
      .get();
    if (!existingTx.empty) {
      if (liveOrder.commissionDeducted !== true) {
        await orderRef.update({ commissionDeducted: true });
      }
      return null;
    }

    const companyId = liveOrder.companyId;
    const totalAmount = liveOrder.totalAmount;
    const commissionAmount = parseFloat((totalAmount * COMMISSION_RATE).toFixed(2));
    const supplierEarning = parseFloat((totalAmount - commissionAmount).toFixed(2));
    const supplierUid = liveOrder.supplierId || liveOrder.supplierUid;
    const txId = db.collection('transactions').doc().id;
    const monthKey = new Date().toISOString().substring(0, 7); // YYYY-MM

    const batch = db.batch();

    batch.update(orderRef, {
      commissionAmount,
      supplierEarning,
      commissionDeducted: true,
    });

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

    batch.update(db.collection('suppliers').doc(supplierUid), {
      totalEarnings: admin.firestore.FieldValue.increment(supplierEarning),
      totalOrders: admin.firestore.FieldValue.increment(1),
    });

    const earningsRef = db.collection('suppliers').doc(supplierUid)
      .collection('earnings').doc(monthKey);
    batch.set(earningsRef, {
      gross: admin.firestore.FieldValue.increment(totalAmount),
      commission: admin.firestore.FieldValue.increment(commissionAmount),
      net: admin.firestore.FieldValue.increment(supplierEarning),
      orderCount: admin.firestore.FieldValue.increment(1),
    }, { merge: true });

    try {
      await batch.commit();
    } catch (error) {
      console.error('Commission financial batch error:', error);
      throw error;
    }

    evaluateSupplierCommissionStatus(supplierUid).catch((error) => {
      console.error('Post-commission restriction evaluation failed (non-fatal):', error);
    });

    // Notifications are best-effort only — must never cause financial reprocessing.
    try {
      const adminDocs = await findAdminUsers();
      await sendCommissionNotifications({
        supplierUid,
        adminDocs,
        orderId,
        companyId,
        txId,
        commissionAmount,
        supplierEarning,
      });
    } catch (error) {
      console.error('Commission notification error (non-fatal):', error);
    }

    return { success: true };
  });
