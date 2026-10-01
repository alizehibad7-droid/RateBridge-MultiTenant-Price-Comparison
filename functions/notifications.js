const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Android Notification Channel Mapping
 */
function channelForType(type) {
  const normalized = (type || '').toLowerCase();
  if (normalized.includes('chat')) return 'chat_channel';
  if (normalized.includes('payment') || normalized.includes('commission') || normalized.includes('subscription')) {
    return 'payments_channel';
  }
  if (normalized.includes('invitation') || normalized.includes('partnership')) return 'invitations_channel';
  if (normalized.includes('order') || normalized.includes('delivery')) {
    return 'orders_channel';
  }
  if (normalized.includes('appeal')) return 'system_channel';
  return 'system_channel';
}

/**
 * Sends FCM push to all tokens of a user.
 */
async function sendPushToUser(userId, { title, body, type, data }) {
  console.log(`[FCM] Starting delivery to user: ${userId}`);
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.error(`[FCM] User ${userId} not found in Firestore.`);
      return;
    }
    
    const userData = userDoc.data();
    let tokens = userData.fcmTokens || [];
    if (userData.fcmToken && !tokens.includes(userData.fcmToken)) {
      tokens.push(userData.fcmToken);
    }
    
    // Filter out empty/null tokens
    tokens = tokens.filter(t => t && typeof t === 'string' && t.trim().length > 0);
    
    if (tokens.length === 0) {
      console.log(`[FCM] No tokens for user ${userId}. Skipping push.`);
      return;
    }

    const payload = {
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries({ type, ...data }).map(([k, v]) => [k, String(v ?? '')])
      ),
      android: {
        priority: 'high',
        notification: { 
          channelId: channelForType(type),
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK'
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default' }
        }
      }
    };

    const response = await admin.messaging().sendEachForMulticast({
      tokens: tokens,
      ...payload
    });
    console.log(`[FCM] Sent to ${tokens.length} tokens. Success: ${response.successCount}, Failure: ${response.failureCount}`);
    
    // Cleanup invalid tokens if any
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success && (resp.error.code === 'messaging/invalid-registration-token' || resp.error.code === 'messaging/registration-token-not-registered')) {
          invalidTokens.push(tokens[idx]);
        }
      });
      if (invalidTokens.length > 0) {
        await db.collection('users').doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens)
        });
      }
    }
  } catch (error) {
    console.error(`[FCM] Critical error for user ${userId}:`, error);
  }
}

/**
 * FIRESTORE AS SOURCE OF TRUTH:
 * Every notification document created in the root 'notifications' collection triggers an FCM push.
 */
exports.onNotificationCreated = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    console.log(`[Trigger] New Notification: ${notif.title} for recipient: ${notif.recipientUserId}`);
    
    if (!notif || !notif.recipientUserId) {
      console.error('[Trigger] Missing recipientUserId');
      return null;
    }

    // Map fields for sendPushToUser (legacy support for body vs message)
    return sendPushToUser(notif.recipientUserId, {
      title: notif.title,
      body: notif.message || notif.body,
      type: notif.type,
      data: notif.data || {}
    });
  });

/**
 * Helper to write notification record to Firestore.
 * Standardized to root 'notifications' collection.
 */
async function writeNotificationRecord(userId, notification) {
  console.log(`[Firestore] Writing notification for ${userId}: ${notification.title}`);
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;
    const userData = userDoc.data();
    
    const notifRef = db.collection('notifications').doc();
    const notifData = {
      notifId: notifRef.id,
      recipientUserId: userId,
      recipientRole: userData.role || '',
      type: notification.type || 'system',
      title: notification.title,
      message: notification.body || notification.message || '',
      data: notification.data || {},
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      companyId: userData.companyId || null,
    };
    
    await notifRef.set(notifData);
    console.log(`[Firestore] Saved to notifications/${notifRef.id}`);
  } catch (error) {
    console.error(`[Firestore] Write failed for ${userId}:`, error);
  }
}

async function getAdminUids() {
  const adminQuery = await db.collection('users')
    .where('role', 'in', ['admin', 'Admin', 'administrator', 'Administrator', 'ADMIN'])
    .get();
  const uids = adminQuery.docs.map(doc => doc.id);
  return uids;
}

// --- Event Triggers writing to the root notifications collection ---

exports.onUserRegistration = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap, context) => {
    const user = snap.data();
    if (!user || !['ceo', 'supplier'].includes(user.role?.toLowerCase()) || user.status !== 'pending') return null;

    const adminUids = await getAdminUids();
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'approval',
        title: `New ${user.role} Registration`,
        body: `${user.name} is awaiting platform approval.`,
        data: { targetUid: context.params.uid, role: user.role }
      });
    }
    return null;
  });

exports.onPaymentProofCreated = functions.firestore
  .document('payment_proofs/{proofId}')
  .onCreate(async (snap, context) => {
    const proof = snap.data();
    const adminUids = await getAdminUids();
    const typeLabel = proof.type === 'subscription' ? 'Subscription' : 'Commission';
    
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'payment',
        title: 'New Payment Proof',
        body: `${proof.payerName} submitted proof for ${typeLabel}.`,
        data: { proofId: snap.id, payerId: proof.payerId, type: proof.type }
      });
    }
    return null;
  });

exports.onAppealSubmitted = functions.firestore
  .document('appeals/{appealId}')
  .onCreate(async (snap, context) => {
    const appeal = snap.data();
    const adminUids = await getAdminUids();
    
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'appeal',
        title: 'New Account Appeal',
        body: `${appeal.name} (${appeal.role}) has submitted an appeal for reconsidering their account status.`,
        data: { appealId: snap.id, uid: appeal.uid, role: appeal.role }
      });
    }
    return null;
  });

/** Alias kept for older deploy/index references. */
exports.onAppealCreated = exports.onAppealSubmitted;

/**
 * FCM push when a doc is written to admin_notifications (legacy/admin feed).
 * Also mirrors into root notifications so in-app admin inbox can show it.
 */
exports.onAdminNotificationCreated = functions.firestore
  .document('admin_notifications/{notifId}')
  .onCreate(async (snap) => {
    const notif = snap.data() || {};
    const title = notif.title || 'Admin notification';
    const body = notif.message || notif.body || '';
    const type = notif.type || 'system';
    const data = notif.data || {};

    // Prefer explicit recipient; otherwise fan-out to all admins.
    const targetUid = String(notif.recipientUserId || notif.userId || '').trim();
    const recipients = targetUid ? [targetUid] : await getAdminUids();

    for (const uid of recipients) {
      if (!uid) continue;
      await writeNotificationRecord(uid, {
        type,
        title,
        body,
        data: { ...data, adminNotificationId: snap.id },
      });
    }
    return null;
  });

/**
 * HTTPS callable — notify company CEO of a supplier join request.
 */
exports.sendJoinRequestNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const companyId = String(data?.companyId || '').trim();
  const supplierName = String(data?.supplierName || 'A supplier').trim();
  const reqId = String(data?.reqId || '').trim();

  if (!companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId is required');
  }

  let ceoUid = '';
  const companySnap = await db.collection('companies').doc(companyId).get();
  if (companySnap.exists) {
    ceoUid = String(companySnap.data()?.ceoUid || '').trim();
  }
  if (!ceoUid) {
    try {
      const ceoQuery = await db
        .collection('users')
        .where('companyId', '==', companyId)
        .where('role', 'in', ['CEO', 'ceo'])
        .limit(1)
        .get();
      if (!ceoQuery.empty) ceoUid = ceoQuery.docs[0].id;
    } catch (error) {
      console.error('sendJoinRequestNotification CEO lookup failed:', error);
    }
  }

  if (!ceoUid) {
    throw new functions.https.HttpsError(
      'not-found',
      'Could not find a CEO for this company.'
    );
  }

  await writeNotificationRecord(ceoUid, {
    type: 'partnership',
    title: 'New join request',
    body: `${supplierName} wants to partner with your company. Tap to review.`,
    data: {
      event: 'join_request',
      reqId,
      companyId,
      relatedId: reqId,
      relatedCollection: 'joinRequests',
      supplierName,
    },
  });

  return { success: true };
});

/**
 * HTTPS callable — generic order notification to a user.
 */
exports.sendOrderNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const toUid = String(data?.toUid || '').trim();
  const orderId = String(data?.orderId || '').trim();
  const type = String(data?.type || 'orderUpdate').trim();
  const title = String(data?.title || 'Order update').trim();
  const body = String(data?.body || data?.message || '').trim();

  if (!toUid) {
    throw new functions.https.HttpsError('invalid-argument', 'toUid is required');
  }

  await writeNotificationRecord(toUid, {
    type,
    title,
    body,
    data: {
      orderId,
      relatedId: orderId,
      relatedCollection: 'orders',
      ...(data?.data && typeof data.data === 'object' ? data.data : {}),
    },
  });

  return { success: true };
});

exports.onDisputeCreated = functions.firestore
  .document('disputes/{disputeId}')
  .onCreate(async (snap, context) => {
    const dispute = snap.data() || {};
    const disputeId = snap.id;
    const orderId = String(dispute.orderId || '');
    const companyId = String(dispute.companyId || '');
    const raisedByUid = String(dispute.raisedByUid || '').trim();
    const raisedByRoleRaw = String(dispute.raisedByRole || '').trim();
    const raisedByName =
      String(dispute.raisedByName || '').trim() || 'A team member';
    const typeKey = String(dispute.type || 'other');
    const typeLabel = disputeTypeLabel(typeKey);
    const roleLabel = disputeRoleLabel(raisedByRoleRaw);

    const order = await loadOrderForDispute(orderId, companyId);
    const materialName =
      String(dispute.materialName || order.materialName || order.materialDescription || '')
        .trim() || `order ${shortOrderId(orderId)}`;

    const payloadBase = {
      disputeId,
      orderId,
      companyId,
      materialName,
      type: typeKey,
      typeLabel,
      raisedByUid,
      raisedByName,
      raisedByRole: raisedByRoleRaw,
      relatedId: disputeId,
      relatedCollection: 'disputes',
    };

    const adminUids = await getAdminUids();
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'dispute',
        title: 'New Dispute Reported',
        body: `Order ${orderId} has a new dispute.`,
        data: { ...payloadBase },
      });
    }

    if (raisedByUid && isFieldDisputeRole(raisedByRoleRaw)) {
      await writeNotificationRecord(raisedByUid, {
        type: 'dispute',
        title: 'Dispute submitted',
        body: `Your report on ${materialName} (${typeLabel}) was submitted and is now open.`,
        data: { ...payloadBase, audience: 'raiser' },
      });
    }

    const ceoUid = await loadCompanyCeoUid(companyId);
    if (ceoUid && ceoUid !== raisedByUid) {
      await writeNotificationRecord(ceoUid, {
        type: 'dispute',
        title: 'Dispute on company order',
        body: `${raisedByName} (${roleLabel}) reported ${typeLabel} on ${materialName}.`,
        data: { ...payloadBase, audience: 'ceo' },
      });
    } else if (ceoUid && ceoUid === raisedByUid) {
      await writeNotificationRecord(ceoUid, {
        type: 'dispute',
        title: 'Dispute submitted',
        body: `Your report on ${materialName} (${typeLabel}) was submitted. Your company panel will track its status.`,
        data: { ...payloadBase, audience: 'ceo' },
      });
    }

    return null;
  });

function disputeTypeLabel(type) {
  switch (String(type || '')) {
    case 'wrongMaterial':
      return 'Wrong Material';
    case 'damagedGoods':
      return 'Damaged Goods';
    case 'quantityMismatch':
      return 'Quantity Mismatch';
    case 'nonDelivery':
      return 'Non-Delivery';
    case 'paymentIssue':
      return 'Payment Issue';
    default:
      return 'Other';
  }
}

function disputeRoleLabel(role) {
  const normalized = String(role || '')
    .trim()
    .toLowerCase()
    .replace(/[\s_]/g, '');
  if (normalized === 'fielduser') return 'Field User';
  if (normalized === 'supplier') return 'Supplier';
  if (normalized === 'ceo') return 'CEO';
  if (normalized === 'admin' || normalized === 'administrator') return 'Admin';
  return role || 'Team member';
}

function isFieldDisputeRole(role) {
  return (
    String(role || '')
      .trim()
      .toLowerCase()
      .replace(/[\s_]/g, '') === 'fielduser'
  );
}

function shortOrderId(orderId) {
  const id = String(orderId || '').trim();
  if (!id) return 'unknown';
  return id.length <= 8 ? id : id.slice(-8);
}

async function loadOrderForDispute(orderId, companyId) {
  if (!orderId) return {};
  const root = await db.collection('orders').doc(orderId).get();
  if (root.exists) return root.data() || {};
  if (companyId) {
    const nested = await db
      .collection('companies')
      .doc(companyId)
      .collection('orders')
      .doc(orderId)
      .get();
    if (nested.exists) return nested.data() || {};
  }
  return {};
}

async function loadCompanyCeoUid(companyId) {
  if (!companyId) return null;
  const company = await db.collection('companies').doc(companyId).get();
  const fromCompany = String(company.data()?.ceoUid || '').trim();
  if (fromCompany) return fromCompany;
  try {
    const ceos = await db
      .collection('users')
      .where('companyId', '==', companyId)
      .where('role', 'in', ['CEO', 'ceo'])
      .limit(1)
      .get();
    if (!ceos.empty) return ceos.docs[0].id;
  } catch (error) {
    console.error('loadCompanyCeoUid query failed:', error);
  }
  return null;
}

exports.onMessageSent = functions.firestore
  .document('companies/{companyId}/orders/{orderId}/chats/{msgId}')
  .onCreate(async (snap, context) => {
    const msg = snap.data();
    if (!msg || !msg.recipientId) return null;
    
    await writeNotificationRecord(msg.recipientId, {
       type: 'chat',
       title: msg.senderName || 'New Message',
       body: msg.text || 'Photo',
       data: { orderId: context.params.orderId, companyId: context.params.companyId, chatId: context.params.orderId }
    });
    return null;
  });

/**
 * Ensures suppliers always get an in-app notification when an order becomes
 * actionable (status → pending), even if the client notify call fails.
 * Uses a stable notification id so client + server do not duplicate.
 */
exports.onOrderNotifySupplier = functions.firestore
  .document('orders/{orderId}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;
    const after = change.after.data() || {};
    const before = change.before.exists ? change.before.data() || {} : null;
    const status = String(after.status || '').toLowerCase();
    const prev = before ? String(before.status || '').toLowerCase() : '';
    if (status !== 'pending' || prev === 'pending') return null;

    const supplierId = String(after.supplierId || after.supplierUid || '').trim();
    if (!supplierId) {
      console.error('[onOrderNotifySupplier] Missing supplierId', context.params.orderId);
      return null;
    }

    const orderId = context.params.orderId;
    const notifId = `order_${orderId}_supplier_pending`;
    const existing = await db.collection('notifications').doc(notifId).get();
    if (existing.exists) {
      console.log('[onOrderNotifySupplier] Already notified', notifId);
      return null;
    }

    const materialName = after.materialName || 'a material';
    const fieldUserName = after.fieldUserName || 'A field user';
    const companyId = after.companyId || null;
    const fromCeoApproval = prev === 'pending_approval';

    await db.collection('notifications').doc(notifId).set({
      notifId,
      recipientUserId: supplierId,
      recipientRole: 'Supplier',
      type: 'newOrder',
      title: 'New order received',
      message: fromCeoApproval
        ? `A company approved an order for ${materialName} from ${fieldUserName}. Review and accept.`
        : `${fieldUserName} ordered ${materialName}`,
      data: {
        orderId,
        status: 'pending',
        relatedId: orderId,
        relatedCollection: 'orders',
        ...(fromCeoApproval ? { event: 'ceo_approved', fieldUserName } : {}),
        ...(companyId ? { companyId } : {}),
      },
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      companyId: companyId || null,
    });
    console.log('[onOrderNotifySupplier] Wrote', notifId, 'for', supplierId);
    return null;
  });
