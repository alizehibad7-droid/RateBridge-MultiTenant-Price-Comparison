const functions = require('firebase-functions');
const admin = require('firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp();
}

const { onOrderConfirmed, onCommissionEnsureJobCreated } = require('./commission');
const {
  scheduledCommissionOverdueCheck,
  onCommissionTransactionChange,
} = require('./commission_restrictions');
const { onInviteAccepted, acceptPartnershipRequest } = require('./invite_system');
const { scheduledOrderApprovalReminders } = require('./reminders');
const { 
  onNotificationCreated,
  onAdminNotificationCreated,
  onMessageSent, 
  onUserRegistration, 
  onPaymentProofCreated, 
  onDisputeCreated, 
  onAppealSubmitted,
  onOrderNotifySupplier,
  sendJoinRequestNotification,
  sendOrderNotification,
} = require('./notifications');
const { verifyPaymentScreenshot } = require('./payment_verification');
const {
  createRfq,
  submitRfqBid,
  awardRfq,
  onRfqJobCreated,
  onRfqBidJobCreated,
  onRfqAwardJobCreated,
  onRfqCancelJobCreated,
  onRfqBidWithdrawJobCreated,
} = require('./rfq');
const {
  raiseDispute,
  updateDispute,
  onDisputeJobCreated,
  onDisputeUpdateJobCreated,
  onDisputeWithdrawJobCreated,
} = require('./disputes');
const { generateAiText, onAiJobCreated } = require('./ai_assistant');
const stripeFunctions = require('./stripe');

exports.onOrderConfirmed = onOrderConfirmed;
exports.onCommissionEnsureJobCreated = onCommissionEnsureJobCreated;
exports.scheduledCommissionOverdueCheck = scheduledCommissionOverdueCheck;
exports.onCommissionTransactionChange = onCommissionTransactionChange;
exports.onInviteAccepted = onInviteAccepted;
exports.acceptPartnershipRequest = acceptPartnershipRequest;
exports.scheduledOrderApprovalReminders = scheduledOrderApprovalReminders;
exports.onMessageSent = onMessageSent;
exports.onNotificationCreated = onNotificationCreated;
exports.onAdminNotificationCreated = onAdminNotificationCreated;
exports.onOrderNotifySupplier = onOrderNotifySupplier;
exports.sendJoinRequestNotification = sendJoinRequestNotification;
exports.sendOrderNotification = sendOrderNotification;

// Admin Triggers
exports.onUserRegistration = onUserRegistration;
// Screenshot payment proofs removed — Stripe-only payments.
// exports.onPaymentProofCreated = onPaymentProofCreated;
exports.onDisputeCreated = onDisputeCreated;
// Canonical name + alias for older deploy references.
exports.onAppealSubmitted = onAppealSubmitted;
exports.onAppealCreated = onAppealSubmitted;

// exports.verifyPaymentScreenshot = verifyPaymentScreenshot;
exports.createRfq = createRfq;
exports.submitRfqBid = submitRfqBid;
exports.awardRfq = awardRfq;
exports.onRfqJobCreated = onRfqJobCreated;
exports.onRfqBidJobCreated = onRfqBidJobCreated;
exports.onRfqAwardJobCreated = onRfqAwardJobCreated;
exports.onRfqCancelJobCreated = onRfqCancelJobCreated;
exports.onRfqBidWithdrawJobCreated = onRfqBidWithdrawJobCreated;
exports.raiseDispute = raiseDispute;
exports.onDisputeJobCreated = onDisputeJobCreated;
exports.updateDispute = updateDispute;
exports.onDisputeUpdateJobCreated = onDisputeUpdateJobCreated;
exports.onDisputeWithdrawJobCreated = onDisputeWithdrawJobCreated;
exports.generateAiText = generateAiText;
exports.onAiJobCreated = onAiJobCreated;

exports.onStripeJobCreated = stripeFunctions.onStripeJobCreated;
exports.onStripeActivateJobCreated = stripeFunctions.onStripeActivateJobCreated;
exports.stripeWebhook = stripeFunctions.stripeWebhook;
