const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { isSupplierCommissionRestricted } = require('./commission_restrictions');

const db = admin.firestore();
const activeOrderStatuses = [
  'pending_approval',
  'pending',
  'accepted',
  'inProgress',
  'inprogress',
  'in_progress',
  'delivered',
];

function normalize(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeRole(value) {
  return normalize(value).replace(/[\s_]/g, '');
}

function requireValue(value, label) {
  const text = String(value || '').trim();
  if (!text) {
    throw new functions.https.HttpsError('invalid-argument', `${label} is required.`);
  }
  return text;
}

/**
 * Matches PlanLimitService.companyPlan: company.plan is the default,
 * and a subscription plan only wins when that subscription is active.
 */
function effectivePlan(companyData, subscriptionData) {
  const companyPlan = normalize(companyData?.plan) || 'free';
  if (!subscriptionData) return companyPlan;

  const status = normalize(subscriptionData.status);
  const expiresAt = subscriptionData.expiresAt?.toDate?.();
  const active =
    (status === 'active' || status === 'admin_granted') &&
    (!expiresAt || expiresAt.getTime() >= Date.now());

  if (active && subscriptionData.plan) {
    return normalize(subscriptionData.plan) || companyPlan;
  }
  return companyPlan;
}

/**
 * Checks if the plan has access to a specific tier.
 */
function hasAccess(plan, requiredPlan) {
  const hierarchy = ['free', 'basic', 'premium', 'advanced'];
  const planIdx = hierarchy.indexOf(plan);
  const reqIdx = hierarchy.indexOf(requiredPlan);
  if (planIdx === -1 || reqIdx === -1) return false;
  return planIdx >= reqIdx;
}

function isActiveSupplier(supplier) {
  if (!supplier) return false;
  const status = normalize(supplier.status);
  return status === 'active' || status === 'approved';
}

function canSupplierBid(supplier) {
  return isActiveSupplier(supplier) && !isSupplierCommissionRestricted(supplier);
}

function stringList(value) {
  return Array.isArray(value)
    ? value.map(normalize).filter(Boolean)
    : [];
}

function supplierMatches(supplier, category, city, user) {
  if (!supplier) return false;
  const categories = [
    ...stringList(supplier.declaredCategories),
    ...stringList(supplier.categories),
    ...stringList(user?.declaredCategories),
    ...stringList(user?.categories),
  ];
  const uniqueCategories = [...new Set(categories)];
  const coverage = stringList(supplier.deliveryCoverageAreas);
  const supplierCity = normalize(supplier.city);
  const cityKey = normalize(city);
  const categoryOk =
    uniqueCategories.length === 0 ||
    categoryListMatches(uniqueCategories, category);
  const cityOk =
    coverage.length === 0 ||
    coverage.includes(cityKey) ||
    supplierCity === cityKey;
  return categoryOk && cityOk;
}

function categoryListMatches(list, category) {
  const target = normalize(category);
  const targetStem = stemCategory(target);
  return list.some((item) => {
    if (item === target) return true;
    return stemCategory(item) === targetStem;
  });
}

function stemCategory(value) {
  return value.replace(/ies$/, 'y').replace(/s$/, '');
}

function notificationData(userId, type, title, body, data) {
  return {
    userId,
    recipientUserId: userId,
    type,
    title,
    body,
    message: body,
    data,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function unwrapCallable(data, context) {
  const looksLikeRequest =
    data &&
    typeof data === 'object' &&
    data.data != null &&
    typeof data.data === 'object' &&
    !Array.isArray(data.data) &&
    (Object.prototype.hasOwnProperty.call(data, 'auth') ||
      Object.prototype.hasOwnProperty.call(data, 'rawRequest'));
  if (looksLikeRequest) {
    return { payload: data.data, auth: data.auth || null };
  }
  return { payload: data || {}, auth: (context && context.auth) || null };
}

function isHttpsError(error) {
  if (!error) return false;
  if (error instanceof functions.https.HttpsError) return true;
  return typeof error.code === 'string' && error.httpErrorCode != null;
}

function rethrowHttps(error, fallbackMessage) {
  if (isHttpsError(error)) throw error;
  console.error(fallbackMessage, error);
  const detail = error && error.message ? String(error.message) : '';
  throw new functions.https.HttpsError(
    'unknown',
    detail ? `${fallbackMessage} (${detail})` : fallbackMessage,
  );
}

async function authenticatedUser(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be signed in.',
    );
  }
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'User profile not found.');
  }
  const user = userDoc.data();
  if (normalize(user.status) !== 'active') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Your account is not active.',
    );
  }
  return { uid: context.auth.uid, user };
}

async function performCreateRfq({ uid, user, payload }) {
    const role = normalizeRole(user.role);
    if (role !== 'ceo' && role !== 'fielduser') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only company users can create quote requests.',
      );
    }

    const companyId = requireValue(payload.companyId, 'Company');
    if (String(user.companyId || '').trim() !== companyId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You cannot create a quote request for another company.',
      );
    }

    const companyRef = db.collection('companies').doc(companyId);
    const [companyDoc, subscriptionDoc] = await Promise.all([
      companyRef.get(),
      db.collection('subscriptions').doc(companyId).get(),
    ]);
    if (!companyDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Company not found.');
    }
    const company = companyDoc.data();
    const plan = effectivePlan(
      company,
      subscriptionDoc.exists ? subscriptionDoc.data() : null,
    );

    if (!hasAccess(plan, 'premium')) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Bulk Quote Requests are available on Premium and Advanced plans. Please upgrade to continue.',
      );
    }

    const category = requireValue(payload.category, 'Category');
    const materialDescription = requireValue(
      payload.materialDescription,
      'Material description',
    );
    const unit = requireValue(payload.unit, 'Unit');
    const city = requireValue(payload.city, 'Delivery city');
    const quantity = Number(payload.quantity);
    const requiredByMillis = Number(payload.requiredByMillis);
    if (!Number.isFinite(quantity) || quantity <= 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Quantity must be greater than zero.',
      );
    }
    if (!Number.isFinite(requiredByMillis)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A valid required-by date is required.',
      );
    }

    const rfqRef = db.collection('rfqs').doc();
    await rfqRef.set({
      companyId,
      companyName: company.name || company.companyName || payload.companyName || 'Company',
      category,
      materialDescription,
      quantity,
      unit,
      city,
      requiredByDate: admin.firestore.Timestamp.fromMillis(requiredByMillis),
      status: 'open',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdByUid: uid,
      createdByName: user.name || company.name || 'Company user',
    });

    let matchedSupplierCount = 0;
    try {
      const suppliers = await db.collection('suppliers').get();
      const matches = suppliers.docs.filter((doc) => {
        const supplier = doc.data();
        return canSupplierBid(supplier) &&
          supplierMatches(supplier, category, city);
      });
      matchedSupplierCount = matches.length;

      if (matches.length > 0) {
        const writer = db.bulkWriter();
        for (const supplierDoc of matches) {
          writer.set(
            db.collection('notifications').doc(),
            notificationData(
              supplierDoc.id,
              'rfq',
              'New RFQ Available',
              `${company.name || 'A company'} is looking for ${category}. Submit your bid now!`,
              {
                rfqId: rfqRef.id,
                companyName: company.name || 'Company',
              },
            ),
          );
        }
        await writer.close();
      }
    } catch (notifyError) {
      console.error('RFQ supplier notifications failed (non-fatal):', notifyError);
    }

    return { rfqId: rfqRef.id, matchedSupplierCount };
}

exports.createRfq = functions.https.onCall(async (data, context) => {
  try {
    const { payload, auth } = unwrapCallable(data, context);
    const { uid, user } = await authenticatedUser({ auth });
    return await performCreateRfq({ uid, user, payload });
  } catch (error) {
    rethrowHttps(error, 'Could not publish the quote request. Please try again.');
  }
});

// Firestore trigger — no public HTTP/IAM. Flutter web callables return
// code=internal/details=null (403 invoker) on this project; see onAiJobCreated.
exports.onRfqJobCreated = functions.firestore
  .document('rfq_jobs/{jobId}')
  .onCreate(async (snap) => {
    const job = snap.data() || {};
    if (job.status && job.status !== 'pending') return null;

    try {
      const uid = requireValue(job.uid, 'User');
      const userDoc = await db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User profile not found.',
        );
      }
      const user = userDoc.data();
      if (normalize(user.status) !== 'active') {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Your account is not active.',
        );
      }

      const result = await performCreateRfq({ uid, user, payload: job });
      await snap.ref.update({
        status: 'complete',
        rfqId: result.rfqId,
        matchedSupplierCount: result.matchedSupplierCount || 0,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('onRfqJobCreated failed:', error);
      await snap.ref.update({
        status: 'error',
        error:
          (isHttpsError(error) && error.message) ||
          error.message ||
          'Could not publish the quote request. Please try again.',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return null;
  });

async function performSubmitRfqBid({ uid, user, payload }) {
  if (normalizeRole(user.role) !== 'supplier') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only approved suppliers can submit bids.',
    );
  }

  const rfqId = requireValue(payload.rfqId, 'Quote request');
  const bidPrice = Number(payload.bidPrice);
  const estimatedDeliveryTime = requireValue(
    payload.estimatedDeliveryTime,
    'Estimated delivery time',
  );
  const note = String(payload.note || '').trim();
  if (!Number.isFinite(bidPrice) || bidPrice <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Bid price must be greater than zero.',
    );
  }

  const rfqRef = db.collection('rfqs').doc(rfqId);
  const supplierRef = db.collection('suppliers').doc(uid);
  const bidRef = rfqRef.collection('bids').doc(uid);

  const result = await db.runTransaction(async (transaction) => {
    const [rfqDoc, supplierDoc, existingBid] = await Promise.all([
      transaction.get(rfqRef),
      transaction.get(supplierRef),
      transaction.get(bidRef),
    ]);
    if (!rfqDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Quote request not found.');
    }
    if (!supplierDoc.exists || !isActiveSupplier(supplierDoc.data())) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Your supplier account must be approved before bidding.',
      );
    }
    if (isSupplierCommissionRestricted(supplierDoc.data())) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Your account is restricted due to overdue commission. Settle outstanding commission from Earnings to submit bids again.',
      );
    }

    const rfq = rfqDoc.data();
    const supplier = supplierDoc.data();
    if (normalize(rfq.status) !== 'open') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'This quote request is closed and no longer accepts bids.',
      );
    }
    // Category/city matching is used to notify relevant suppliers. The supplier
    // RFQ inbox lists every open request, so bidding is allowed for any active
    // supplier who can see it.

    let requesterUid = rfq.createdByUid;
    if (!requesterUid) {
      const companyDoc = await transaction.get(
        db.collection('companies').doc(rfq.companyId),
      );
      requesterUid = companyDoc.data()?.ceoUid;
    }
    if (!requesterUid) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'The request owner could not be resolved.',
      );
    }

    const supplierName =
      supplier.businessName || supplier.name || user.name || 'Supplier';
    transaction.set(bidRef, {
      rfqId,
      supplierId: uid,
      supplierName,
      bidPrice,
      estimatedDeliveryTime,
      note,
      createdAt: existingBid.exists
        ? existingBid.data().createdAt
        : admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      supplierRating: Number(
        supplier.globalAvgRating ?? supplier.rating ?? user.rating ?? 0,
      ),
      status: 'submitted',
    });

    const notificationRef = db.collection('notifications').doc();
    transaction.set(
      notificationRef,
      notificationData(
        requesterUid,
        'rfq',
        existingBid.exists
          ? `Bid updated for ${rfq.category}`
          : `New Bid for ${rfq.category}`,
        `${supplierName} has ${existingBid.exists ? 'updated' : 'submitted'} a bid for your quote request.`,
        { rfqId, supplierName },
      ),
    );
    return { updated: existingBid.exists };
  });

  return { success: true, updated: result.updated };
}

exports.submitRfqBid = functions.https.onCall(async (data, context) => {
  const { uid, user } = await authenticatedUser(context);
  return performSubmitRfqBid({ uid, user, payload: data || {} });
});

// Firestore trigger — Flutter web callables are blocked by CORS on this project.
exports.onRfqBidJobCreated = functions.firestore
  .document('rfq_bid_jobs/{jobId}')
  .onCreate(async (snap) => {
    const job = snap.data() || {};
    if (job.status && job.status !== 'pending') return null;

    try {
      const uid = requireValue(job.uid, 'User');
      const userDoc = await db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User profile not found.',
        );
      }
      const user = userDoc.data();
      if (normalize(user.status) !== 'active') {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Your account is not active.',
        );
      }

      const result = await performSubmitRfqBid({ uid, user, payload: job });
      await snap.ref.update({
        status: 'complete',
        updated: result.updated === true,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('onRfqBidJobCreated failed:', error);
      await snap.ref.update({
        status: 'error',
        error:
          (isHttpsError(error) && error.message) ||
          error.message ||
          'Could not submit the bid. Please try again.',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return null;
  });

async function performAwardRfq({ uid, user, payload }) {
  const role = normalizeRole(user.role);
  if (role !== 'ceo' && role !== 'fielduser') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only the requesting company can award this quote request.',
    );
  }

  const rfqId = requireValue(payload.rfqId, 'Quote request');
  const bidId = requireValue(payload.bidId, 'Bid');
  const rfqRef = db.collection('rfqs').doc(rfqId);
  const bidRef = rfqRef.collection('bids').doc(bidId);
  const orderRef = db.collection('orders').doc(`RFQ_${rfqId}`);

  const rfqPreviewDoc = await rfqRef.get();
  if (rfqPreviewDoc.exists) {
    const rfqPreview = rfqPreviewDoc.data();
    if (user.companyId !== rfqPreview.companyId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You cannot award another company’s request.',
      );
    }
    if (role === 'fielduser' && rfqPreview.createdByUid !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only the user who created this request can award it.',
      );
    }
    if (normalize(rfqPreview.status) === 'open') {
      const [companyDoc, subscriptionDoc] = await Promise.all([
        db.collection('companies').doc(rfqPreview.companyId).get(),
        db.collection('subscriptions').doc(rfqPreview.companyId).get(),
      ]);
      if (companyDoc.exists) {
        const plan = effectivePlan(
          companyDoc.data(),
          subscriptionDoc.exists ? subscriptionDoc.data() : null,
        );
        const maxActiveOrders = plan === 'free' ? 5 : null;
        if (maxActiveOrders !== null) {
          const activeOrders = await db
            .collection('orders')
            .where('companyId', '==', rfqPreview.companyId)
            .where('status', 'in', activeOrderStatuses)
            .get();
          if (activeOrders.size >= maxActiveOrders) {
            throw new functions.https.HttpsError(
              'resource-exhausted',
              `Active order limit reached (${maxActiveOrders}) for the Free plan. Please upgrade to award this request.`,
            );
          }
        }
      }
    }
  }

  const result = await db.runTransaction(async (transaction) => {
    const [rfqDoc, bidDoc, existingOrder] = await Promise.all([
      transaction.get(rfqRef),
      transaction.get(bidRef),
      transaction.get(orderRef),
    ]);
    if (!rfqDoc.exists || !bidDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'The quote request or selected bid no longer exists.',
      );
    }

    const rfq = rfqDoc.data();
    const bid = bidDoc.data();
    if (user.companyId !== rfq.companyId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You cannot award another company’s request.',
      );
    }
    if (role === 'fielduser' && rfq.createdByUid !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only the user who created this request can award it.',
      );
    }
    if (normalize(rfq.status) !== 'open') {
      if (
        rfq.awardedBidId === bidId &&
        existingOrder.exists
      ) {
        return {
          orderId: existingOrder.id,
          autoApproved: normalize(existingOrder.data().status) === 'pending',
          alreadyAwarded: true,
        };
      }
      throw new functions.https.HttpsError(
        'already-exists',
        'This quote request has already been awarded.',
      );
    }

    const companyRef = db.collection('companies').doc(rfq.companyId);
    const [companyDoc, allBids] = await Promise.all([
      transaction.get(companyRef),
      transaction.get(rfqRef.collection('bids')),
    ]);
    if (!companyDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Company not found.');
    }
    const company = companyDoc.data();

    const totalAmount = Number(rfq.quantity) * Number(bid.bidPrice);
    const commissionAmount = totalAmount * 0.02;
    const threshold = Number(company.autoApprovalThreshold || 0);
    const autoApproved = threshold > 0 && totalAmount <= threshold;
    const orderStatus = autoApproved ? 'pending' : 'pending_approval';
    const requesterUid = rfq.createdByUid || uid;
    const requesterName =
      rfq.createdByName || user.name || rfq.companyName || 'Company user';
    const now = admin.firestore.FieldValue.serverTimestamp();

    transaction.set(orderRef, {
      companyId: rfq.companyId,
      fieldUserUid: requesterUid,
      supplierId: bid.supplierId,
      materialId: `RFQ_${rfqId}`,
      materialName: rfq.materialDescription,
      supplierName: bid.supplierName,
      fieldUserName: requesterName,
      quantity: Number(rfq.quantity),
      unit: rfq.unit,
      unitPrice: Number(bid.bidPrice),
      totalAmount,
      commissionAmount,
      supplierEarning: totalAmount - commissionAmount,
      deliveryAddress: rfq.city,
      siteLocation: rfq.city,
      notes: bid.note || null,
      status: orderStatus,
      createdAt: now,
      updatedAt: now,
      requiredDate: rfq.requiredByDate,
      commissionDeducted: false,
      source: 'rfq',
      rfqId,
    });
    transaction.update(rfqRef, {
      status: 'awarded',
      awardedBidId: bidId,
      awardedSupplierId: bid.supplierId,
      awardedAt: now,
      orderId: orderRef.id,
    });

    for (const currentBidDoc of allBids.docs) {
      const currentBid = currentBidDoc.data();
      const awarded = currentBidDoc.id === bidId;
      transaction.update(currentBidDoc.ref, {
        status: awarded ? 'awarded' : 'not_awarded',
        updatedAt: now,
      });
      transaction.set(
        db.collection('notifications').doc(),
        notificationData(
          currentBid.supplierId,
          'rfq',
          awarded ? 'RFQ Awarded! ✅' : 'RFQ Closed',
          awarded
            ? `Congratulations! ${rfq.companyName} has awarded you the contract for ${rfq.category}.`
            : `The RFQ for ${rfq.category} from ${rfq.companyName} has been closed.`,
          { rfqId, awarded: String(awarded), orderId: awarded ? orderRef.id : '' },
        ),
      );
    }

    const ceoUid = company.ceoUid;
    if (autoApproved) {
      transaction.set(
        db.collection('notifications').doc(),
        notificationData(
          bid.supplierId,
          'newOrder',
          'New order received',
          `${requesterName} ordered ${rfq.materialDescription}`,
          {
            orderId: orderRef.id,
            companyId: rfq.companyId,
            status: 'pending',
          },
        ),
      );
      if (ceoUid) {
        transaction.set(
          db.collection('notifications').doc(),
          notificationData(
            ceoUid,
            'orderUpdate',
            'Order Auto-Approved',
            `Order for ${rfq.materialDescription} (Rs. ${totalAmount.toFixed(0)}) was auto-approved per your threshold.`,
            {
              orderId: orderRef.id,
              companyId: rfq.companyId,
              status: 'pending',
            },
          ),
        );
      }
    } else if (ceoUid) {
      transaction.set(
        db.collection('notifications').doc(),
        notificationData(
          ceoUid,
          'orderUpdate',
          'Order awaiting approval',
          `${requesterName} requested ${rfq.materialDescription} — review and approve`,
          {
            orderId: orderRef.id,
            companyId: rfq.companyId,
            status: 'pending_approval',
          },
        ),
      );
    }

    return {
      orderId: orderRef.id,
      autoApproved,
      alreadyAwarded: false,
    };
  });

  return { success: true, ...result };
}

exports.awardRfq = functions.https.onCall(async (data, context) => {
  try {
    const { uid, user } = await authenticatedUser(context);
    return await performAwardRfq({ uid, user, payload: data || {} });
  } catch (error) {
    rethrowHttps(error, 'Could not award this quote request.');
  }
});

// Firestore trigger — Flutter web callables are blocked by CORS on this project.
exports.onRfqAwardJobCreated = functions.firestore
  .document('rfq_award_jobs/{jobId}')
  .onCreate(async (snap) => {
    const job = snap.data() || {};
    if (job.status && job.status !== 'pending') return null;

    try {
      const uid = requireValue(job.uid, 'User');
      const userDoc = await db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User profile not found.',
        );
      }
      const user = userDoc.data();
      if (normalize(user.status) !== 'active') {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Your account is not active.',
        );
      }

      const result = await performAwardRfq({ uid, user, payload: job });
      await snap.ref.update({
        status: 'complete',
        orderId: result.orderId || null,
        autoApproved: result.autoApproved === true,
        alreadyAwarded: result.alreadyAwarded === true,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('onRfqAwardJobCreated failed:', error);
      await snap.ref.update({
        status: 'error',
        error:
          (isHttpsError(error) && error.message) ||
          error.message ||
          'Could not award this quote request. Please try again.',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return null;
  });
