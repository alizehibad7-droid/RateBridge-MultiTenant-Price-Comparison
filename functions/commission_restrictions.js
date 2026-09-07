const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();
const OVERDUE_DAYS = 7;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

function normalizeOverride(value) {
  return String(value || 'none').trim().toLowerCase();
}

function toMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

/**
 * Reads the restriction flag already stored on a supplier document.
 * Admin overrides: force_allow / exempt, or force_restrict.
 */
function isSupplierCommissionRestricted(supplier) {
  if (!supplier) return false;
  const override = normalizeOverride(supplier.commissionRestrictionOverride);
  if (override === 'force_allow' || override === 'exempt') return false;
  if (override === 'force_restrict') return true;
  return supplier.commissionRestricted === true;
}

async function evaluateSupplierCommissionStatus(supplierUid) {
  if (!supplierUid) return null;

  const supplierRef = db.collection('suppliers').doc(supplierUid);
  const supplierSnap = await supplierRef.get();
  if (!supplierSnap.exists) return null;

  const supplier = supplierSnap.data() || {};
  const unsettledSnap = await db
    .collection('transactions')
    .where('supplierUid', '==', supplierUid)
    .where('status', '==', 'unsettled')
    .get();

  let outstanding = 0;
  let oldestMs = null;
  for (const doc of unsettledSnap.docs) {
    const tx = doc.data() || {};
    outstanding += Number(tx.commissionAmount || 0);
    const createdMs = toMillis(tx.createdAt);
    if (createdMs && (oldestMs == null || createdMs < oldestMs)) {
      oldestMs = createdMs;
    }
  }

  const oldestDays =
    oldestMs == null
      ? 0
      : Math.max(0, Math.floor((Date.now() - oldestMs) / MS_PER_DAY));
  const overdue = outstanding > 0 && oldestDays >= OVERDUE_DAYS;

  const override = normalizeOverride(supplier.commissionRestrictionOverride);
  let restricted = overdue;
  let reason = overdue
    ? `Outstanding commission is ${oldestDays} day(s) overdue.`
    : admin.firestore.FieldValue.delete();

  if (override === 'force_allow' || override === 'exempt') {
    restricted = false;
    reason = admin.firestore.FieldValue.delete();
  } else if (override === 'force_restrict') {
    restricted = true;
    if (!overdue) reason = 'Restricted by admin.';
  }

  const wasRestricted = supplier.commissionRestricted === true;
  await supplierRef.update({
    commissionRestricted: restricted,
    commissionRestrictionReason: reason,
    commissionOutstandingAmount: Math.round(outstanding * 100) / 100,
    commissionOldestUnsettledDays: oldestDays,
    commissionRestrictionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (restricted && !wasRestricted) {
    await db.collection('notifications').add({
      userId: supplierUid,
      type: 'commission',
      title: 'Account restricted',
      body:
        'Your listings are hidden and bulk-quote bidding is paused until outstanding commission is settled.',
      data: { screen: 'earnings' },
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return { restricted, outstanding, oldestDays };
}

exports.isSupplierCommissionRestricted = isSupplierCommissionRestricted;
exports.evaluateSupplierCommissionStatus = evaluateSupplierCommissionStatus;

exports.scheduledCommissionOverdueCheck = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const [unsettledSnap, restrictedSnap] = await Promise.all([
      db.collection('transactions').where('status', '==', 'unsettled').get(),
      db.collection('suppliers').where('commissionRestricted', '==', true).get(),
    ]);

    const uids = new Set();
    for (const doc of unsettledSnap.docs) {
      const uid = doc.data()?.supplierUid;
      if (uid) uids.add(uid);
    }
    for (const doc of restrictedSnap.docs) {
      uids.add(doc.id);
    }

    for (const uid of uids) {
      try {
        await evaluateSupplierCommissionStatus(uid);
      } catch (error) {
        console.error(`Commission overdue check failed for ${uid}:`, error);
      }
    }
    return null;
  });

exports.onCommissionTransactionChange = functions.firestore
  .document('transactions/{txId}')
  .onWrite(async (change) => {
    const after = change.after.exists ? change.after.data() : null;
    const before = change.before.exists ? change.before.data() : null;
    const supplierUid = after?.supplierUid || before?.supplierUid;
    if (!supplierUid) return null;
    try {
      await evaluateSupplierCommissionStatus(supplierUid);
    } catch (error) {
      console.error(
        `Commission restriction update failed for ${supplierUid}:`,
        error,
      );
    }
    return null;
  });
