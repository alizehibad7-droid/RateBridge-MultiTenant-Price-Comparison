const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();
const { evaluateSupplierCommissionStatus } = require('./commission_restrictions');

const COMMISSION_RATE = 0.02;

function normalizeStatus(value) {
  return String(value || '').toLowerCase().trim();
}

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

/**
 * Source of truth for commission owed: one transactions/{comm_orderId} row
 * per confirmed order. Gross/net on the Earnings screen still come from orders.
 *
 * Must not skip just because orders.commissionDeducted is already true — the
 * field-user confirm path used to set that flag before this function created
 * the transaction, which left owed at 0.
 */
async function ensureCommissionForConfirmedOrder(orderId, orderRef, liveOrder) {
  if (!liveOrder || normalizeStatus(liveOrder.status) !== 'confirmed') {
    return null;
  }

  const supplierUid = liveOrder.supplierId || liveOrder.supplierUid;
  if (!supplierUid) {
    console.error(`Commission skip: order ${orderId} has no supplier id`);
    return null;
  }

  const totalAmount = Number(liveOrder.totalAmount || 0);
  if (!Number.isFinite(totalAmount) || totalAmount <= 0) {
    console.error(`Commission skip: order ${orderId} has invalid totalAmount`);
    return null;
  }

  const commissionAmount = parseFloat((totalAmount * COMMISSION_RATE).toFixed(2));
  const supplierEarning = parseFloat((totalAmount - commissionAmount).toFixed(2));
  const txId = `comm_${orderId}`;
  const txRef = db.collection('transactions').doc(txId);

  const [txSnap, existingByOrder] = await Promise.all([
    txRef.get(),
    db.collection('transactions').where('orderId', '==', orderId).limit(5).get(),
  ]);

  const existingDocs = [];
  if (txSnap.exists) existingDocs.push(txSnap);
  for (const doc of existingByOrder.docs) {
    if (doc.id !== txId) existingDocs.push(doc);
  }

  if (existingDocs.length > 0) {
    const batch = db.batch();
    let patched = false;
    for (const doc of existingDocs) {
      const data = doc.data() || {};
      const patch = {};
      if (!data.supplierUid) patch.supplierUid = supplierUid;
      if (!data.status) patch.status = 'unsettled';
      const storedCommission = Number(data.commissionAmount || 0);
      if (storedCommission <= 0 && commissionAmount > 0) {
        patch.commissionAmount = commissionAmount;
        patch.commissionRate = COMMISSION_RATE;
        patch.supplierEarning = supplierEarning;
        patch.totalAmount = totalAmount;
      }
      if (Object.keys(patch).length) {
        batch.update(doc.ref, patch);
        patched = true;
      }
    }
    if (liveOrder.commissionDeducted !== true) {
      batch.update(orderRef, {
        commissionDeducted: true,
        commissionAmount,
        supplierEarning,
      });
      patched = true;
    }
    if (patched) await batch.commit();
    return { success: true, existing: true };
  }

  const monthKey = new Date().toISOString().substring(0, 7);
  const batch = db.batch();

  batch.update(orderRef, {
    commissionAmount,
    supplierEarning,
    commissionDeducted: true,
  });

  batch.set(txRef, {
    orderId,
    companyId: liveOrder.companyId || '',
    supplierUid,
    totalAmount,
    commissionRate: COMMISSION_RATE,
    commissionAmount,
    supplierEarning,
    status: 'unsettled',
    type: 'order_payment',
    month: monthKey,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  batch.set(
    db.collection('suppliers').doc(supplierUid),
    {
      totalEarnings: admin.firestore.FieldValue.increment(supplierEarning),
      totalOrders: admin.firestore.FieldValue.increment(1),
    },
    { merge: true },
  );

  const earningsRef = db
    .collection('suppliers')
    .doc(supplierUid)
    .collection('earnings')
    .doc(monthKey);
  batch.set(
    earningsRef,
    {
      gross: admin.firestore.FieldValue.increment(totalAmount),
      commission: admin.firestore.FieldValue.increment(commissionAmount),
      net: admin.firestore.FieldValue.increment(supplierEarning),
      orderCount: admin.firestore.FieldValue.increment(1),
    },
    { merge: true },
  );

  try {
    await batch.commit();
  } catch (error) {
    console.error('Commission financial batch error:', error);
    throw error;
  }

  evaluateSupplierCommissionStatus(supplierUid).catch((error) => {
    console.error('Post-commission restriction evaluation failed (non-fatal):', error);
  });

  try {
    const adminDocs = await findAdminUsers();
    await sendCommissionNotifications({
      supplierUid,
      adminDocs,
      orderId,
      companyId: liveOrder.companyId,
      txId,
      commissionAmount,
      supplierEarning,
    });
  } catch (error) {
    console.error('Commission notification error (non-fatal):', error);
  }

  return { success: true };
}

async function backfillConfirmedOrdersForSupplier(supplierUid) {
  if (!supplierUid) return { processed: 0 };

  const [bySupplierId, bySupplierUid] = await Promise.all([
    db.collection('orders').where('supplierId', '==', supplierUid).where('status', '==', 'confirmed').get(),
    db.collection('orders').where('supplierUid', '==', supplierUid).where('status', '==', 'confirmed').get(),
  ]);

  const orders = new Map();
  for (const doc of bySupplierId.docs) orders.set(doc.id, doc);
  for (const doc of bySupplierUid.docs) orders.set(doc.id, doc);

  let processed = 0;
  for (const doc of orders.values()) {
    await ensureCommissionForConfirmedOrder(doc.id, doc.ref, doc.data());
    processed += 1;
  }
  return { processed };
}

exports.ensureCommissionForConfirmedOrder = ensureCommissionForConfirmedOrder;

exports.onOrderConfirmed = functions.firestore
  .document('orders/{orderId}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;
    const liveOrder = change.after.data();
    if (normalizeStatus(liveOrder.status) !== 'confirmed') return null;
    return ensureCommissionForConfirmedOrder(
      context.params.orderId,
      change.after.ref,
      liveOrder,
    );
  });

exports.onCommissionEnsureJobCreated = functions.firestore
  .document('commission_ensure_jobs/{jobId}')
  .onWrite(async (change) => {
    if (!change.after.exists) return null;
    const job = change.after.data() || {};
    if (job.status && job.status !== 'pending') return null;

    const supplierUid = job.uid || job.supplierUid;
    try {
      const result = await backfillConfirmedOrdersForSupplier(supplierUid);
      await change.after.ref.set(
        {
          status: 'complete',
          processed: result.processed,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } catch (error) {
      console.error('onCommissionEnsureJobCreated failed:', error);
      await change.after.ref.set(
        {
          status: 'error',
          error: error.message || 'Could not ensure commission transactions.',
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    return null;
  });
