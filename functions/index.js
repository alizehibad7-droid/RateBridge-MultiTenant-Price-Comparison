const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

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
  onDisputeCreated,
  onAppealCreated 
} = require('./notifications');

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

const stripeFunctions = require("./stripe");
exports.createSubscriptionPaymentIntent = stripeFunctions.createSubscriptionPaymentIntent;
exports.createCommissionPaymentIntent = stripeFunctions.createCommissionPaymentIntent;
exports.stripeWebhook = stripeFunctions.stripeWebhook;

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

// Admin Triggers
exports.onUserRegistration = onUserRegistration;
exports.onDisputeCreated = onDisputeCreated;
exports.onAppealCreated = onAppealCreated;


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
