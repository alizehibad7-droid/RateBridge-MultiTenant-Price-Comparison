const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();
const validTypes = new Set([
  'wrongMaterial',
  'damagedGoods',
  'quantityMismatch',
  'nonDelivery',
  'paymentIssue',
  'other',
]);
const validStatuses = new Set(['under_review', 'resolved']);

function normalize(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeRole(value) {
  return normalize(value).replace(/[\s_]/g, '');
}

function requiredText(value, label, maxLength) {
  const text = String(value || '').trim();
  if (!text) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${label} is required.`,
    );
  }
  if (text.length > maxLength) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${label} is too long.`,
    );
  }
  return text;
}

async function authenticatedUser(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be signed in.',
    );
  }
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists || normalize(userDoc.data().status) !== 'active') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Your account is not active.',
    );
  }
  return { uid: context.auth.uid, user: userDoc.data() };
}

async function getOrder(orderId, companyId) {
  const rootOrder = await db.collection('orders').doc(orderId).get();
  if (rootOrder.exists) return rootOrder;

  if (companyId) {
    const companyOrder = await db
      .collection('companies')
      .doc(companyId)
      .collection('orders')
      .doc(orderId)
      .get();
    if (companyOrder.exists) return companyOrder;
  }
  throw new functions.https.HttpsError('not-found', 'Order not found.');
}

function isAdminRole(role) {
  const normalized = normalizeRole(role);
  return normalized === 'admin' || normalized === 'administrator';
}

async function findAdminUserIds() {
  const ids = new Set();
  const snap = await db.collection('users').where('role', 'in', [
    'admin',
    'Admin',
    'administrator',
    'Administrator',
  ]).get();
  for (const doc of snap.docs) ids.add(doc.id);

  if (ids.size === 0) {
    const fallback = await db.collection('users').limit(200).get();
    for (const doc of fallback.docs) {
      if (isAdminRole(doc.data()?.role)) ids.add(doc.id);
    }
  }
  return [...ids];
}

function notificationData(userId, orderId, companyId, raisedByRole) {
  return {
    userId,
    type: 'dispute',
    title: 'New Dispute Raised',
    body: `A dispute was raised for order ${orderId} by a ${raisedByRole}.`,
    data: { orderId, companyId },
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

exports.raiseDispute = functions.https.onCall(async (data, context) => {
  const { uid, user } = await authenticatedUser(context);
  const orderId = requiredText(data.orderId, 'Order', 200);
  const suppliedCompanyId = requiredText(data.companyId, 'Company', 200);
  const type = requiredText(data.type, 'Dispute type', 50);
  const description = requiredText(data.description, 'Description', 2000);
  const rawPhotoUrl = data.photoUrl == null ? '' : String(data.photoUrl).trim();
  const photoUrl = rawPhotoUrl || null;
  if (!validTypes.has(type)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid dispute type.',
    );
  }
  if (
    photoUrl &&
    (photoUrl.length > 2000 || !photoUrl.startsWith('https://'))
  ) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Photo evidence URL is invalid.',
    );
  }

  const orderDoc = await getOrder(orderId, suppliedCompanyId);
  const order = orderDoc.data();
  const companyId = String(order.companyId || suppliedCompanyId);
  if (companyId !== suppliedCompanyId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'The order does not belong to this company.',
    );
  }
  const orderStatus = normalize(order.status);
  if (orderStatus !== 'delivered' && orderStatus !== 'confirmed') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Issues can only be reported for delivered or confirmed orders.',
    );
  }

  const role = normalizeRole(user.role);
  const isFieldUser =
    role === 'fielduser' && String(order.fieldUserUid || '') === uid;
  const isSupplier =
    role === 'supplier' &&
    String(order.supplierId || order.supplierUid || '') === uid;
  if (!isFieldUser && !isSupplier) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only a participant in this order can report an issue.',
    );
  }

  const adminIds = await findAdminUserIds();
  const disputeRef = db.collection('disputes').doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const raisedByRole = isSupplier ? 'supplier' : 'field_user';
  const batch = db.batch();
  batch.set(disputeRef, {
    orderId,
    supplierId: String(order.supplierId || order.supplierUid || ''),
    companyId,
    raisedByUid: uid,
    raisedByRole,
    raisedByName: String(user.name || user.fullName || '').trim() || null,
    type,
    description,
    photoUrl,
    status: 'open',
    resolutionNotes: null,
    createdAt: now,
    updatedAt: now,
  });
  for (const adminId of adminIds) {
    batch.set(
      db.collection('notifications').doc(),
      notificationData(adminId, orderId, companyId, raisedByRole),
    );
  }
  await batch.commit();
  if (adminIds.length === 0) {
    console.warn('raiseDispute: no admin users found to notify');
  }

  return { success: true, disputeId: disputeRef.id };
});

exports.updateDispute = functions.https.onCall(async (data, context) => {
  const { uid, user } = await authenticatedUser(context);
  if (normalizeRole(user.role) !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only an administrator can update disputes.',
    );
  }

  const disputeId = requiredText(data.disputeId, 'Dispute', 200);
  const status = requiredText(data.status, 'Status', 30);
  const notes = String(data.resolutionNotes || '').trim();
  if (!validStatuses.has(status)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid dispute status.',
    );
  }
  if (notes.length > 4000) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Resolution notes are too long.',
    );
  }
  if (status === 'resolved' && !notes) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Resolution notes are required before resolving a dispute.',
    );
  }

  const disputeRef = db.collection('disputes').doc(disputeId);
  await db.runTransaction(async (transaction) => {
    const disputeDoc = await transaction.get(disputeRef);
    if (!disputeDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Dispute not found.',
      );
    }
    transaction.update(disputeRef, {
      status,
      resolutionNotes: notes || null,
      resolvedByUid: status === 'resolved' ? uid : null,
      resolvedAt:
        status === 'resolved'
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (status === 'resolved') {
      const dispute = disputeDoc.data() || {};
      const orderId = dispute.orderId || 'unknown order';
      const raisedBy = dispute.raisedByName || dispute.raisedByRole || 'a user';
      transaction.set(db.collection('audit_logs').doc(), {
        actorId: uid,
        actorName: user.name || 'Admin',
        actionType: 'resolve_dispute',
        targetType: 'dispute',
        targetId: disputeId,
        description: `Resolved dispute on order ${orderId} (raised by ${raisedBy})`,
        reason: notes || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  return { success: true };
});
