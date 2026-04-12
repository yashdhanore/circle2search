class SlidingWindowRateLimiter {
  constructor({ windowSeconds, maxRequests }) {
    this.windowMs = windowSeconds * 1000;
    this.maxRequests = maxRequests;
    this.entries = new Map();
  }

  consume(key, now = Date.now()) {
    const cutoff = now - this.windowMs;
    const existing = this.entries.get(key) || [];
    const next = existing.filter((timestamp) => timestamp > cutoff);

    if (next.length >= this.maxRequests) {
      this.entries.set(key, next);
      return false;
    }

    next.push(now);
    this.entries.set(key, next);
    return true;
  }
}

module.exports = {
  SlidingWindowRateLimiter,
};
