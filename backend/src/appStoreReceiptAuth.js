const crypto = require('node:crypto');

const APPLE_VERIFY_RECEIPT_PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_VERIFY_RECEIPT_SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';
const APPLE_STATUS_SANDBOX_RECEIPT_SENT_TO_PRODUCTION = 21007;

class AppStoreReceiptAuthorizer {
  constructor(config) {
    this.config = config;
    this.cache = new Map();
  }

  async authorize(receiptData) {
    const trimmedReceipt = typeof receiptData === 'string' ? receiptData.trim() : '';
    if (!trimmedReceipt) {
      return null;
    }

    const receiptHash = hashReceipt(trimmedReceipt);
    const cached = this.cache.get(receiptHash);
    if (cached && Date.now() < cached.expiresAt) {
      return cached.value;
    }

    const verification = await this.verifyReceipt(trimmedReceipt);
    const bundleID = String(verification.receipt?.bundle_id || '').trim();

    if (!bundleID || bundleID !== this.config.expectedBundleID) {
      const error = new Error(
        `App Store receipt bundle ID mismatch. Expected ${this.config.expectedBundleID}, got ${bundleID || '<missing>'}.`
      );
      error.statusCode = 401;
      throw error;
    }

    const authorization = {
      scheme: 'app_store_receipt',
      subjectKey: `receipt:${receiptHash}`,
      subjectDescription: `${bundleID}:${verification.environment || 'unknown'}`,
      bundleID,
      environment: verification.environment || 'unknown',
      applicationVersion: String(verification.receipt?.application_version || '').trim() || null,
    };

    this.cache.set(receiptHash, {
      expiresAt: Date.now() + this.config.receiptCacheTTLSeconds * 1000,
      value: authorization,
    });

    return authorization;
  }

  async verifyReceipt(receiptData) {
    const productionResult = await postReceiptVerification(APPLE_VERIFY_RECEIPT_PRODUCTION_URL, receiptData);
    if (productionResult.status === APPLE_STATUS_SANDBOX_RECEIPT_SENT_TO_PRODUCTION) {
      return postReceiptVerification(APPLE_VERIFY_RECEIPT_SANDBOX_URL, receiptData);
    }

    return productionResult;
  }
}

async function postReceiptVerification(url, receiptData) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
    body: JSON.stringify({
      'receipt-data': receiptData,
      'exclude-old-transactions': true,
    }),
  });

  const responseText = await response.text();
  let payload = null;

  if (responseText) {
    try {
      payload = JSON.parse(responseText);
    } catch {
      payload = null;
    }
  }

  if (!response.ok) {
    const error = new Error(
      `Apple receipt verification returned HTTP ${response.status}: ${responseText || '<empty body>'}.`
    );
    error.statusCode = 502;
    throw error;
  }

  const status = Number(payload?.status);
  if (status !== 0 && status !== APPLE_STATUS_SANDBOX_RECEIPT_SENT_TO_PRODUCTION) {
    const error = new Error(`App Store receipt validation failed with status ${status}.`);
    error.statusCode = 401;
    throw error;
  }

  if (!payload?.receipt || typeof payload.receipt !== 'object') {
    const error = new Error('Apple receipt verification returned no receipt object.');
    error.statusCode = 502;
    throw error;
  }

  return payload;
}

function hashReceipt(receiptData) {
  return crypto.createHash('sha256').update(receiptData, 'utf8').digest('hex');
}

module.exports = {
  AppStoreReceiptAuthorizer,
};
