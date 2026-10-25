const functions = require("firebase-functions");
const admin = require("firebase-admin");

/**
 * Lazy Stripe init — functions.config().stripe.secret_key must match
 * the Flutter publishable key (same Stripe account / pk_test_51UDAH2...).
 * Do NOT fall back to stripe.secret (different test account).
 */
let cachedStripe = null;
function getStripe() {
  if (cachedStripe) return cachedStripe;
  const secretKey =
    process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
  if (!secretKey) {
    throw new Error(
      "STRIPE_SECRET_KEY is not configured. Use firebase functions:config:set stripe.secret_key=\"sk_...\""
    );
  }
  cachedStripe = require("stripe")(secretKey);
  return cachedStripe;
}

const SUBSCRIPTION_PLANS_PKR = {
  basic: 1000,
  premium: 5000,
};

/** Stripe PKR amount is in paisa (Rs. 1 = 100). */
function toStripeAmountPkr(amountPKR) {
  return Math.round(Number(amountPKR) * 100);
}

function fromStripeAmountPkr(amountPaisa) {
  return Math.round(Number(amountPaisa) / 100);
}

function subscriptionMeta(plan, companyId, amountPKR) {
  return {
    type: "subscription",
    companyId: companyId || "",
    plan: String(plan || ""),
    amountPKR: String(amountPKR),
  };
}

function commissionMeta(supplierId, transactionIds, rupees) {
  const ids = Array.isArray(transactionIds)
    ? transactionIds
    : String(transactionIds || "")
        .split(",")
        .filter(Boolean);
  return {
    type: "commission",
    supplierId: supplierId || "",
    transactionIds: ids.join(","),
    amountPKR: String(rupees),
  };
}

function planExpiryDate() {
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30);
  return expiresAt;
}

function publicStripeError(error) {
  const raw = String(error?.message || error || "Payment failed");
  return raw.slice(0, 280);
}

/**
 * Helper to write notification record to Firestore.
 * Standardized to root 'notifications' collection.
 */
async function writeNotificationRecord(userId, notification) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) return;
    const userData = userDoc.data();
    
    const notifRef = admin.firestore().collection('notifications').doc();
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
      companyId: userData.companyId || notification.companyId || null,
    };
    
    await notifRef.set(notifData);
  } catch (error) {
    console.error(`[Firestore] Notification write failed for ${userId}:`, error);
  }
}

async function getAdminUids() {
  const adminQuery = await admin.firestore().collection('users')
    .where('role', 'in', ['admin', 'Admin', 'administrator', 'Administrator', 'ADMIN'])
    .get();
  return adminQuery.docs.map(doc => doc.id);
}

async function applySuccessfulPayment(metadata, amountFallback, paymentRefId) {
  const { type, companyId, plan, transactionIds, amountPKR, supplierId } = metadata || {};

  if (type === "subscription") {
    if (!companyId) {
      throw new Error(
        "Subscription payment missing companyId in metadata"
      );
    }
    if (!plan || !SUBSCRIPTION_PLANS_PKR[plan]) {
      throw new Error("Subscription payment missing/invalid plan");
    }
    const subRef = admin.firestore().collection("subscriptions").doc(companyId);
    const existing = await subRef.get();
    const history = existing.data()?.history || [];
    if (
      paymentRefId &&
      history.some((h) => h && h.stripePaymentIntentId === paymentRefId)
    ) {
      console.log("Subscription payment already applied:", paymentRefId);
      return;
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const expiresAt = planExpiryDate();
    const paidRupees = amountPKR
      ? Math.round(Number(amountPKR))
      : fromStripeAmountPkr(amountFallback);

    await subRef.set(
      {
        plan: plan,
        status: "active",
        startedAt: now,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        updatedAt: now,
        adminGranted: false,
      },
      { merge: true }
    );

    await subRef.update({
      history: admin.firestore.FieldValue.arrayUnion({
        plan: plan,
        action: "purchased",
        date: new Date(),
        amountPaid: paidRupees,
        stripePaymentIntentId: paymentRefId || "",
      }),
    });

    const companyDoc = await admin.firestore().collection("companies").doc(companyId).get();
    const companyName = companyDoc.data()?.name || companyDoc.data()?.companyName || "A company";

    await admin.firestore().collection("companies").doc(companyId).set(
      {
        plan: plan,
        planExpiry: admin.firestore.Timestamp.fromDate(expiresAt),
        status: "active",
        aiEnabled: plan === "basic" || plan === "premium",
      },
      { merge: true }
    );

    // Trigger Admin Notification
    const adminUids = await getAdminUids();
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'payment',
        title: 'New Subscription Payment',
        body: `${companyName} successfully paid for the ${plan.charAt(0).toUpperCase() + plan.slice(1)} plan.`,
        data: {
          companyId,
          companyName,
          plan,
          amount: paidRupees,
          stripeId: paymentRefId,
          paymentType: 'subscription'
        }
      });
    }

    return;
  }

  if (type === "commission") {
    if (!transactionIds) {
      throw new Error("Commission payment missing transactionIds in metadata");
    }
    const ids = String(transactionIds).split(",").filter(Boolean);
    if (!ids.length) {
      throw new Error("Commission payment has empty transactionIds");
    }
    
    const paidRupees = amountPKR
      ? Math.round(Number(amountPKR))
      : fromStripeAmountPkr(amountFallback);

    const batch = admin.firestore().batch();
    ids.forEach((id) => {
      batch.set(
        admin.firestore().collection("transactions").doc(id),
        {
          status: "settled",
          settledAt: admin.firestore.FieldValue.serverTimestamp(),
          stripePaymentId: paymentRefId || "",
        },
        { merge: true }
      );
    });
    await batch.commit();

    // Notify Admin of Commission Payment
    let supplierName = "A supplier";
    const sId = supplierId || metadata.supplierId;
    if (sId) {
      const sDoc = await admin.firestore().collection('suppliers').doc(sId).get();
      supplierName = sDoc.data()?.businessName || sDoc.data()?.name || supplierName;
    }

    const adminUids = await getAdminUids();
    for (const adminUid of adminUids) {
      await writeNotificationRecord(adminUid, {
        type: 'commission',
        title: 'Commission Payment Received',
        body: `Commission payment received from ${supplierName} for ${ids.length} order(s).`,
        data: {
          supplierId: sId,
          supplierName,
          transactionIds: String(transactionIds),
          amount: paidRupees,
          stripeId: paymentRefId,
          paymentType: 'commission'
        }
      });
    }
  }
}

async function createSubscriptionCheckout({
  plan,
  companyId,
  successUrl,
  cancelUrl,
}) {
  const amountPKR = SUBSCRIPTION_PLANS_PKR[plan];
  if (!amountPKR) throw new Error("Unknown plan: " + plan);
  if (!companyId) throw new Error("companyId is required");
  if (!successUrl || !cancelUrl) {
    throw new Error("successUrl and cancelUrl are required");
  }

  const stripe = getStripe();
  const metadata = subscriptionMeta(plan, companyId, amountPKR);
  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    payment_method_types: ["card"],
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency: "pkr",
          unit_amount: toStripeAmountPkr(amountPKR),
          product_data: {
            name: `RateBridge ${String(plan).toUpperCase()} plan`,
            description: "Monthly subscription",
          },
        },
      },
    ],
    success_url: successUrl,
    cancel_url: cancelUrl,
    client_reference_id: companyId,
    metadata,
    payment_intent_data: { metadata },
  });
  if (!session.url) throw new Error("Checkout session missing URL");
  return { url: session.url, amountPKR };
}

async function createCommissionCheckout({
  supplierId,
  amountPKR,
  transactionIds,
  successUrl,
  cancelUrl,
}) {
  const rupees = Math.round(Number(amountPKR));
  if (!Number.isFinite(rupees) || rupees <= 0) {
    throw new Error("Invalid amountPKR");
  }
  if (!transactionIds || !transactionIds.length) {
    throw new Error("transactionIds are required");
  }
  if (!successUrl || !cancelUrl) {
    throw new Error("successUrl and cancelUrl are required");
  }

  const stripe = getStripe();
  const metadata = commissionMeta(supplierId, transactionIds, rupees);
  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    payment_method_types: ["card"],
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency: "pkr",
          unit_amount: toStripeAmountPkr(rupees),
          product_data: {
            name: "RateBridge commission settlement",
          },
        },
      },
    ],
    success_url: successUrl,
    cancel_url: cancelUrl,
    metadata,
    payment_intent_data: { metadata },
  });
  if (!session.url) throw new Error("Checkout session missing URL");
  return { url: session.url, amountPKR: rupees };
}

async function createSubscriptionPaymentIntent({ plan, companyId }) {
  const amountPKR = SUBSCRIPTION_PLANS_PKR[plan];
  if (!amountPKR) throw new Error("Unknown plan: " + plan);
  if (!companyId) throw new Error("companyId is required");

  const stripe = getStripe();
  const metadata = subscriptionMeta(plan, companyId, amountPKR);
  const paymentIntent = await stripe.paymentIntents.create({
    amount: toStripeAmountPkr(amountPKR),
    currency: "pkr",
    automatic_payment_methods: { enabled: true },
    metadata,
  });
  return { clientSecret: paymentIntent.client_secret, amountPKR };
}

async function createCommissionPaymentIntent({
  supplierId,
  amountPKR,
  transactionIds,
}) {
  const rupees = Math.round(Number(amountPKR));
  if (!Number.isFinite(rupees) || rupees <= 0) {
    throw new Error("Invalid amountPKR");
  }
  if (!transactionIds || !transactionIds.length) {
    throw new Error("transactionIds are required");
  }

  const stripe = getStripe();
  const metadata = commissionMeta(supplierId, transactionIds, rupees);
  const paymentIntent = await stripe.paymentIntents.create({
    amount: toStripeAmountPkr(rupees),
    currency: "pkr",
    automatic_payment_methods: { enabled: true },
    metadata,
  });
  return { clientSecret: paymentIntent.client_secret, amountPKR: rupees };
}

/**
 * Firestore job trigger — same pattern as onAiJobCreated.
 * Client writes stripe_jobs/{id} with status=pending, then waits until
 * status is complete|error. 512MB / 120s reduces cold-start timeouts.
 */
exports.onStripeJobCreated = functions
  .region("us-central1")
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .firestore.document("stripe_jobs/{jobId}")
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const uid = typeof data.uid === "string" ? data.uid : "";
    const mode = data.mode === "payment_sheet" ? "payment_sheet" : "checkout";
    const type = data.type === "commission" ? "commission" : "subscription";

    // Mark processing immediately so the client knows the trigger fired
    // (and so cold starts are visible vs a silent hang).
    try {
      await snap.ref.update({
        status: "processing",
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.warn("Could not mark stripe job processing:", e.message || e);
    }

    if (!uid) {
      await snap.ref.update({
        status: "error",
        error: "Missing uid.",
      });
      return;
    }

    try {
      let result;
      if (mode === "checkout") {
        if (type === "subscription") {
          result = await createSubscriptionCheckout({
            plan: data.plan,
            companyId: data.companyId,
            successUrl: data.successUrl,
            cancelUrl: data.cancelUrl,
          });
        } else {
          result = await createCommissionCheckout({
            supplierId: uid,
            amountPKR: data.amountPKR,
            transactionIds: data.transactionIds,
            successUrl: data.successUrl,
            cancelUrl: data.cancelUrl,
          });
        }
        await snap.ref.update({
          status: "complete",
          url: result.url,
          amountPKR: result.amountPKR,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // payment_sheet (mobile)
      if (type === "subscription") {
        result = await createSubscriptionPaymentIntent({
          plan: data.plan,
          companyId: data.companyId,
        });
      } else {
        result = await createCommissionPaymentIntent({
          supplierId: uid,
          amountPKR: data.amountPKR,
          transactionIds: data.transactionIds,
        });
      }
      await snap.ref.update({
        status: "complete",
        clientSecret: result.clientSecret,
        amountPKR: result.amountPKR,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("onStripeJobCreated error:", error);
      await snap.ref.update({
        status: "error",
        error: publicStripeError(error),
      });
    }
  });

/**
 * Verifies a Checkout Session is paid when the client returns session_id=cs_...
 * Returns metadata + amount from Stripe (source of truth).
 */
async function verifyCheckoutSessionIfPresent(paymentRefId) {
  const ref = typeof paymentRefId === "string" ? paymentRefId.trim() : "";
  if (!ref.startsWith("cs_")) return null;

  const stripe = getStripe();
  const session = await stripe.checkout.sessions.retrieve(ref);
  if (!session || session.payment_status !== "paid") {
    throw new Error("Checkout payment is not completed yet.");
  }
  return {
    metadata: session.metadata || {},
    amountTotal: session.amount_total,
    paymentRef: session.payment_intent || session.id,
  };
}

/**
 * Client writes stripe_activate_jobs after Checkout success.
 * Admin SDK applies the plan / commission settle — bypasses client permission issues.
 * Supports type=subscription (default) and type=commission.
 */
exports.onStripeActivateJobCreated = functions
  .region("us-central1")
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .firestore.document("stripe_activate_jobs/{jobId}")
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const uid = typeof data.uid === "string" ? data.uid : "";
    const type = data.type === "commission" ? "commission" : "subscription";
    const paymentRefRaw =
      typeof data.paymentRefId === "string" ? data.paymentRefId.trim() : "";

    try {
      await snap.ref.update({
        status: "processing",
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (!uid) {
      await snap.ref.update({
        status: "error",
        error: "uid is required.",
      });
      return;
    }

    try {
      const verified = await verifyCheckoutSessionIfPresent(paymentRefRaw);

      if (type === "commission") {
        const ids = Array.isArray(data.transactionIds)
          ? data.transactionIds
          : String(data.transactionIds || "")
              .split(",")
              .map((v) => String(v || "").trim())
              .filter(Boolean);
        if (!ids.length) {
          throw new Error("transactionIds are required for commission settle.");
        }

        const meta = verified?.metadata || {};
        await applySuccessfulPayment(
          {
            type: "commission",
            supplierId: meta.supplierId || uid,
            transactionIds: meta.transactionIds || ids.join(","),
            amountPKR:
              meta.amountPKR ||
              (data.amountPKR != null ? String(data.amountPKR) : ""),
          },
          verified?.amountTotal ||
            toStripeAmountPkr(data.amountPKR || 0),
          verified?.paymentRef || paymentRefRaw || `activate_${snap.id}`
        );
      } else {
        const companyId =
          typeof data.companyId === "string" ? data.companyId.trim() : "";
        const plan = typeof data.plan === "string" ? data.plan.trim() : "";
        const amountPKR = data.amountPKR;

        const meta = verified?.metadata || {};
        const effectiveCompanyId = meta.companyId || companyId;
        const effectivePlan = meta.plan || plan;

        if (!effectiveCompanyId || !SUBSCRIPTION_PLANS_PKR[effectivePlan]) {
          throw new Error(
            "companyId and a valid plan are required for subscription activation."
          );
        }

        // When a Checkout Session is present, require metadata to match the job.
        if (verified) {
          if (
            meta.companyId &&
            meta.companyId !== effectiveCompanyId
          ) {
            throw new Error("Checkout company does not match activation request.");
          }
          if (meta.plan && meta.plan !== effectivePlan) {
            throw new Error("Checkout plan does not match activation request.");
          }
        }

        await applySuccessfulPayment(
          {
            type: "subscription",
            companyId: effectiveCompanyId,
            plan: effectivePlan,
            amountPKR: String(
              meta.amountPKR ||
                (amountPKR != null
                  ? amountPKR
                  : SUBSCRIPTION_PLANS_PKR[effectivePlan])
            ),
          },
          verified?.amountTotal ||
            toStripeAmountPkr(SUBSCRIPTION_PLANS_PKR[effectivePlan]),
          verified?.paymentRef || paymentRefRaw || `activate_${snap.id}`
        );
      }

      await snap.ref.update({
        status: "complete",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("onStripeActivateJobCreated error:", error);
      await snap.ref.update({
        status: "error",
        error: publicStripeError(error),
      });
    }
  });

/** HTTP webhook — Stripe → Firestore activation / settlement. */
exports.stripeWebhook = functions
  .region("us-central1")
  .runWith({ timeoutSeconds: 60, memory: "512MB" })
  .https.onRequest(async (req, res) => {
    const sig = req.headers["stripe-signature"];
    const webhookSecret =
      process.env.STRIPE_WEBHOOK_SECRET ||
      functions.config().stripe?.webhook_secret;

    if (!webhookSecret) {
      console.error("Missing STRIPE_WEBHOOK_SECRET configuration");
      return res.status(500).send("Webhook configuration missing");
    }

    let event;
    try {
      const stripe = getStripe();
      event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    } catch (err) {
      console.error("Webhook signature verification failed:", err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    try {
      if (event.type === "payment_intent.succeeded") {
        const intent = event.data.object;
        await applySuccessfulPayment(intent.metadata, intent.amount, intent.id);
      } else if (event.type === "checkout.session.completed") {
        const session = event.data.object;
        if (session.payment_status === "paid") {
          await applySuccessfulPayment(
            session.metadata,
            session.amount_total,
            session.payment_intent || session.id
          );
        }
      }
      res.json({ received: true });
    } catch (err) {
      // Return 5xx so Stripe retries instead of silently dropping the update.
      console.error("Error updating Firestore after payment:", err);
      res.status(500).send("Webhook handler failed");
    }
  });
