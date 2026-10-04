import { createHash, randomBytes, scrypt as deriveKey, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(deriveKey);
export const sha256 = (value) => createHash('sha256').update(value).digest('hex');
export const sessionToken = () => randomBytes(32).toString('base64url');

export async function hashPassword(password) {
  if (typeof password !== 'string' || password.length < 14 || password.length > 256) {
    throw new Error('Password must contain 14–256 characters.');
  }
  const salt = randomBytes(16).toString('hex');
  const key = await scrypt(password, salt, 64, { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
  return `scrypt:${salt}:${key.toString('hex')}`;
}

export async function verifyPassword(password, stored) {
  const [kind, salt, expected] = stored.split(':');
  if (kind !== 'scrypt' || !/^[a-f0-9]{32}$/.test(salt) || !/^[a-f0-9]{128}$/.test(expected)) return false;
  const key = await scrypt(password, salt, 64, { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
  return timingSafeEqual(key, Buffer.from(expected, 'hex'));
}

export function rateLimit({ maximum, windowMs, key = (req) => req.ip }) {
  const entries = new Map();
  return (req, res, next) => {
    const now = Date.now();
    if (entries.size >= 10000) {
      for (const [id, entry] of entries) if (entry.until <= now) entries.delete(id);
      if (entries.size >= 10000) return res.status(429).json({ error: 'Please retry later.' });
    }
    const id = key(req);
    let entry = entries.get(id);
    if (!entry || entry.until <= now) {
      entry = { count: 0, until: now + windowMs };
      entries.set(id, entry);
    }
    entry.count++;
    if (entry.count > maximum) {
      res.set('Retry-After', String(Math.ceil((entry.until - now) / 1000)));
      return res.status(429).json({ error: 'Please retry later.' });
    }
    next();
  };
}
