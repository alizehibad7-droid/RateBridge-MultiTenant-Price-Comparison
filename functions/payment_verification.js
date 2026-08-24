const functions = require("firebase-functions");

/**
 * DEPRECATED: Gemini OCR verification removed as per request.
 * The system now relies on manual admin review of the payment screenshot.
 */
exports.verifyPaymentScreenshot = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  }

  // Return a legacy structure to avoid breaking older clients if any, 
  // but with all AI flags disabled.
  return {
    verified: false,
    amountDetected: 0,
    transactionId: "MANUAL_REVIEW",
    dateDetected: "MANUAL_REVIEW",
    isDuplicate: false,
    error: null,
    rawStatus: 'pending'
  };
});
