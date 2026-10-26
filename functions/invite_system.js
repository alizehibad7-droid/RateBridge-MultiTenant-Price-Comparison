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

  // Read the whole subcollection inside the transaction (avoid status-in
  // queries that can fail/index-miss and block accepts).
  const allLinks = await transaction.get(companyRef.collection('suppliers'));
  const activeCount = allLinks.docs.filter((doc) => {
    const status = String(doc.data()?.status || '').toLowerCase();
    return status === 'active' || status === 'approved';
  }).length;
  if (activeCount >= limit) {
    const planName = plan.charAt(0).toUpperCase() + plan.slice(1);
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `Supplier limit reached for the ${planName} plan (${limit}). Please upgrade to link another supplier.`
    );
  }
  return { mirrorRef, alreadyLinked: false };
}

function isCompanyCeoUser({ uid, ceoUid, userRole, userCompanyId, companyId }) {
  if (ceoUid && uid === ceoUid) return true;
  const role = String(userRole || '')
    .trim()
    .toLowerCase()
    .replace(/[\s_-]+/g, '');
  const companyMatch =
    String(userCompanyId || '').trim() === String(companyId || '').trim();
  return companyMatch && (role === 'ceo' || role.endsWith('ceo') || role.includes('ceo'));
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
      // App watches suppliers/{uid}/companies — write that path (not companyLinks).
      const supplierCompanyRef = supplierRef.collection('companies').doc(companyId);
      const displayName =
        supplierData.name || supplierData.businessName || 'Supplier';

      transaction.set(supplierCompanyRef, {
        id: companyId,
        name: companyData.name || companyData.companyName || '',
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        onboardingComplete: false,
      }, { merge: true });

      // Keep legacy companyLinks in sync for any older readers.
      transaction.set(supplierRef.collection('companyLinks').doc(companyId), {
        companyId,
        companyName: companyData.name || companyData.companyName || '',
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        companyRating: 0,
      }, { merge: true });

      transaction.set(capacity.mirrorRef, {
        id: supplierUid,
        supplierUid,
        name: displayName,
        businessName: supplierData.businessName || supplierData.name || displayName,
        supplierName: supplierData.businessName || supplierData.name || displayName,
        city: supplierData.city || '',
        categories: supplierData.categories || [],
        materialType: supplierData.materialType || supplierData.businessType || 'General',
        globalAvgRating: supplierData.globalAvgRating || 0,
        email: supplierData.email || '',
        status: 'active',
        linkedAt: admin.firestore.FieldValue.serverTimestamp(),
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

    // f. Create root notifications (app listens on notifications/, not nested company docs)
    const notifBatch = db.batch();
    const supplierNotifRef = db.collection('notifications').doc();
    notifBatch.set(supplierNotifRef, {
      notifId: supplierNotifRef.id,
      recipientUserId: supplierUid,
      recipientRole: 'Supplier',
      type: 'partnership',
      title: 'Company Link Approved',
      message: `You are now linked to ${companyData.name}. Start adding materials.`,
      data: { companyId, event: 'accepted', relatedId: companyId, relatedCollection: 'companies' },
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      companyId,
    });
    if (ceoUid) {
      const ceoNotifRef = db.collection('notifications').doc();
      notifBatch.set(ceoNotifRef, {
        notifId: ceoNotifRef.id,
        recipientUserId: ceoUid,
        recipientRole: 'CEO',
        type: 'partnership',
        title: 'New Supplier Joined',
        message: `${supplierData.businessName || supplierData.name || 'A supplier'} has joined your company.`,
        data: { supplierUid, companyId, event: 'accepted', relatedId: supplierUid, relatedCollection: 'suppliers' },
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        companyId,
      });
    }
    await notifBatch.commit();

    return { success: true };

  } catch (error) {
    console.error('onInviteAccepted error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.acceptPartnershipRequest = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const requestId = data.requestId;
  if (!requestId) {
    throw new functions.https.HttpsError('invalid-argument', 'requestId is required');
  }

  const uid = context.auth.uid;

  try {
    let companyData;
    let supplierData;
    let request;

    await db.runTransaction(async (transaction) => {
      const requestRef = db.collection('partnershipRequests').doc(requestId);
      const requestDoc = await transaction.get(requestRef);
      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Partnership request not found.');
      }

      request = requestDoc.data() || {};
      if (String(request.status || '').toLowerCase() !== 'pending') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This request is no longer pending.'
        );
      }

      const companyId = String(request.companyId || '').trim();
      const supplierId = String(request.supplierId || '').trim();
      if (!companyId || !supplierId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Partnership request is missing company or supplier.'
        );
      }

      const companyRef = db.collection('companies').doc(companyId);
      const supplierRef = db.collection('suppliers').doc(supplierId);
      const companyDoc = await transaction.get(companyRef);
      const supplierDoc = await transaction.get(supplierRef);
      const subscriptionDoc = await transaction.get(
        db.collection('subscriptions').doc(companyId)
      );
      if (!companyDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Company not found');
      }
      if (!supplierDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Supplier not found');
      }

      companyData = companyDoc.data() || {};
      supplierData = supplierDoc.data() || {};

      const initiatedBy = String(request.initiatedBy || '').toLowerCase();
      const ceoUid = String(
        companyData.ceoUid || companyData.ownerUid || ''
      ).trim();
      const userDoc = await transaction.get(db.collection('users').doc(uid));
      const userData = userDoc.data() || {};
      const userCompanyId = String(userData.companyId || '').trim();
      const userRole = String(userData.role || '').trim();
      const ceoOk = isCompanyCeoUser({
        uid,
        ceoUid,
        userRole,
        userCompanyId,
        companyId,
      });

      // CEO invite → supplier accepts. Supplier request → CEO accepts.
      if (initiatedBy === 'ceo' || initiatedBy === 'company') {
        if (uid !== supplierId) {
          throw new functions.https.HttpsError(
            'permission-denied',
            'Only the invited supplier can accept this partnership invite.'
          );
        }
      } else if (!ceoOk) {
        console.warn('acceptPartnershipRequest denied', {
          uid,
          ceoUid,
          userRole,
          userCompanyId,
          companyId,
          initiatedBy,
        });
        throw new functions.https.HttpsError(
          'permission-denied',
          'Only the company CEO can accept this partnership request.'
        );
      }

      const capacity = await assertSupplierCapacity(
        transaction,
        companyRef,
        companyData,
        subscriptionDoc.exists ? subscriptionDoc.data() : null,
        supplierId
      );
      const supplierCompanyRef = supplierRef.collection('companies').doc(companyId);
      const displayName =
        supplierData.name || supplierData.businessName || 'Supplier';
      const companyName =
        companyData.name || companyData.companyName || '';

      transaction.update(requestRef, {
        status: 'accepted',
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(capacity.mirrorRef, {
        id: supplierId,
        supplierUid: supplierId,
        name: displayName,
        businessName: supplierData.businessName || supplierData.name || displayName,
        supplierName: supplierData.businessName || supplierData.name || displayName,
        city: supplierData.city || '',
        categories: supplierData.categories || [],
        materialType: supplierData.materialType || supplierData.businessType || 'General',
        globalAvgRating: supplierData.globalAvgRating || 0,
        email: supplierData.email || '',
        status: 'active',
        linkedAt: admin.firestore.FieldValue.serverTimestamp(),
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.set(supplierCompanyRef, {
        id: companyId,
        name: companyName,
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        onboardingComplete: false,
      }, { merge: true });
      // Keep legacy companyLinks in sync.
      transaction.set(supplierRef.collection('companyLinks').doc(companyId), {
        companyId,
        companyName,
        status: 'active',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        companyRating: 0,
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
    throw new functions.https.HttpsError('internal', error.message || String(error));
  }
});
