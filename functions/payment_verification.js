const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const axios = require("axios");

function readGeminiKey() {
  if (process.env.GEMINI_KEY) return process.env.GEMINI_KEY;
  try {
    return functions.config().gemini?.key || "";
  } catch (_) {
    return "";
  }
}

// Expects: firebase functions:config:set gemini.key="YOUR_KEY"
const GENAI_API_KEY = readGeminiKey();
const genAI = new GoogleGenerativeAI(GENAI_API_KEY);

exports.verifyPaymentScreenshot = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  }

  const { imageUrl } = data;
  if (!imageUrl) {
    throw new functions.https.HttpsError("invalid-argument", "Missing image URL.");
  }

  try {
    // 1. Fetch image and convert to Base64
    const response = await axios.get(imageUrl, { responseType: 'arraybuffer' });
    const imageBase64 = Buffer.from(response.data, 'binary').toString('base64');

    // 2. Setup Gemini Model
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    const prompt = `
      Extract payment info from this screenshot in strict JSON format:
      {
        "amount": (number),
        "transaction_id": (string),
        "status": ("success" | "failed"),
        "date": (string)
      }
      Rules:
      - Map 'Sent', 'Successful', 'Transferred', 'Paid' to "success".
      - Map anything else or error to "failed".
      - Return ONLY the JSON object. No markdown.
    `;

    const result = await model.generateContent([
      prompt,
      { inlineData: { data: imageBase64, mimeType: "image/jpeg" } }
    ]);

    const rawText = result.response.text().trim();
    let parsedResult;
    try {
      const cleanJson = rawText.replace(/```json/g, "").replace(/```/g, "").trim();
      parsedResult = JSON.parse(cleanJson);
    } catch (parseError) {
      console.error("JSON Error. Raw:", rawText);
      throw new functions.https.HttpsError("internal", "AI response parse failed.");
    }

    // 3. Duplicate Check in Firestore
    let isDuplicate = false;
    let duplicateMessage = null;

    if (parsedResult.transaction_id) {
      const duplicateQuery = await admin.firestore()
        .collection("payment_proofs")
        .where("transactionIdDetected", "==", parsedResult.transaction_id)
        .where("status", "==", "approved")
        .limit(1)
        .get();

      if (!duplicateQuery.empty) {
        isDuplicate = true;
        duplicateMessage = "This Transaction ID has already been used and approved.";
      }
    }

    return {
      verified: !isDuplicate && parsedResult.status === 'success',
      amountDetected: parsedResult.amount || 0,
      transactionId: parsedResult.transaction_id || "NOT_FOUND",
      dateDetected: parsedResult.date || "NOT_FOUND",
      isDuplicate: isDuplicate,
      error: duplicateMessage,
      rawStatus: parsedResult.status
    };

  } catch (error) {
    console.error("Gemini Cloud Function Error:", error);
    throw new functions.https.HttpsError(
      "internal",
      error.message || "An unexpected error occurred during verification."
    );
  }
});
