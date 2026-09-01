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
    model: 'gemini-3.6-flash',
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
      model: 'groq/compound-mini',
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
      console.warn('Groq path failed:', error.message || error);
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
      console.warn('Gemini API key path failed, trying Vertex:', error.message || error);
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
      console.warn(`Vertex model ${model} failed:`, error.message || error);
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
    return 'AI provider authentication failed. Set GROQ_API_KEY or GEMINI_KEY for the Cloud Function.';
  }
  if (lower.includes('429') || lower.includes('rate limit') || lower.includes('resource exhausted')) {
    return 'AI provider rate limit reached. Try again shortly.';
  }
  if (lower.includes('timeout') || lower.includes('etimedout') || lower.includes('deadline')) {
    return 'The AI provider timed out. Please try again.';
  }
  if (lower.includes('empty response')) {
    return 'The assistant returned an empty response.';
  }
  return raw.slice(0, 280);
}

// Firestore trigger — no public HTTP/IAM. Flutter writes ai_jobs/{id} and
// listens for the response. This avoids the 403 on generateAiText.
exports.onAiJobCreated = functions
  .region('us-central1')
  .runWith({ timeoutSeconds: 60, memory: '256MB' })
  .firestore.document('ai_jobs/{jobId}')
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const prompt = typeof data.prompt === 'string' ? data.prompt.trim() : '';
    if (!prompt) {
      await snap.ref.update({ status: 'error', error: 'Missing prompt.' });
      return;
    }
    if (prompt.length > 12000) {
      await snap.ref.update({ status: 'error', error: 'Prompt too long.' });
      return;
    }
    try {
      const text = await generateText(prompt);
      await snap.ref.update({
        status: 'complete',
        text: text || '',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('onAiJobCreated error:', error);
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
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Auth required.');
    }
    const prompt =
      typeof request.data?.prompt === 'string' ? request.data.prompt.trim() : '';
    if (!prompt) {
      throw new HttpsError('invalid-argument', 'Missing prompt.');
    }
    try {
      const text = await generateText(prompt);
      return { text };
    } catch (error) {
      console.error('generateAiText error:', error);
      throw new HttpsError('internal', publicAiError(error));
    }
  },
);
