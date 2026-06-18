const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

exports.onInviteAccepted = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');

  const { token, reqId, companyId, supplierUid } = data;
  if (!companyId || !supplierUid) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId and supplierUid required');
  }

  try {
    // Get supplier data for denormalization
    const supplierDoc = await db.collection('suppliers').doc(supplierUid).get();
    if (!supplierDoc.exists) throw new functions.https.HttpsError('not-found', 'Supplier not found');
    const supplierData = supplierDoc.data();

    const companyDoc = await db.collection('companies').doc(companyId).get();
    if (!companyDoc.exists) throw new functions.https.HttpsError('not-found', 'Company not found');
    const companyData = companyDoc.data();

    const batch = db.batch();

    // a. Create supplier → company link
    const linkRef = db.collection('suppliers').doc(supplierUid)
      .collection('companyLinks').doc(companyId);
    batch.set(linkRef, {
      companyId,
      companyName: companyData.name,
      status: 'active',
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      companyRating: 0,
    });

    // b. Create company → supplier mirror
    const mirrorRef = db.collection('companies').doc(companyId)
      .collection('suppliers').doc(supplierUid);
    batch.set(mirrorRef, {
      supplierUid,
      supplierName: supplierData.businessName,
      city: supplierData.city,
      categories: supplierData.categories || [],
      globalAvgRating: supplierData.globalAvgRating || 0,
      status: 'active',
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // c. Update invitation or join request status
    if (token) {
      const inviteRef = db.collection('invitations').doc(token);
      batch.update(inviteRef, { status: 'accepted' });
    }
    if (reqId) {
      const reqRef = db.collection('joinRequests').doc(reqId);
      batch.update(reqRef, { status: 'accepted' });
    }

    // d. Increment supplier.totalCompanies
    const supplierRef = db.collection('suppliers').doc(supplierUid);
    batch.update(supplierRef, {
      totalCompanies: admin.firestore.FieldValue.increment(1),
    });

    await batch.commit();

    // e. Send FCM notifications
    const supplierUserDoc = await db.collection('users').doc(supplierUid).get();
    const supplierToken = supplierUserDoc.data()?.fcmToken;
    if (supplierToken) {
      await admin.messaging().send({
        token: supplierToken,
        notification: {
          title: 'Company Link Approved!',
          body: `You are now linked to ${companyData.name}. Start adding materials.`,
        },
        android: { channelId: 'invitations_channel' },
      });
    }

    const ceoUid = companyData.ceoUid;
    const ceoDoc = await db.collection('users').doc(ceoUid).get();
    const ceoToken = ceoDoc.data()?.fcmToken;
    if (ceoToken) {
      await admin.messaging().send({
        token: ceoToken,
        notification: {
          title: 'Supplier Joined!',
          body: `${supplierData.businessName} has joined your company.`,
        },
        android: { channelId: 'invitations_channel' },
      });
    }

    // f. Create notification docs
    const notifBatch = db.batch();
    notifBatch.set(
      db.collection('companies').doc(companyId).collection('notifications').doc(),
      {
        userId: supplierUid,
        type: 'invitation',
        title: 'Company Link Approved',
        body: `You are now linked to ${companyData.name}`,
        data: { companyId },
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    );
    notifBatch.set(
      db.collection('companies').doc(companyId).collection('notifications').doc(),
      {
        userId: ceoUid,
        type: 'invitation',
        title: 'New Supplier Joined',
        body: `${supplierData.businessName} has joined your company`,
        data: { supplierUid, companyId },
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    );
    await notifBatch.commit();

    return { success: true };

  } catch (error) {
    console.error('onInviteAccepted error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
