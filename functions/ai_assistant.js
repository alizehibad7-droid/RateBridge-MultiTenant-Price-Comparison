const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { GoogleAuth } = require('google-auth-library');
const { GoogleGenerativeAI } = require('@google/generative-ai');

async function generateWithVertex(prompt) {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });
  const client = await auth.getClient();
  const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
  if (!project) {
    throw new Error('Missing GCP project id');
  }
  const location = 'us-central1';
  const model = 'gemini-2.0-flash';
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
    model: 'gemini-2.0-flash',
    generationConfig: {
      maxOutputTokens: 500,
      temperature: 0.3,
    },
  });
  const result = await model.generateContent(prompt);
  return (result.response.text() || '').trim();
}

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
    if (prompt.length > 12000) {
      throw new HttpsError('invalid-argument', 'Prompt too long.');
    }

    try {
      const apiKey = process.env.GEMINI_KEY || '';
      const text = apiKey
        ? await generateWithApiKey(prompt, apiKey)
        : await generateWithVertex(prompt);
      return { text };
    } catch (error) {
      console.error('generateAiText error:', error);
      throw new HttpsError('internal', 'AI request failed.');
    }
  },
);
