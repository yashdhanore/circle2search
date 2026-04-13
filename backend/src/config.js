const DEFAULT_ENDPOINT = 'translate-eu.googleapis.com';
const DEFAULT_LOCATION = 'europe-west1';
const DEFAULT_MODEL = 'general/nmt';
const DEFAULT_PORT = 8080;
const DEFAULT_MAX_CODE_POINTS = 5000;
const DEFAULT_MAX_BLOCKS = 100;
const DEFAULT_EXPECTED_BUNDLE_ID = 'com.circle2search.app';
const DEFAULT_RECEIPT_CACHE_TTL_SECONDS = 21600;
const DEFAULT_RATE_LIMIT_WINDOW_SECONDS = 60;
const DEFAULT_RATE_LIMIT_MAX_REQUESTS = 30;
const DEFAULT_BASIC_ENDPOINT = 'translation.googleapis.com';

function loadConfig(env = process.env) {
  const basicAPIKey = (env.GOOGLE_TRANSLATE_API_KEY || '').trim();
  const translationMode = basicAPIKey ? 'basic_api_key' : 'advanced_service_account';
  const projectId = (env.GOOGLE_CLOUD_PROJECT || env.GCLOUD_PROJECT || '').trim();

  if (translationMode === 'advanced_service_account' && !projectId) {
    throw new Error('GOOGLE_CLOUD_PROJECT is required when GOOGLE_TRANSLATE_API_KEY is not set.');
  }

  const endpoint = translationMode === 'basic_api_key'
    ? (env.GOOGLE_TRANSLATE_BASIC_ENDPOINT || DEFAULT_BASIC_ENDPOINT).trim()
    : (env.GOOGLE_TRANSLATE_ENDPOINT || DEFAULT_ENDPOINT).trim();
  const location = (env.GOOGLE_TRANSLATE_LOCATION || DEFAULT_LOCATION).trim();
  const model = (env.GOOGLE_TRANSLATE_MODEL || DEFAULT_MODEL).trim();

  if (translationMode === 'advanced_service_account') {
    if (endpoint !== DEFAULT_ENDPOINT) {
      throw new Error(`Only the EU endpoint is supported. Expected ${DEFAULT_ENDPOINT}.`);
    }

    if (!location.startsWith('europe-')) {
      throw new Error('GOOGLE_TRANSLATE_LOCATION must be an EU region such as europe-west1.');
    }

    if (model !== DEFAULT_MODEL) {
      throw new Error(`Only the Google NMT model (${DEFAULT_MODEL}) is supported.`);
    }
  }

  const defaultLabels = parseJsonObject(env.GOOGLE_TRANSLATE_LABELS_JSON, 'GOOGLE_TRANSLATE_LABELS_JSON');
  const sharedSecret = (env.TRANSLATE_SHARED_SECRET || '').trim();
  const expectedBundleID = (env.APP_STORE_EXPECTED_BUNDLE_ID || DEFAULT_EXPECTED_BUNDLE_ID).trim();
  const port = parseInteger(env.PORT, DEFAULT_PORT, 'PORT');
  const maxCodePoints = parseInteger(env.TRANSLATE_MAX_CODE_POINTS, DEFAULT_MAX_CODE_POINTS, 'TRANSLATE_MAX_CODE_POINTS');
  const maxBlocks = parseInteger(env.TRANSLATE_MAX_BLOCKS, DEFAULT_MAX_BLOCKS, 'TRANSLATE_MAX_BLOCKS');
  const receiptCacheTTLSeconds = parseInteger(
    env.APP_STORE_RECEIPT_CACHE_TTL_SECONDS,
    DEFAULT_RECEIPT_CACHE_TTL_SECONDS,
    'APP_STORE_RECEIPT_CACHE_TTL_SECONDS'
  );
  const rateLimitWindowSeconds = parseInteger(
    env.TRANSLATE_RATE_LIMIT_WINDOW_SECONDS,
    DEFAULT_RATE_LIMIT_WINDOW_SECONDS,
    'TRANSLATE_RATE_LIMIT_WINDOW_SECONDS'
  );
  const rateLimitMaxRequests = parseInteger(
    env.TRANSLATE_RATE_LIMIT_MAX_REQUESTS,
    DEFAULT_RATE_LIMIT_MAX_REQUESTS,
    'TRANSLATE_RATE_LIMIT_MAX_REQUESTS'
  );
  const allowLocalhostWithoutAuth = parseBoolean(
    env.TRANSLATE_ALLOW_LOCALHOST_WITHOUT_AUTH,
    true,
    'TRANSLATE_ALLOW_LOCALHOST_WITHOUT_AUTH'
  );
  const requestBodyLimitBytes = parseInteger(
    env.TRANSLATE_MAX_REQUEST_BYTES,
    256 * 1024,
    'TRANSLATE_MAX_REQUEST_BYTES'
  );

  return {
    translationMode,
    basicAPIKey,
    projectId,
    endpoint,
    location,
    model,
    port,
    maxCodePoints,
    maxBlocks,
    requestBodyLimitBytes,
    defaultLabels,
    sharedSecret,
    expectedBundleID,
    receiptCacheTTLSeconds,
    rateLimitWindowSeconds,
    rateLimitMaxRequests,
    allowLocalhostWithoutAuth,
    googleAccessTokenOverride: (env.GOOGLE_ACCESS_TOKEN || '').trim(),
  };
}

function parseInteger(value, fallback, name) {
  if (value == null || String(value).trim() === '') {
    return fallback;
  }

  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer.`);
  }

  return parsed;
}

function parseJsonObject(value, name) {
  if (value == null || String(value).trim() === '') {
    return {};
  }

  let parsed;
  try {
    parsed = JSON.parse(value);
  } catch {
    throw new Error(`${name} must contain valid JSON.`);
  }

  if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error(`${name} must be a JSON object.`);
  }

  return parsed;
}

function parseBoolean(value, fallback, name) {
  if (value == null || String(value).trim() === '') {
    return fallback;
  }

  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) {
    return true;
  }

  if (['0', 'false', 'no', 'off'].includes(normalized)) {
    return false;
  }

  throw new Error(`${name} must be a boolean value.`);
}

module.exports = {
  loadConfig,
  DEFAULT_ENDPOINT,
  DEFAULT_LOCATION,
  DEFAULT_MODEL,
  DEFAULT_BASIC_ENDPOINT,
};
