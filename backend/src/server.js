const http = require('node:http');
const crypto = require('node:crypto');
const { loadConfig } = require('./config');
const { chunkBlocks, normalizeLabels, summarizeBlocks } = require('./chunking');
const { GoogleTranslateClient } = require('./googleTranslate');

const config = loadConfig();
const translateClient = new GoogleTranslateClient(config);

const server = http.createServer(async (req, res) => {
  const requestId = crypto.randomUUID();

  try {
    if (req.method === 'GET' && req.url === '/healthz') {
      sendJson(res, 200, { ok: true, requestId });
      return;
    }

    if (req.method !== 'POST' || req.url !== '/v1/translate-screen') {
      sendJsonError(res, 404, 'not_found', 'Not found.', requestId);
      return;
    }

    if (!authorizeRequest(req, config.sharedSecret)) {
      sendJsonError(res, 401, 'unauthorized', 'Missing or invalid bearer token.', requestId);
      return;
    }

    const bodyText = await readBody(req, config.requestBodyLimitBytes);
    let body;

    try {
      body = JSON.parse(bodyText);
    } catch {
      sendJsonError(res, 400, 'invalid_json', 'Request body must be valid JSON.', requestId);
      return;
    }

    const parsed = parseRequest(body);
    if (parsed.error) {
      sendJsonError(res, 400, 'validation_error', parsed.error, requestId, parsed.details);
      return;
    }

    const { targetLanguageCode, sourceLanguageCode, blocks, labels } = parsed.value;
    const requestSummary = summarizeBlocks(blocks);
    const mergedLabels = normalizeLabels(
      {
        app: 'circle2search',
        surface: 'screen_translate',
      },
      {
        ...config.defaultLabels,
        ...labels,
      }
    );

    console.info(
      JSON.stringify({
        level: 'info',
        event: 'translate_screen_request',
        requestId,
        blockCount: requestSummary.blockCount,
        codePoints: requestSummary.codePoints,
        targetLanguageCode,
        sourceLanguageCode: sourceLanguageCode || null,
      })
    );

    const translatedBlocks = await translateBlocks({
      blocks,
      targetLanguageCode,
      sourceLanguageCode,
      labels: mergedLabels,
      requestId,
    });

    sendJson(res, 200, {
      provider: 'google-cloud-nmt',
      region: config.location,
      blocks: translatedBlocks,
    }, requestId);
  } catch (error) {
    const statusCode = Number.isInteger(error.statusCode) ? error.statusCode : 500;
    const code = statusCode === 413
      ? 'payload_too_large'
      : statusCode >= 500
        ? 'upstream_error'
        : 'internal_error';
    console.error(
      JSON.stringify({
        level: 'error',
        event: 'translate_screen_failed',
        requestId,
        statusCode,
        message: error.message,
      })
    );
    sendJsonError(res, statusCode, code, error.message || 'Internal server error.', requestId);
  }
});

server.listen(config.port, () => {
  console.info(
    JSON.stringify({
      level: 'info',
      event: 'server_listening',
      port: config.port,
      endpoint: config.endpoint,
      location: config.location,
    })
  );
});

async function translateBlocks({ blocks, targetLanguageCode, sourceLanguageCode, labels, requestId }) {
  const chunks = chunkBlocks(blocks, config.maxCodePoints, config.maxBlocks);
  const result = [];

  for (let index = 0; index < chunks.length; index += 1) {
    const chunk = chunks[index];
    const translatedChunk = await translateClient.translateChunk({
      items: chunk,
      targetLanguageCode,
      sourceLanguageCode,
      labels,
      requestId,
      chunkIndex: index + 1,
      chunkCount: chunks.length,
    });

    for (const translated of translatedChunk) {
      result.push(translated);
    }
  }

  return result;
}

function parseRequest(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'Request body must be a JSON object.' };
  }

  const targetLanguageCode = canonicalizeLanguageCode(body.targetLanguageCode);
  if (!targetLanguageCode) {
    return { error: 'targetLanguageCode is required and must be a valid BCP-47 language tag.' };
  }

  const sourceLanguageCode = body.sourceLanguageCode ? canonicalizeLanguageCode(body.sourceLanguageCode) : null;
  if (body.sourceLanguageCode && !sourceLanguageCode) {
    return { error: 'sourceLanguageCode must be a valid BCP-47 language tag.' };
  }

  if (!Array.isArray(body.blocks) || body.blocks.length === 0) {
    return { error: 'blocks must be a non-empty array.' };
  }

  if (body.blocks.length > config.maxBlocks * 10) {
    return { error: `blocks exceeds the maximum allowed request size of ${config.maxBlocks * 10} items.` };
  }

  const blocks = [];
  for (let i = 0; i < body.blocks.length; i += 1) {
    const block = body.blocks[i];
    if (!block || typeof block !== 'object' || Array.isArray(block)) {
      return { error: `blocks[${i}] must be an object.` };
    }

    if (typeof block.id !== 'string' || !block.id.trim()) {
      return { error: `blocks[${i}].id must be a non-empty string.` };
    }

    if (typeof block.text !== 'string') {
      return { error: `blocks[${i}].text must be a string.` };
    }

    blocks.push({
      id: block.id,
      text: block.text,
    });
  }

  let labels = {};
  if (body.labels != null) {
    if (typeof body.labels !== 'object' || Array.isArray(body.labels)) {
      return { error: 'labels must be an object if provided.' };
    }
    labels = body.labels;
  }

  return {
    value: {
      targetLanguageCode,
      sourceLanguageCode,
      blocks,
      labels,
    },
  };
}

function canonicalizeLanguageCode(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  try {
    const canonical = Intl.getCanonicalLocales(trimmed)[0];
    return canonical || null;
  } catch {
    return null;
  }
}

function authorizeRequest(req, sharedSecret) {
  if (!sharedSecret) {
    return true;
  }

  const header = req.headers.authorization || req.headers['x-circle-to-search-secret'];
  if (typeof header !== 'string' || !header.trim()) {
    return false;
  }

  const bearerPrefix = 'Bearer ';
  const provided = header.startsWith(bearerPrefix) ? header.slice(bearerPrefix.length).trim() : header.trim();

  if (provided.length !== sharedSecret.length) {
    return false;
  }

  return crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(sharedSecret));
}

function readBody(req, maxBytes) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];

    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > maxBytes) {
        reject(Object.assign(new Error(`Request body exceeds ${maxBytes} bytes.`), { statusCode: 413 }));
        req.destroy();
        return;
      }

      chunks.push(chunk);
    });

    req.on('end', () => {
      resolve(Buffer.concat(chunks).toString('utf8'));
    });

    req.on('error', reject);
  });
}

function sendJson(res, statusCode, payload, requestId) {
  res.statusCode = statusCode;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  if (requestId) {
    res.setHeader('x-request-id', requestId);
  }
  res.end(`${JSON.stringify(payload)}\n`);
}

function sendJsonError(res, statusCode, code, message, requestId, details) {
  const payload = {
    error: {
      code,
      message,
    },
  };

  if (details) {
    payload.error.details = details;
  }

  sendJson(res, statusCode, payload, requestId);
}
