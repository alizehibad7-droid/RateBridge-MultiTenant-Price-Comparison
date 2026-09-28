const functions = require("firebase-functions");
const admin = require("firebase-admin");

/**
 * Lazy initialization helper for Stripe to prevent top-level crashes
 * during deployment or when config is missing.
 */
function getStripe() {
  const secretKey = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key;
  if (!secretKey) {
    throw new Error("STRIPE_SECRET_KEY is not configured. Use firebase functions:config:set stripe.secret_key=\"...\" or set the environment variable.");
  }
  return require("stripe")(secretKey);
}

// Fixed PKR pricing — server decides the amount, client only sends the plan key.
const SUBSCRIPTION_PLANS_PKR = {
  basic: 1000,   // 1000 PKR
  premium: 5000, // 5000 PKR
};

exports.createSubscriptionPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required");
  }

  const { plan } = data;
  const companyId = context.auth.token.companyId;

  const amountPKR = SUBSCRIPTION_PLANS_PKR[plan];
  if (!amountPKR) {
    throw new functions.https.HttpsError("invalid-argument", "Unknown plan: " + plan);
  }

  try {
    const stripe = getStripe();
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountPKR,
      currency: "pkr",
      metadata: {
        type: "subscription",
        companyId: companyId || "",
        plan: plan,
      },
    });

    return { clientSecret: paymentIntent.client_secret, amountPKR };
  } catch (error) {
    console.error("Stripe Subscription Error:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.createCommissionPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required");
  }

  const { amountPKR, transactionIds } = data;
  const supplierId = context.auth.uid;

  if (!amountPKR || !transactionIds || !transactionIds.length) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "amountPKR and transactionIds are required"
    );
  }

  try {
    const stripe = getStripe();
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amountPKR),
      currency: "pkr",
      metadata: {
        type: "commission",
        supplierId: supplierId,
        transactionIds: transactionIds.join(","),
        amountPKR: amountPKR,
      },
    });

    return { clientSecret: paymentIntent.client_secret, amountPKR };
  } catch (error) {
    console.error("Stripe Commission Error:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  let event;

  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || functions.config().stripe?.webhook_secret;

  if (!webhookSecret) {
    console.error("Missing STRIPE_WEBHOOK_SECRET configuration");
    return res.status(500).send("Webhook configuration missing");
  }

  try {
    const stripe = getStripe();
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error("Webhook signature verification failed:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === "payment_intent.succeeded") {
    const intent = event.data.object;
    const { type, companyId, supplierId, plan, transactionIds } = intent.metadata;
    try {
      if (type === "subscription" && companyId) {
        const now = admin.firestore.FieldValue.serverTimestamp();
        // 1. Update the official subscription record
        await admin.firestore().collection("subscriptions").doc(companyId).set({
          plan: plan,
          status: "active",
          startedAt: now,
          updatedAt: now,
        }, { merge: true });

        // 2. Add to history
        await admin.firestore().collection("subscriptions").doc(companyId).update({
          history: admin.firestore.FieldValue.arrayUnion({
            plan: plan,
            action: "purchased",
            date: new Date(),
            amountPaid: intent.amount,
            stripePaymentIntentId: intent.id,
          })
        });

        // 3. Update the company doc for field user inheritance and UI
        await admin.firestore().collection("companies").doc(companyId).update({
          plan: plan,
          aiEnabled: plan !== 'free',
          status: "active",
        });

      } else if (type === "commission" && transactionIds) {
        const ids = transactionIds.split(",");
        const batch = admin.firestore().batch();
        ids.forEach((id) => {
          batch.update(admin.firestore().collection("transactions").doc(id), {
            status: "settled",
            settledAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        await batch.commit();
      }
    } catch (err) {
      console.error("Error updating Firestore after payment:", err);
    }
  }
  res.json({ received: true });
});
