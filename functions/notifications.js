const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

function channelForType(type) {
  const normalized = (type || '').toLowerCase();
  if (normalized.includes('chat')) return 'chat_channel';
  if (normalized.includes('payment') || normalized.includes('commission')) {
    return 'payments_channel';
  }
  if (normalized.includes('invitation')) return 'invitations_channel';
  if (normalized.includes('order') || normalized.includes('delivery')) {
    return 'orders_channel';
  }
  return 'system_channel';
}

async function sendPushToUser(userId, { title, body, type, data }) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return;

    const payload = Object.fromEntries(
      Object.entries({ type, ...data }).map(([k, v]) => [k, String(v ?? '')]),
    );

    await admin.messaging().send({
      token,
      notification: { title, body },
      data: payload,
      android: {
        notification: { channelId: channelForType(type) },
        priority: 'high',
      },
    });
  } catch (error) {
    console.error('sendPushToUser error:', userId, error);
  }
}

// Sends FCM push when the Flutter app writes to notifications/{id}.
exports.onNotificationCreated = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap) => {
    const notif = snap.data();
    if (!notif?.userId) return null;

    await sendPushToUser(notif.userId, {
      title: notif.title || 'RateBridge',
      body: notif.body || '',
      type: notif.type || 'system',
      data: notif.data || {},
    });
    return null;
  });

// Legacy export kept for compatibility — chat notifications are created client-side.
exports.onMessageSent = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async () => null);

// New CEO registration awaiting approval
exports.onNewCEORegistration = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap, context) => {
    const user = snap.data();
    if (!user || user.role !== 'ceo' || user.status !== 'pending') return null;

    try {
      const adminQuery = await db
        .collection('users')
        .where('role', 'in', ['admin', 'Admin', 'administrator'])
        .limit(5)
        .get();
      if (adminQuery.empty) return null;

      for (const adminDoc of adminQuery.docs) {
        await db.collection('notifications').doc().set({
          userId: adminDoc.id,
          type: 'approval',
          title: 'New CEO Registration',
          body: `${user.name || 'A CEO'} is awaiting approval`,
          data: { ceoUid: context.params.uid },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      console.error('onNewCEORegistration error:', error);
    }
    return null;
  });

// Legacy export — order notifications are created client-side.
exports.onOrderStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after || before.status === after.status) return null;
    return null;
  });
