// The Vercel CLI login the Sandbox SDK uses (via OIDC) on this host. It lives
// about 8 hours and the SDK does not refresh it, so `start` refuses a
// familiar the login cannot cover, after one `vercel whoami` refresh.

import { execFileSync } from 'node:child_process';

export const NEED_MINUTES = 60;

export function minutesLeft(auth, now = Date.now()) {
  if (!auth?.token) return 0;
  if (!auth.expiresAt) return Infinity;
  return Math.max(0, Math.floor((auth.expiresAt.getTime() - now) / 60_000));
}

export async function vercelLogin({ refresh = true } = {}) {
  const { getAuth } = await import('@vercel/sandbox/dist/auth/index.js');
  let left = minutesLeft(getAuth());
  if (left < NEED_MINUTES && refresh) {
    try { execFileSync('vercel', ['whoami'], { stdio: 'ignore', timeout: 60_000 }); } catch {}
    left = minutesLeft(getAuth());
  }
  return { left, ok: left >= NEED_MINUTES, message: left === 0 ? 'no Vercel CLI login: run `vercel login`' : `the Vercel CLI login has ${left} minutes left (need ${NEED_MINUTES}): run \`vercel logout && vercel login\`` };
}
