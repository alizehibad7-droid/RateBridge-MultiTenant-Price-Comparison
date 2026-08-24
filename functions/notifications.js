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
  } catch (error) {
    console.error(`[FCM] Critical error for user ${userId}:`, error);
  }
}

/**
 * ALGORITHM 10 CORE: Trigger point for Admin-facing push notifications.
 */
exports.onAdminNotificationCreated = functions.firestore
  .document('adminNotifications/{notifId}')
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    console.log(`[Algorithm 10] New Admin Notif: ${notif.title} for UID: ${notif.userId}`);
    if (!notif || !notif.userId) return null;
    return sendPushToUser(notif.userId, notif);
  });

/**
 * TRIGGER: Handles delivery for all other users.
 */
exports.onNotificationCreated = functions.firestore
  .document('{col}/{id}/notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    if (!notif || !notif.userId) return null;
    return sendPushToUser(notif.userId, notif);
  });

/**
 * Helper to write notification record to Firestore.
 */
async function writeNotificationRecord(userId, notification) {
  console.log(`[Firestore] Writing notification for ${userId}: ${notification.title}`);
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;
    const userData = userDoc.data();
    const role = (userData.role || '').toLowerCase();
    const companyId = userData.companyId;

    let path = 'notifications';
    if (role === 'admin' || role === 'administrator') {
      path = 'adminNotifications';
    } else if (role === 'supplier') {
      path = `suppliers/${userId}/notifications`;
    } else if (companyId) {
      path = `companies/${companyId}/notifications`;
    }

    const notifRef = db.collection(path).doc();
    const notifData = {
      ...notification,
      userId: userId,
      notifId: notifRef.id,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    await notifRef.set(notifData);
    console.log(`[Firestore] Saved to ${path}/${notifRef.id}`);
  } catch (error) {
    console.error(`[Firestore] Write failed for ${userId}:`, error);
  }
}

async function getAdminUids() {
  const adminQuery = await db.collection('users')
    .where('role', 'in', ['admin', 'Admin', 'administrator', 'Administrator', 'ADMIN'])
    .get();
  const uids = adminQuery.docs.map(doc => doc.id);
  console.log(`[Lookup] Found ${uids.length} admin(s): ${uids.join(', ')}`);
  return uids;
}

// --- Admin Event Triggers ---

exports.onUserRegistration = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap, context) => {
    const user = snap.data();
    console.log(`[Trigger] New User Registration: ${user.name} (${user.role})`);
    
    if (!user || !['ceo', 'supplier'].includes(user.role?.toLowerCase()) || user.status !== 'pending') return null;

    const adminUids = await getAdminUids();
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'approval',
        title: `New ${user.role} Registration — Action Required`,
        body: `${user.name} is awaiting platform approval.`,
        data: { targetUid: context.params.uid, role: user.role, screen: 'pending_approvals' }
      });
    }
    return null;
  });

exports.onPaymentProofCreated = functions.firestore
  .document('payment_proofs/{proofId}')
  .onCreate(async (snap, context) => {
    const proof = snap.data();
    console.log(`[Trigger] New Payment Proof: ${proof.payerName}`);
    
    const adminUids = await getAdminUids();
    const typeLabel = proof.type === 'subscription' ? 'Subscription' : 'Commission';
    
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'payment',
        title: 'Payment Proof Submitted for Review',
        body: `${proof.payerName} uploaded proof for ${typeLabel} settlement.`,
        data: { proofId: snap.id, payerId: proof.payerId, type: proof.type, screen: 'payment_verification' }
      });
    }
    return null;
  });

exports.onDisputeCreated = functions.firestore
  .document('disputes/{disputeId}')
  .onCreate(async (snap, context) => {
    const dispute = snap.data();
    console.log(`[Trigger] New Dispute: Order ${dispute.orderId}`);
    
    const adminUids = await getAdminUids();
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'dispute',
        title: 'New Dispute Reported',
        body: `Order ${dispute.orderId} has a new dispute requiring mediation.`,
        data: { disputeId: snap.id, orderId: dispute.orderId, screen: 'disputes_panel' }
      });
    }
    return null;
  });

exports.onAppealCreated = functions.firestore
  .document('appeals/{appealId}')
  .onCreate(async (snap, context) => {
    const appeal = snap.data();
    console.log(`[Trigger] New Appeal from Supplier: ${appeal.supplierUid}`);
    
    const adminUids = await getAdminUids();
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'approval',
        title: 'Supplier Appeal Submitted',
        body: `A rejected supplier has submitted an appeal for reconsideration.`,
        data: { appealId: snap.id, supplierUid: appeal.supplierUid, screen: 'supplier_appeals' }
      });
    }
    return null;
  });

exports.onMessageSent = functions.firestore
  .document('companies/{companyId}/orders/{orderId}/chats/{msgId}')
  .onCreate(async (snap, context) => {
    const msg = snap.data();
    if (!msg || !msg.recipientId) return null;
    
    await writeNotificationRecord(msg.recipientId, {
       type: 'chat',
       title: msg.senderName || 'New Message',
       body: msg.text || '📷 Photo',
       data: { orderId: context.params.orderId, companyId: context.params.companyId, chatId: context.params.orderId }
    });
    return null;
  });
