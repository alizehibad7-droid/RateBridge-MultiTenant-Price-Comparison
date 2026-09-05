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
const validStatuses = new Set(['under_review', 'resolved', 'rejected']);

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

function isHttpsError(error) {
  if (!error) return false;
  if (error instanceof functions.https.HttpsError) return true;
  return typeof error.code === 'string' && error.httpErrorCode != null;
}

function publicErrorMessage(error, fallback) {
  if (isHttpsError(error) && error.message) return error.message;
  return fallback;
}

const inactiveAccountStatuses = new Set([
  'pending',
  'rejected',
  'suspended',
  'inactive',
  'deactivated',
  'blocked',
]);

async function loadActiveUser(uid) {
  if (!uid) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be signed in.',
    );
  }
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'User profile not found.',
    );
  }
  const user = userDoc.data() || {};
  const status = normalize(user.status);
  if (status && inactiveAccountStatuses.has(status)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Your account is not active.',
    );
  }
  return { uid, user };
}

async function authenticatedUser(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be signed in.',
    );
  }
  return loadActiveUser(context.auth.uid);
}

async function performRaiseDispute({ uid, user, payload }) {
  const orderId = requiredText(payload.orderId, 'Order', 200);
  const suppliedCompanyId = requiredText(payload.companyId, 'Company', 200);
  const type = requiredText(payload.type, 'Dispute type', 50);
  const description = requiredText(payload.description, 'Description', 2000);
  const rawPhotoUrl =
    payload.photoUrl == null ? '' : String(payload.photoUrl).trim();
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
    recipientUserId: userId,
    type: 'dispute',
    title: 'New Dispute Raised',
    body: `A dispute was raised for order ${orderId} by a ${raisedByRole}.`,
    data: { orderId, companyId },
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function disputeOutcomeNotification({
  userId,
  recipientRole,
  orderId,
  companyId,
  status,
  notes,
}) {
  const rejected = status === 'rejected';
  const outcome = rejected ? 'rejected' : 'resolved';
  const body = notes
    ? `Your dispute for order ${orderId} was ${outcome}. ${notes}`
    : `Your dispute for order ${orderId} was ${outcome}.`;
  return {
    userId,
    recipientUserId: userId,
    recipientRole: recipientRole || 'field_user',
    type: 'dispute',
    title: rejected ? 'Dispute rejected' : 'Dispute resolved',
    body,
    message: body,
    data: { orderId, companyId, status },
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function performUpdateDispute({ uid, user, payload }) {
  if (!isAdminRole(user.role)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only an administrator can update disputes.',
    );
  }

  const disputeId = requiredText(payload.disputeId, 'Dispute', 200);
  const status = requiredText(payload.status, 'Status', 30);
  const notes = String(payload.resolutionNotes || '').trim();
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
  if ((status === 'resolved' || status === 'rejected') && !notes) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Resolution notes are required before closing a dispute.',
    );
  }

  const disputeRef = db.collection('disputes').doc(disputeId);
  const disputeDoc = await disputeRef.get();
  if (!disputeDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Dispute not found.');
  }

  const dispute = disputeDoc.data() || {};
  const now = admin.firestore.FieldValue.serverTimestamp();
  const isClosed = status === 'resolved' || status === 'rejected';
  await disputeRef.update({
    status,
    resolutionNotes: notes || null,
    resolvedByUid: isClosed ? uid : null,
    resolvedBy: isClosed ? uid : null,
    resolvedAt: isClosed ? now : null,
    updatedAt: now,
  });

  const orderId = dispute.orderId || 'unknown order';
  const raisedBy = dispute.raisedByName || dispute.raisedByRole || 'a user';
  if (isClosed) {
    await db.collection('audit_logs').doc().set({
      actorId: uid,
      actorName: user.name || user.fullName || 'Admin',
      actionType: status === 'rejected' ? 'reject_dispute' : 'resolve_dispute',
      targetType: 'dispute',
      targetId: disputeId,
      description: `${status === 'rejected' ? 'Rejected' : 'Resolved'} dispute on order ${orderId} (raised by ${raisedBy})`,
      reason: notes || null,
      timestamp: now,
    });

    const raisedByUid = String(dispute.raisedByUid || '').trim();
    if (raisedByUid) {
      await db.collection('notifications').doc().set(
        disputeOutcomeNotification({
          userId: raisedByUid,
          recipientRole: dispute.raisedByRole,
          orderId,
          companyId: String(dispute.companyId || ''),
          status,
          notes,
        }),
      );
    }
  }

  return { success: true, disputeId };
}

exports.raiseDispute = functions.https.onCall(async (data, context) => {
  const { uid, user } = await authenticatedUser(context);
  return performRaiseDispute({ uid, user, payload: data || {} });
});

// Firestore trigger — no public HTTP/IAM. Flutter web callables return
// CORS / code=internal on this project; see onRfqJobCreated and onAiJobCreated.
exports.onDisputeJobCreated = functions.firestore
  .document('dispute_jobs/{jobId}')
  .onCreate(async (snap) => {
    const job = snap.data() || {};
    if (job.status && job.status !== 'pending') return null;

    try {
      const uid = requiredText(job.uid, 'User', 200);
      const { user } = await loadActiveUser(uid);
      const result = await performRaiseDispute({ uid, user, payload: job });
      await snap.ref.update({
        status: 'complete',
        disputeId: result.disputeId,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('onDisputeJobCreated failed:', error);
      await snap.ref.update({
        status: 'error',
        error: publicErrorMessage(
          error,
          'Could not submit the report. Please try again.',
        ),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return null;
  });

exports.updateDispute = functions.https.onCall(async (data, context) => {
  try {
    const { uid, user } = await authenticatedUser(context);
    return await performUpdateDispute({ uid, user, payload: data || {} });
  } catch (error) {
    console.error('updateDispute failed:', error);
    if (isHttpsError(error)) throw error;
    throw new functions.https.HttpsError(
      'internal',
      publicErrorMessage(
        error,
        'Could not update the dispute. Please try again.',
      ),
    );
  }
});

// Firestore trigger — Flutter web HTTPS callables return CORS / code=internal
// on this project (same pattern as onDisputeJobCreated).
exports.onDisputeUpdateJobCreated = functions.firestore
  .document('dispute_update_jobs/{jobId}')
  .onCreate(async (snap) => {
    const job = snap.data() || {};
    if (job.status && job.status !== 'pending') return null;

    try {
      const uid = requiredText(job.uid, 'User', 200);
      const { user } = await loadActiveUser(uid);
      await performUpdateDispute({
        uid,
        user,
        payload: {
          disputeId: job.disputeId,
          status: job.statusUpdate || job.disputeStatus,
          resolutionNotes: job.resolutionNotes,
        },
      });
      await snap.ref.update({
        status: 'complete',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('onDisputeUpdateJobCreated failed:', error);
      await snap.ref.update({
        status: 'error',
        error: publicErrorMessage(
          error,
          'Could not update the dispute. Please try again.',
        ),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return null;
  });
