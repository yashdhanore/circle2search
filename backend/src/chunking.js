function codePointLength(text) {
  return Array.from(text).length;
}

function sanitizeText(text) {
  return String(text).trim();
}

function validateLabelKey(key) {
  return /^[\p{L}][\p{L}0-9_-]{0,62}$/u.test(key);
}

function validateLabelValue(value) {
  return /^[\p{L}0-9_-]{0,63}$/u.test(value);
}

function normalizeLabels(baseLabels, requestLabels) {
  const merged = {
    ...baseLabels,
    ...requestLabels,
  };

  const entries = Object.entries(merged);
  if (entries.length > 64) {
    throw new Error('labels cannot contain more than 64 entries.');
  }

  const result = {};
  for (const [key, rawValue] of entries) {
    const normalizedKey = String(key).trim();
    const normalizedValue = String(rawValue ?? '').trim();

    if (!validateLabelKey(normalizedKey)) {
      throw new Error(`Invalid label key "${normalizedKey}".`);
    }

    if (!validateLabelValue(normalizedValue)) {
      throw new Error(`Invalid label value for key "${normalizedKey}".`);
    }

    result[normalizedKey] = normalizedValue;
  }

  return result;
}

function chunkBlocks(blocks, maxCodePoints, maxBlocks) {
  const chunks = [];
  let current = [];
  let currentCodePoints = 0;

  for (const block of blocks) {
    const text = sanitizeText(block.text);
    const textCodePoints = codePointLength(text);

    if (textCodePoints > 30000) {
      throw new Error(`Block ${block.id} exceeds the 30000 code point limit.`);
    }

    if (
      current.length > 0 &&
      (current.length >= maxBlocks || currentCodePoints + textCodePoints > maxCodePoints)
    ) {
      chunks.push(current);
      current = [];
      currentCodePoints = 0;
    }

    current.push({
      id: block.id,
      text,
      codePoints: textCodePoints,
    });
    currentCodePoints += textCodePoints;
  }

  if (current.length > 0) {
    chunks.push(current);
  }

  return chunks;
}

function summarizeBlocks(blocks) {
  const codePoints = blocks.reduce((sum, block) => sum + codePointLength(sanitizeText(block.text)), 0);
  return {
    blockCount: blocks.length,
    codePoints,
  };
}

module.exports = {
  chunkBlocks,
  codePointLength,
  normalizeLabels,
  sanitizeText,
  summarizeBlocks,
};
