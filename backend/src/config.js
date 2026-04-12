const DEFAULT_ENDPOINT = 'translate-eu.googleapis.com';
const DEFAULT_LOCATION = 'europe-west1';
const DEFAULT_MODEL = 'general/nmt';
const DEFAULT_PORT = 8080;
const DEFAULT_MAX_CODE_POINTS = 5000;
const DEFAULT_MAX_BLOCKS = 100;

function loadConfig(env = process.env) {
  const projectId = (env.GOOGLE_CLOUD_PROJECT || env.GCLOUD_PROJECT || '').trim();
  if (!projectId) {
    throw new Error('GOOGLE_CLOUD_PROJECT is required.');
  }

  const endpoint = (env.GOOGLE_TRANSLATE_ENDPOINT || DEFAULT_ENDPOINT).trim();
  const location = (env.GOOGLE_TRANSLATE_LOCATION || DEFAULT_LOCATION).trim();
  const model = (env.GOOGLE_TRANSLATE_MODEL || DEFAULT_MODEL).trim();

  if (endpoint !== DEFAULT_ENDPOINT) {
    throw new Error(`Only the EU endpoint is supported. Expected ${DEFAULT_ENDPOINT}.`);
  }

  if (!location.startsWith('europe-')) {
    throw new Error('GOOGLE_TRANSLATE_LOCATION must be an EU region such as europe-west1.');
  }

  if (model !== DEFAULT_MODEL) {
    throw new Error(`Only the Google NMT model (${DEFAULT_MODEL}) is supported.`);
  }

  const defaultLabels = parseJsonObject(env.GOOGLE_TRANSLATE_LABELS_JSON, 'GOOGLE_TRANSLATE_LABELS_JSON');
  const sharedSecret = (env.TRANSLATE_SHARED_SECRET || '').trim();
  const port = parseInteger(env.PORT, DEFAULT_PORT, 'PORT');
  const maxCodePoints = parseInteger(env.TRANSLATE_MAX_CODE_POINTS, DEFAULT_MAX_CODE_POINTS, 'TRANSLATE_MAX_CODE_POINTS');
  const maxBlocks = parseInteger(env.TRANSLATE_MAX_BLOCKS, DEFAULT_MAX_BLOCKS, 'TRANSLATE_MAX_BLOCKS');
  const requestBodyLimitBytes = parseInteger(
    env.TRANSLATE_MAX_REQUEST_BYTES,
    256 * 1024,
    'TRANSLATE_MAX_REQUEST_BYTES'
  );

  return {
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

module.exports = {
  loadConfig,
  DEFAULT_ENDPOINT,
  DEFAULT_LOCATION,
  DEFAULT_MODEL,
};
