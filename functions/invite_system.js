const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

const supplierLimits = {
  free: 3,
  basic: 15,
  premium: null,
};

function supplierLimitFor(companyData, subscriptionData) {
  const status = String(subscriptionData?.status || '').toLowerCase();
  const expiresAt = subscriptionData?.expiresAt?.toDate?.();
  const subscriptionActive =
    (status === 'active' || status === 'admin_granted') &&
    (!expiresAt || expiresAt.getTime() >= Date.now());
  const plan = String(
    subscriptionData
      ? (subscriptionActive ? subscriptionData.plan : 'free')
      : (companyData.plan || 'free')
  ).toLowerCase();
  return {
    plan,
    limit: Object.prototype.hasOwnProperty.call(supplierLimits, plan)
      ? supplierLimits[plan]
      : supplierLimits.free,
  };
}

async function assertSupplierCapacity(
  transaction,
  companyRef,
  companyData,
  subscriptionData,
  supplierId
) {
  const mirrorRef = companyRef.collection('suppliers').doc(supplierId);
  const existing = await transaction.get(mirrorRef);
  const existingStatus = String(existing.data()?.status || '').toLowerCase();
  if (existing.exists && (existingStatus === 'active' || existingStatus === 'approved')) {
    return { mirrorRef, alreadyLinked: true };
  }

  const { plan, limit } = supplierLimitFor(companyData, subscriptionData);
  if (limit === null) return { mirrorRef, alreadyLinked: false };

  const activeLinks = await transaction.get(
    companyRef.collection('suppliers')
      .where('status', 'in', ['active', 'approved'])
  );
  if (activeLinks.size >= limit) {
    const planName = plan.charAt(0).toUpperCase() + plan.slice(1);
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `Supplier limit reached for the ${planName} plan (${limit}). Please upgrade to link another supplier.`
    );
  }
  return { mirrorRef, alreadyLinked: false };
}

exports.onInviteAccepted = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');

  const { token, reqId, companyId, supplierUid } = data;
  if (!companyId || !supplierUid) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId and supplierUid required');
  }

  try {
    const supplierRef = db.collection('suppliers').doc(supplierUid);
    const companyRef = db.collection('companies').doc(companyId);
    let supplierData;
    let companyData;

    await db.runTransaction(async (transaction) => {
      const supplierDoc = await transaction.get(supplierRef);
      const companyDoc = await transaction.get(companyRef);
      const subscriptionDoc = await transaction.get(
        db.collection('subscriptions').doc(companyId)
      );
      if (!supplierDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Supplier not found');
      }
      if (!companyDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Company not found');
      }
      supplierData = supplierDoc.data();
      companyData = companyDoc.data();

      const capacity = await assertSupplierCapacity(
        transaction,
        companyRef,
        companyData,
        subscriptionDoc.exists ? subscriptionDoc.data() : null,
        supplierUid
      );
      const linkRef = supplierRef.collection('companyLinks').doc(companyId);

      transaction.set(linkRef, {
        companyId,
        companyName: companyData.name,
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        companyRating: 0,
      }, { merge: true });

      transaction.set(capacity.mirrorRef, {
        supplierUid,
        supplierName: supplierData.businessName,
        city: supplierData.city,
        categories: supplierData.categories || [],
        globalAvgRating: supplierData.globalAvgRating || 0,
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      if (token) {
        transaction.update(db.collection('invitations').doc(token), {
          status: 'accepted',
        });
      }
      if (reqId) {
        transaction.update(db.collection('joinRequests').doc(reqId), {
          status: 'accepted',
        });
      }
      if (!capacity.alreadyLinked) {
        transaction.update(supplierRef, {
          totalCompanies: admin.firestore.FieldValue.increment(1),
        });
      }
    });

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
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.acceptPartnershipRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const requestId = data.requestId;
  if (!requestId) {
    throw new functions.https.HttpsError('invalid-argument', 'requestId is required');
  }

  try {
    await db.runTransaction(async (transaction) => {
      const requestRef = db.collection('partnershipRequests').doc(requestId);
      const requestDoc = await transaction.get(requestRef);
      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Partnership request not found.');
      }

      const request = requestDoc.data();
      if (String(request.status || '').toLowerCase() !== 'pending') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This request is no longer pending.'
        );
      }

      const companyRef = db.collection('companies').doc(request.companyId);
      const supplierRef = db.collection('suppliers').doc(request.supplierId);
      const companyDoc = await transaction.get(companyRef);
      const supplierDoc = await transaction.get(supplierRef);
      const subscriptionDoc = await transaction.get(
        db.collection('subscriptions').doc(request.companyId)
      );
      if (!companyDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Company not found');
      }
      if (!supplierDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Supplier not found');
      }

      const companyData = companyDoc.data();
      const capacity = await assertSupplierCapacity(
        transaction,
        companyRef,
        companyData,
        subscriptionDoc.exists ? subscriptionDoc.data() : null,
        request.supplierId
      );
      const supplierCompanyRef = supplierRef
        .collection('companies')
        .doc(request.companyId);

      transaction.update(requestRef, {
        status: 'accepted',
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(capacity.mirrorRef, {
        id: request.supplierId,
        status: 'active',
        linkedAt: admin.firestore.FieldValue.serverTimestamp(),
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.set(supplierCompanyRef, {
        id: request.companyId,
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        onboardingComplete: false,
      }, { merge: true });
      if (!capacity.alreadyLinked) {
        transaction.set(supplierRef, {
          totalCompanies: admin.firestore.FieldValue.increment(1),
        }, { merge: true });
      }
    });

    return { success: true };
  } catch (error) {
    console.error('acceptPartnershipRequest error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});
