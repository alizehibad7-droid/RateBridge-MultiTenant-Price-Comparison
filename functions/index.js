const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const { onOrderConfirmed } = require('./commission');
const { stripeWebhook, createCheckoutSession, createPortalSession } = require('./stripe_webhook');
const { onInviteAccepted } = require('./invite_system');
const { onMessageSent, onNewCEORegistration, onOrderStatusChange } = require('./notifications');

exports.onOrderConfirmed = onOrderConfirmed;
exports.stripeWebhook = stripeWebhook;
exports.createCheckoutSession = createCheckoutSession;
exports.createPortalSession = createPortalSession;
exports.onInviteAccepted = onInviteAccepted;
exports.onMessageSent = onMessageSent;
exports.onNewCEORegistration = onNewCEORegistration;
exports.onOrderStatusChange = onOrderStatusChange;
