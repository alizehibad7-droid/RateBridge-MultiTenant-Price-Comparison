const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

/** Models this project's Groq key can actually call (verified via /v1/models). */
const GROQ_MODEL_CANDIDATES = [
  process.env.GROQ_MODEL,
  'openai/gpt-oss-20b',
  'qwen/qwen3.8-27b',
  'allam-2-7b',
].filter(Boolean);

function readGroqKey() {
  if (process.env.GROQ_API_KEY) return process.env.GROQ_API_KEY;
  try {
    return functions.config().groq?.key || '';
  } catch (_) {
    return '';
  }
}

function isModelUnavailableError(error) {
  const status = error?.response?.status;
  const code = String(error?.response?.data?.error?.code || '').toLowerCase();
  const msg = String(error?.response?.data?.error?.message || error?.message || '').toLowerCase();
  return (
    status === 404 ||
    code === 'model_not_found' ||
    (msg.includes('model') && (msg.includes('not found') || msg.includes('do not have access')))
  );
}

async function callGroqOnce(prompt, apiKey, model) {
  const res = await axios.post(
    'https://api.groq.com/openai/v1/chat/completions',
    {
      model,
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
      validateStatus: () => true,
    },
  );

  if (res.status >= 200 && res.status < 300) {
    const content = String(
      res.data?.choices?.[0]?.message?.content ||
        res.data?.choices?.[0]?.message?.reasoning ||
        '',
    ).trim();
    return content;
  }

  const err = new Error(
    res.data?.error?.message || `Request failed with status code ${res.status}`,
  );
  err.response = {
    status: res.status,
    data: res.data,
  };
  throw err;
}

async function generateWithGroq(prompt, apiKey) {
  let lastError;
  const tried = [];

  for (const model of GROQ_MODEL_CANDIDATES) {
    if (tried.includes(model)) continue;
    tried.push(model);
    try {
      const text = await callGroqOnce(prompt, apiKey, model);
      console.log(`AI provider used: groq model=${model}`);
      return text;
    } catch (error) {
      lastError = error;
      const detail =
        error?.response?.data?.error?.message || error?.message || String(error);
      console.error(`Groq model failed (${model}): ${detail}`);
      if (!isModelUnavailableError(error)) {
        throw error;
      }
    }
  }

  throw lastError || new Error('No Groq model available for this API key.');
}

async function generateText(prompt) {
  const groqKey = readGroqKey();
  if (!groqKey) {
    throw new Error('GROQ_API_KEY is not configured for Cloud Functions.');
  }

  const text = await generateWithGroq(prompt, groqKey);
  if (!text) {
    throw new Error('AI returned an empty response.');
  }
  return text;
}

function publicAiError(error) {
  const status = error?.response?.status;
  const apiMsg = error?.response?.data?.error?.message;
  const raw = String(apiMsg || error?.message || error || 'AI request failed.');
  const lower = raw.toLowerCase();
  if (
    lower.includes('api key') ||
    lower.includes('unauthenticated') ||
    lower.includes('401') ||
    status === 401 ||
    lower.includes('permission') ||
    lower.includes('groq_api_key')
  ) {
    return 'AI provider authentication failed. Set GROQ_API_KEY for the Cloud Function.';
  }
  if (isModelUnavailableError(error)) {
    return 'AI model is unavailable for this Groq account. Check allowed models in Groq console.';
  }
  if (
    status === 429 ||
    lower.includes('429') ||
    lower.includes('rate limit') ||
    lower.includes('resource exhausted')
  ) {
    return 'AI provider rate limit reached. Try again shortly.';
  }
  if (lower.includes('timeout') || lower.includes('etimedout') || lower.includes('deadline')) {
    return 'The AI provider timed out. Please try again.';
  }
  if (lower.includes('empty response')) {
    return 'The assistant returned an empty response.';
  }
  if (lower.startsWith('request failed with status code')) {
    return 'The AI service is temporarily unavailable. Please try again.';
  }
  return raw.slice(0, 280);
}

function normalizePlan(value) {
  return String(value || '')
    .trim()
    .toLowerCase();
}

/**
 * Matches PlanLimitService.companyPlan: company.plan is the default,
 * and a subscription plan only wins when that subscription is active.
 */
function effectivePlan(companyData, subscriptionData) {
  const companyPlan = normalizePlan(companyData?.plan) || 'free';
  if (!subscriptionData) return companyPlan;

  const status = normalizePlan(subscriptionData.status);
  const expiresAt = subscriptionData.expiresAt?.toDate?.();
  const active =
    (status === 'active' || status === 'admin_granted') &&
    (!expiresAt || expiresAt.getTime() >= Date.now());

  if (active && subscriptionData.plan) {
    return normalizePlan(subscriptionData.plan) || companyPlan;
  }
  return companyPlan;
}

function planHasAiAccess(plan) {
  const hierarchy = ['free', 'basic', 'premium'];
  const planIdx = hierarchy.indexOf(normalizePlan(plan) || 'free');
  const basicIdx = hierarchy.indexOf('basic');
  return planIdx >= basicIdx;
}

async function assertAiAccessForUid(uid) {
  const userId = String(uid || '').trim();
  if (!userId) {
    throw new Error('AI features require a signed-in user.');
  }

  const userSnap = await admin.firestore().collection('users').doc(userId).get();
  const companyId = String(userSnap.data()?.companyId || '').trim();
  if (!companyId) {
    throw new Error(
      'AI features require a company account on the Basic plan or higher.',
    );
  }

  const [companySnap, subSnap] = await Promise.all([
    admin.firestore().collection('companies').doc(companyId).get(),
    admin.firestore().collection('subscriptions').doc(companyId).get(),
  ]);

  const plan = effectivePlan(
    companySnap.data(),
    subSnap.exists ? subSnap.data() : null,
  );
  if (!planHasAiAccess(plan)) {
    throw new Error(
      'AI features require the Basic plan or higher. Please ask your CEO to upgrade.',
    );
  }
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
      await assertAiAccessForUid(data.uid);
      const text = await generateText(prompt);
      await snap.ref.update({
        status: 'complete',
        text: text || '',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('onAiJobCreated error:', error?.response?.data || error);
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
      await assertAiAccessForUid(request.auth.uid);
      const text = await generateText(prompt);
      return { text };
    } catch (error) {
      console.error('generateAiText error:', error?.response?.data || error);
      const message = publicAiError(error);
      if (
        String(message).toLowerCase().includes('basic plan') ||
        String(message).toLowerCase().includes('require')
      ) {
        throw new HttpsError('permission-denied', message);
      }
      throw new HttpsError('internal', message);
    }
  },
);
