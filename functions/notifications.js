const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

// When a chat message is sent
exports.onMessageSent = functions.firestore
  .document('companies/{companyId}/orders/{orderId}/chats/{msgId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const { companyId, orderId } = context.params;
    const senderUid = message.senderUid;
    const senderRole = message.senderRole;

    try {
      const orderDoc = await db.collection('companies').doc(companyId)
        .collection('orders').doc(orderId).get();
      const orderData = orderDoc.data();

      const recipientUid = senderRole === 'fieldUser'
        ? orderData.supplierUid
        : orderData.fieldUserUid;

      // Get recipient FCM token
      const recipientDoc = await db.collection('users').doc(recipientUid).get();
      const recipientToken = recipientDoc.data()?.fcmToken;

      // Send FCM
      if (recipientToken) {
        const senderName = senderRole === 'fieldUser'
          ? orderData.fieldUserName : orderData.supplierName;
        await admin.messaging().send({
          token: recipientToken,
          notification: {
            title: `${senderName}`,
            body: message.imageUrl
              ? '📷 Sent an image'
              : message.text?.substring(0, 100) || 'New message',
          },
          data: { type: 'chat', orderId, companyId },
          android: { channelId: 'chat_channel' },
        });
      }

      // Create notification doc
      await db.collection('companies').doc(companyId)
        .collection('notifications').doc().set({
          userId: recipientUid,
          type: 'chat',
          title: senderRole === 'fieldUser' ? orderData.fieldUserName : orderData.supplierName,
          body: message.imageUrl ? 'Sent an image' : (message.text?.substring(0, 100) || ''),
          data: { orderId, companyId },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Increment unread count in chatMeta
      await db.collection('companies').doc(companyId)
        .collection('orders').doc(orderId)
        .collection('chatMeta').doc('meta')
        .set({
          [`unreadCount.${recipientUid}`]: admin.firestore.FieldValue.increment(1),
          lastMessage: message.text || '📷 Image',
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

    } catch (error) {
      console.error('onMessageSent error:', error);
    }
  });

// When a new CEO registers (status = pending)
exports.onNewCEORegistration = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap, context) => {
    const user = snap.data();
    if (user.role !== 'ceo' || user.status !== 'pending') return null;

    try {
      // Find admin
      const adminQuery = await db.collection('users').where('role', '==', 'admin').limit(1).get();
      if (adminQuery.empty) return null;

      const adminData = adminQuery.docs[0].data();
      const adminUid = adminQuery.docs[0].id;

      if (adminData.fcmToken) {
        await admin.messaging().send({
          token: adminData.fcmToken,
          notification: {
            title: 'New CEO Registration',
            body: `${user.name} from ${user.companyName || 'Unknown Company'} is awaiting approval`,
          },
          data: { type: 'approval', ceoUid: context.params.uid },
          android: { channelId: 'system_channel' },
        });
      }

      await db.collection('companies').doc('admin')
        .collection('notifications').doc().set({
          userId: adminUid,
          type: 'approval',
          title: 'New CEO Registration',
          body: `${user.name} is awaiting approval`,
          data: { ceoUid: context.params.uid },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

    } catch (error) {
      console.error('onNewCEORegistration error:', error);
    }
  });

// When order status changes — notify relevant parties
exports.onOrderStatusChange = functions.firestore
  .document('companies/{companyId}/orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return null;

    const { companyId, orderId } = context.params;
    const newStatus = after.status;

    const statusMessages = {
      accepted: { title: 'Order Accepted', body: `Your order for ${after.materialName} has been accepted` },
      rejected: { title: 'Order Rejected', body: `Your order for ${after.materialName} was rejected: ${after.rejectionReason || ''}` },
      inProgress: { title: 'Order In Progress', body: `Your order for ${after.materialName} is now in progress` },
      delivered: { title: 'Delivery Ready — Confirm Receipt', body: `${after.materialName} has been delivered. Please confirm receipt.` },
      confirmed: { title: 'Order Complete', body: `Your order for ${after.materialName} is complete` },
      cancelled: { title: 'Order Cancelled', body: `Order for ${after.materialName} was cancelled` },
    };

    const msg = statusMessages[newStatus];
    if (!msg) return null;

    // Determine who to notify
    let notifyUid;
    if (['accepted', 'rejected', 'inProgress', 'delivered', 'confirmed'].includes(newStatus)) {
      notifyUid = after.fieldUserUid; // notify field user
    } else if (newStatus === 'cancelled') {
      notifyUid = after.supplierUid; // notify supplier
    }

    if (!notifyUid) return null;

    try {
      const userDoc = await db.collection('users').doc(notifyUid).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: { title: msg.title, body: msg.body },
          data: { type: 'orderUpdate', orderId, companyId, status: newStatus },
          android: { channelId: 'orders_channel', priority: 'high' },
        });
      }

      await db.collection('companies').doc(companyId)
        .collection('notifications').doc().set({
          userId: notifyUid,
          type: 'orderUpdate',
          title: msg.title,
          body: msg.body,
          data: { orderId, companyId, status: newStatus },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

    } catch (error) {
      console.error('onOrderStatusChange error:', error);
    }
  });
