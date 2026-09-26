require("dotenv").config();
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const stripe = require("stripe")(process.env.STRIPE_SECRET);
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// Subscription plan prices in PKR
const SUBSCRIPTION_PLANS = {
  basic: 1000,
  premium: 5000,
};

// --- Subscription Payments ---
exports.stripeCreateSubscriptionPaymentIntent = onCall(async (request) => {
  try {
    const {plan} = request.data;

    if (!plan || !SUBSCRIPTION_PLANS[plan]) {
      throw new HttpsError(
          "invalid-argument",
          "Invalid or missing plan. Must be 'basic' or 'premium'.",
      );
    }

    const amountPKR = SUBSCRIPTION_PLANS[plan];

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountPKR, // whole PKR unit
      currency: "pkr",
      payment_method_types: ["card"],
      metadata: {
        type: "subscription",
        plan: plan,
      },
    });

    return {clientSecret: paymentIntent.client_secret};
  } catch (error) {
    console.error("Subscription payment error:", error);
    throw new HttpsError("internal", error.message);
  }
});

// --- Commission Payments ---
exports.stripeCreateCommissionPaymentIntent = onCall(async (request) => {
  try {
    const {transactionIds} = request.data;

    if (!transactionIds || !Array.isArray(transactionIds) ||
        transactionIds.length === 0) {
      throw new HttpsError(
          "invalid-argument",
          "transactionIds array is required.",
      );
    }

    // Fetch each transaction from Firestore and sum the real
    // commissionAmount stored on each doc — never trust an amount
    // sent directly from the app.
    let totalCommission = 0;
    const validTransactionIds = [];

    for (const txId of transactionIds) {
      const docSnap = await db.collection("transactions").doc(txId).get();

      if (!docSnap.exists) {
        console.warn(`Transaction ${txId} not found, skipping.`);
        continue;
      }

      const data = docSnap.data();

      if (data.status !== "settled") {
        console.warn(`Transaction ${txId} is not settled, skipping.`);
        continue;
      }

      const commissionAmount = data.commissionAmount;
      if (typeof commissionAmount !== "number" || commissionAmount <= 0) {
        console.warn(`Transaction ${txId} has invalid commissionAmount.`);
        continue;
      }

      totalCommission += commissionAmount;
      validTransactionIds.push(txId);
    }

    if (totalCommission <= 0) {
      throw new HttpsError(
          "invalid-argument",
          "No valid, settled transactions found for the given IDs.",
      );
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(totalCommission), // whole PKR unit
      currency: "pkr",
      payment_method_types: ["card"],
      metadata: {
        type: "commission",
        transactionIds: validTransactionIds.join(","),
        totalCommissionPKR: totalCommission,
      },
    });

    return {clientSecret: paymentIntent.client_secret};
  } catch (error) {
    console.error("Commission payment error:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message);
  }
});
