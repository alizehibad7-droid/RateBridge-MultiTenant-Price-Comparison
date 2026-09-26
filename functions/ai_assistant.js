const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { GoogleAuth } = require('google-auth-library');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const VERTEX_MODELS = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash'];

function readGeminiKey() {
  if (process.env.GEMINI_KEY) return process.env.GEMINI_KEY;
  try {
    return functions.config().gemini?.key || '';
  } catch (_) {
    return '';
  }
}

function readGroqKey() {
  if (process.env.GROQ_API_KEY) return process.env.GROQ_API_KEY;
  try {
    return functions.config().groq?.key || '';
  } catch (_) {
    return '';
  }
}

async function generateWithVertex(prompt, model) {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });
  const client = await auth.getClient();
  const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
  if (!project) {
    throw new Error('Missing GCP project id');
  }
  const location = 'us-central1';
  const url =
    `https://${location}-aiplatform.googleapis.com/v1/projects/${project}` +
    `/locations/${location}/publishers/google/models/${model}:generateContent`;

  const res = await client.request({
    url,
    method: 'POST',
    data: {
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: 500, temperature: 0.3 },
    },
  });

  const parts = res.data?.candidates?.[0]?.content?.parts || [];
  return parts.map((part) => part.text || '').join('').trim();
}

async function generateWithApiKey(prompt, apiKey) {
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: 'gemini-1.5-flash',
    generationConfig: {
      maxOutputTokens: 500,
      temperature: 0.3,
    },
  });
  const result = await model.generateContent(prompt);
  return (result.response.text() || '').trim();
}

async function generateWithGroq(prompt, apiKey) {
  const res = await axios.post(
    'https://api.groq.com/openai/v1/chat/completions',
    {
      model: 'llama3-70b-8192',
      max_tokens: 500,
      temperature: 0.3,
      messages: [{ role: 'user', content: prompt }],
    },
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 45000,
    },
  );
  const content = String(
    res.data?.choices?.[0]?.message?.content ||
      res.data?.choices?.[0]?.message?.reasoning ||
      '',
  ).trim();
  return content;
}

async function generateText(prompt) {
  const groqKey = readGroqKey();
  const apiKey = readGeminiKey();
  console.log('AI providers available:', {
    groq: Boolean(groqKey),
    gemini: Boolean(apiKey),
    vertex: true,
  });

  if (groqKey) {
    try {
      const text = await generateWithGroq(prompt, groqKey);
      if (text) {
        console.log('AI provider used: groq');
        return text;
      }
      console.warn('Groq returned an empty response');
    } catch (error) {
      console.error('[AI Provider Error] Groq failed:', {
        message: error.message,
        details: error.response?.data || 'N/A'
      });
    }
  }

  if (apiKey) {
    try {
      const text = await generateWithApiKey(prompt, apiKey);
      if (text) {
        console.log('AI provider used: gemini-api-key');
        return text;
      }
      console.warn('Gemini API key path returned an empty response');
    } catch (error) {
      console.error('[AI Provider Error] Gemini API Key failed:', {
        message: error.message,
        stack: error.stack
      });
    }
  }

  let lastError;
  for (const model of VERTEX_MODELS) {
    try {
      const text = await generateWithVertex(prompt, model);
      if (text) {
        console.log('AI provider used: vertex', model);
        return text;
      }
      console.warn(`Vertex model ${model} returned an empty response`);
    } catch (error) {
      lastError = error;
      console.error(`[AI Provider Error] Vertex model ${model} failed:`, {
        message: error.message,
        stack: error.stack
      });
    }
  }
  throw lastError || new Error('AI returned an empty response.');
}

function publicAiError(error) {
  const raw = String(error?.message || error || 'AI request failed.');
  const lower = raw.toLowerCase();
  if (
    lower.includes('api key') ||
    lower.includes('unauthenticated') ||
    lower.includes('401') ||
    lower.includes('permission')
  ) {
    return 'AI provider authentication failed. Check your API keys and project permissions.';
  }
  if (lower.includes('429') || lower.includes('rate limit') || lower.includes('resource exhausted')) {
    return 'The AI service is currently busy. Please try again in a moment.';
  }
  if (lower.includes('timeout') || lower.includes('etimedout') || lower.includes('deadline')) {
    return 'The request timed out. Please try a shorter prompt.';
  }
  return 'The AI assistant encountered an error. Please try again.';
}

// Firestore trigger — no public HTTP/IAM. Flutter writes ai_jobs/{id} and
// listens for the response. This avoids the 403 on generateAiText.
exports.onAiJobCreated = functions
  .region('us-central1')
  .runWith({ timeoutSeconds: 60, memory: '512MB' })
  .firestore.document('ai_jobs/{jobId}')
  .onCreate(async (snap, context) => {
    const jobId = context.params.jobId;
    const data = snap.data() || {};
    const prompt = typeof data.prompt === 'string' ? data.prompt.trim() : '';

    if (!prompt) {
      console.error(`[onAiJobCreated] Job ${jobId} missing prompt`);
      await snap.ref.update({ status: 'error', error: 'Missing prompt.' });
      return;
    }

    console.log(`[onAiJobCreated] Starting AI Job: ${jobId}`);

    try {
      const text = await generateText(prompt);
      await snap.ref.update({
        status: 'complete',
        text: text || '',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`[onAiJobCreated] Job ${jobId} completed successfully`);
    } catch (error) {
      console.error(`[onAiJobCreated] Job ${jobId} failed:`, {
        message: error.message,
        stack: error.stack
      });
      await snap.ref.update({
        status: 'error',
        error: publicAiError(error),
      });
    }
  });

exports.generateAiText = onCall(
  {
    region: 'us-central1',
    cors: true,
    invoker: 'public',
    timeoutSeconds: 60,
    memory: '512MiB',
    secrets: ["GEMINI_KEY", "GROQ_API_KEY"],
  },
  async (request) => {
    if (!request.auth) {
      console.error('[generateAiText] Unauthenticated request');
      throw new HttpsError('unauthenticated', 'You must be signed in to use the AI assistant.');
    }

    const uid = request.auth.uid;
    const prompt = typeof request.data?.prompt === 'string' ? request.data.prompt.trim() : '';

    if (!prompt) {
      console.error(`[generateAiText] Missing prompt from user: ${uid}`);
      throw new HttpsError('invalid-argument', 'Please provide a prompt.');
    }

    console.log(`[generateAiText] Request from UID: ${uid}. Length: ${prompt.length}`);

    try {
      const text = await generateText(prompt);
      console.log(`[generateAiText] Success for UID: ${uid}`);
      return { text };
    } catch (error) {
      console.error(`[generateAiText] Execution failed for UID: ${uid}:`, {
        message: error.message,
        stack: error.stack,
        promptPreview: prompt.slice(0, 100) + (prompt.length > 100 ? '...' : '')
      });

      throw new HttpsError('internal', publicAiError(error));
    }
  },
);
