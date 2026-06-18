const functions = require('firebase-functions');
const admin = require('firebase-admin');
const stripe = require('stripe')(functions.config().stripe.secret_key);
const db = admin.firestore();

const PLAN_PRICE_IDS = {
  basic: 'price_basic_PKR_1000',
  premium: 'price_premium_PKR_5000',
};

// Stripe webhook handler
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = functions.config().stripe.webhook_secret;
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Idempotency check
  const processedRef = db.collection('processedEvents').doc(event.id);
  const processed = await processedRef.get();
  if (processed.exists) {
    return res.status(200).send('Already processed');
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object;
        const companyId = session.metadata?.companyId;
        const plan = session.metadata?.plan;
        if (!companyId || !plan) break;

        const subscriptionId = session.subscription;
        const customerId = session.customer;
        const periodEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

        const batch = db.batch();
        batch.set(db.collection('subscriptions').doc(companyId), {
          companyId,
          stripeCustomerId: customerId,
          stripeSubscriptionId: subscriptionId,
          plan,
          status: 'active',
          currentPeriodEnd: admin.firestore.Timestamp.fromDate(periodEnd),
          cancelAtPeriodEnd: false,
          lastWebhookEvent: event.id,
        });
        batch.update(db.collection('companies').doc(companyId), {
          plan,
          planExpiry: admin.firestore.Timestamp.fromDate(periodEnd),
          aiEnabled: true,
          stripeCustomerId: customerId,
          stripeSubscriptionId: subscriptionId,
        });
        await batch.commit();

        // FCM to CEO
        const companyDoc = await db.collection('companies').doc(companyId).get();
        const ceoUid = companyDoc.data()?.ceoUid;
        if (ceoUid) {
          const ceoDoc = await db.collection('users').doc(ceoUid).get();
          const fcmToken = ceoDoc.data()?.fcmToken;
          if (fcmToken) {
            await admin.messaging().send({
              token: fcmToken,
              notification: {
                title: `${plan.charAt(0).toUpperCase() + plan.slice(1)} Plan Activated!`,
                body: 'Your subscription is now active. AI features are unlocked.',
              },
              android: { channelId: 'payments_channel' },
            });
          }
        }
        break;
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object;
        const companyQuery = await db.collection('subscriptions')
          .where('stripeSubscriptionId', '==', subscription.id)
          .limit(1).get();
        if (!companyQuery.empty) {
          const companyId = companyQuery.docs[0].id;
          const batch = db.batch();
          batch.update(db.collection('subscriptions').doc(companyId), {
            plan: 'free', status: 'canceled', lastWebhookEvent: event.id,
          });
          batch.update(db.collection('companies').doc(companyId), {
            plan: 'free', aiEnabled: false,
          });
          await batch.commit();

          // FCM warning to CEO
          const companyDoc = await db.collection('companies').doc(companyId).get();
          const ceoUid = companyDoc.data()?.ceoUid;
          if (ceoUid) {
            const ceoDoc = await db.collection('users').doc(ceoUid).get();
            const fcmToken = ceoDoc.data()?.fcmToken;
            if (fcmToken) {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: 'Subscription Expired',
                  body: 'Your plan has been downgraded to Free. AI features are now locked.',
                },
                android: { channelId: 'payments_channel' },
              });
            }
          }
        }
        break;
      }

      case 'invoice.payment_failed': {
        const invoice = event.data.object;
        const companyQuery = await db.collection('subscriptions')
          .where('stripeCustomerId', '==', invoice.customer)
          .limit(1).get();
        if (!companyQuery.empty) {
          const companyId = companyQuery.docs[0].id;
          const companyDoc = await db.collection('companies').doc(companyId).get();
          const ceoUid = companyDoc.data()?.ceoUid;
          if (ceoUid) {
            const ceoDoc = await db.collection('users').doc(ceoUid).get();
            const fcmToken = ceoDoc.data()?.fcmToken;
            if (fcmToken) {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: '⚠ Payment Failed',
                  body: 'Your subscription payment failed. Update your payment method to keep AI features.',
                },
                android: { channelId: 'payments_channel', priority: 'high' },
              });
            }
          }
        }
        break;
      }

      case 'customer.subscription.updated': {
        const subscription = event.data.object;
        const companyQuery = await db.collection('subscriptions')
          .where('stripeSubscriptionId', '==', subscription.id)
          .limit(1).get();
        if (!companyQuery.empty) {
          const companyId = companyQuery.docs[0].id;
          await db.collection('subscriptions').doc(companyId).update({
            status: subscription.status,
            cancelAtPeriodEnd: subscription.cancel_at_period_end,
            lastWebhookEvent: event.id,
          });
        }
        break;
      }
    }

    // Mark as processed
    await processedRef.set({ processedAt: admin.firestore.FieldValue.serverTimestamp() });
    res.status(200).send({ received: true });

  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).send('Internal server error');
  }
});

// Create Stripe Checkout Session
exports.createCheckoutSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');

  const { plan, companyId } = data;
  if (!plan || !companyId) throw new functions.https.HttpsError('invalid-argument', 'plan and companyId required');

  const priceId = PLAN_PRICE_IDS[plan];
  if (!priceId) throw new functions.https.HttpsError('invalid-argument', `Unknown plan: ${plan}`);

  // Get or create Stripe customer
  let stripeCustomerId;
  const subDoc = await db.collection('subscriptions').doc(companyId).get();
  if (subDoc.exists && subDoc.data()?.stripeCustomerId) {
    stripeCustomerId = subDoc.data().stripeCustomerId;
  } else {
    const companyDoc = await db.collection('companies').doc(companyId).get();
    const companyData = companyDoc.data();
    const customer = await stripe.customers.create({
      metadata: { companyId },
      email: companyData?.ceoEmail || undefined,
      name: companyData?.name || undefined,
    });
    stripeCustomerId = customer.id;
  }

  const session = await stripe.checkout.sessions.create({
    customer: stripeCustomerId,
    payment_method_types: ['card'],
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `https://ratebridge.pk/subscription/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `https://ratebridge.pk/subscription/cancel`,
    metadata: { companyId, plan },
  });

  return { sessionUrl: session.url };
});

// Create Stripe Customer Portal Session
exports.createPortalSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');

  const { companyId } = data;
  const subDoc = await db.collection('subscriptions').doc(companyId).get();
  if (!subDoc.exists || !subDoc.data()?.stripeCustomerId) {
    throw new functions.https.HttpsError('not-found', 'No subscription found for this company');
  }

  const session = await stripe.billingPortal.sessions.create({
    customer: subDoc.data().stripeCustomerId,
    return_url: 'https://ratebridge.pk/subscription',
  });

  return { portalUrl: session.url };
});
