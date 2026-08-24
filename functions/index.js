const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const { onOrderConfirmed } = require('./commission');
const { onInviteAccepted, acceptPartnershipRequest } = require('./invite_system');
const { scheduledOrderApprovalReminders } = require('./reminders');
const { 
  onNotificationCreated,
  onAdminNotificationCreated,
  onMessageSent, 
  onUserRegistration, 
  onPaymentProofCreated, 
  onDisputeCreated, 
  onAppealCreated 
} = require('./notifications');
const { verifyPaymentScreenshot } = require('./payment_verification');
const { createRfq, submitRfqBid, awardRfq } = require('./rfq');
const { raiseDispute, updateDispute } = require('./disputes');
const { generateAiText } = require('./ai_assistant');

exports.onOrderConfirmed = onOrderConfirmed;
exports.onInviteAccepted = onInviteAccepted;
exports.acceptPartnershipRequest = acceptPartnershipRequest;
exports.scheduledOrderApprovalReminders = scheduledOrderApprovalReminders;
exports.onMessageSent = onMessageSent;
exports.onNotificationCreated = onNotificationCreated;
exports.onAdminNotificationCreated = onAdminNotificationCreated;

// Admin Triggers
exports.onUserRegistration = onUserRegistration;
exports.onPaymentProofCreated = onPaymentProofCreated;
exports.onDisputeCreated = onDisputeCreated;
exports.onAppealCreated = onAppealCreated;

exports.verifyPaymentScreenshot = verifyPaymentScreenshot;
exports.createRfq = createRfq;
exports.submitRfqBid = submitRfqBid;
exports.awardRfq = awardRfq;
exports.raiseDispute = raiseDispute;
exports.updateDispute = updateDispute;
exports.generateAiText = generateAiText;
