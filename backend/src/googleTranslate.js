const METADATA_TOKEN_URL = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token';

class GoogleTranslateClient {
  constructor(config) {
    this.config = config;
    this.cachedAccessToken = null;
    this.cachedAccessTokenExpiresAt = 0;
  }

  async translateChunk({ items, targetLanguageCode, sourceLanguageCode, labels, requestId, chunkIndex, chunkCount }) {
    if (this.config.translationMode === 'basic_api_key') {
      return this.translateChunkWithBasicAPIKey({
        items,
        targetLanguageCode,
        sourceLanguageCode,
        requestId,
        chunkIndex,
        chunkCount,
      });
    }

    return this.translateChunkWithAdvancedAPI({
      items,
      targetLanguageCode,
      sourceLanguageCode,
      labels,
      requestId,
      chunkIndex,
      chunkCount,
    });
  }

  async translateChunkWithAdvancedAPI({ items, targetLanguageCode, sourceLanguageCode, labels, requestId, chunkIndex, chunkCount }) {
    const accessToken = await this.getAccessToken();
    const endpoint = `https://${this.config.endpoint}/v3/projects/${encodeURIComponent(this.config.projectId)}/locations/${encodeURIComponent(this.config.location)}:translateText`;
    const body = {
      contents: items.map((item) => item.text),
      mimeType: 'text/plain',
      targetLanguageCode,
      model: `projects/${this.config.projectId}/locations/${this.config.location}/models/${this.config.model}`,
      labels,
    };

    if (sourceLanguageCode) {
      body.sourceLanguageCode = sourceLanguageCode;
    }

    console.info(
      JSON.stringify({
        level: 'info',
        event: 'google_translate_request',
        requestId,
        chunkIndex,
        chunkCount,
        endpoint: this.config.endpoint,
        location: this.config.location,
        blockCount: items.length,
        codePoints: items.reduce((sum, item) => sum + item.codePoints, 0),
        targetLanguageCode,
      })
    );

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json; charset=utf-8',
        'x-goog-user-project': this.config.projectId,
      },
      body: JSON.stringify(body),
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
      const message = payload?.error?.message || responseText || `Google Translation returned HTTP ${response.status}.`;
      const error = new Error(message);
      error.statusCode = response.status;
      error.upstream = payload;
      throw error;
    }

    const translations = Array.isArray(payload?.translations) ? payload.translations : [];
    if (translations.length !== items.length) {
      const error = new Error('Google Translation returned an unexpected number of translations.');
      error.statusCode = 502;
      error.upstream = payload;
      throw error;
    }

    return translations.map((translation, index) => ({
      id: items[index].id,
      translatedText: String(translation?.translatedText || ''),
      detectedSourceLanguage: translation?.detectedLanguageCode || translation?.detectedSourceLanguage || null,
    }));
  }

  async translateChunkWithBasicAPIKey({ items, targetLanguageCode, sourceLanguageCode, requestId, chunkIndex, chunkCount }) {
    const endpoint = `https://${this.config.endpoint}/language/translate/v2?key=${encodeURIComponent(this.config.basicAPIKey)}`;
    const body = {
      q: items.map((item) => item.text),
      target: targetLanguageCode,
      format: 'text',
    };

    if (sourceLanguageCode) {
      body.source = sourceLanguageCode;
    }

    console.info(
      JSON.stringify({
        level: 'info',
        event: 'google_translate_basic_request',
        requestId,
        chunkIndex,
        chunkCount,
        endpoint: this.config.endpoint,
        blockCount: items.length,
        codePoints: items.reduce((sum, item) => sum + item.codePoints, 0),
        targetLanguageCode,
      })
    );

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: JSON.stringify(body),
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
      const message = payload?.error?.message || responseText || `Google Translation returned HTTP ${response.status}.`;
      const error = new Error(message);
      error.statusCode = response.status;
      error.upstream = payload;
      throw error;
    }

    const translations = Array.isArray(payload?.data?.translations) ? payload.data.translations : [];
    if (translations.length !== items.length) {
      const error = new Error('Google Translation returned an unexpected number of translations.');
      error.statusCode = 502;
      error.upstream = payload;
      throw error;
    }

    return translations.map((translation, index) => ({
      id: items[index].id,
      translatedText: String(translation?.translatedText || ''),
      detectedSourceLanguage: translation?.detectedSourceLanguage || null,
    }));
  }

  async getAccessToken() {
    if (this.config.googleAccessTokenOverride) {
      return this.config.googleAccessTokenOverride;
    }

    if (this.cachedAccessToken && Date.now() < this.cachedAccessTokenExpiresAt) {
      return this.cachedAccessToken;
    }

    const response = await fetch(METADATA_TOKEN_URL, {
      headers: {
        'Metadata-Flavor': 'Google',
      },
    });

    if (!response.ok) {
      throw new Error(`Unable to get a Google access token from the metadata server: HTTP ${response.status}.`);
    }

    const payload = await response.json();
    if (!payload?.access_token || typeof payload.access_token !== 'string') {
      throw new Error('Google metadata server did not return an access token.');
    }

    const expiresInSeconds = Number(payload.expires_in || 0);
    const safetyWindowMs = 60_000;

    this.cachedAccessToken = payload.access_token;
    this.cachedAccessTokenExpiresAt = Date.now() + Math.max(expiresInSeconds, 60) * 1000 - safetyWindowMs;

    return this.cachedAccessToken;
  }
}

module.exports = {
  GoogleTranslateClient,
};
