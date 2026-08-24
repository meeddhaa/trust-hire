import { describe, expect, it } from 'vitest';
import { AuthError, verifyFirebaseIdToken } from '../src/auth';

/**
 * Regression coverage for a real bug caught during the first live deploy
 * smoke test: a malformed (but 3-dot-shaped) token threw an uncaught
 * SyntaxError from JSON.parse deep in base64 decoding, which fell through
 * to index.ts's generic 500 handler instead of a clean 401. These run
 * under plain Node (crypto.subtle/atob/TextDecoder are all available
 * there too), no Workers runtime needed — see vitest.config.ts.
 */
describe('verifyFirebaseIdToken — malformed input never throws past AuthError', () => {
  it('rejects a token with the wrong number of segments', async () => {
    await expect(verifyFirebaseIdToken('not-a-jwt', 'trusthire-bdapps')).rejects.toBeInstanceOf(AuthError);
  });

  it('rejects a token whose segments are not valid base64', async () => {
    await expect(verifyFirebaseIdToken('not.a.realtoken', 'trusthire-bdapps')).rejects.toBeInstanceOf(
      AuthError,
    );
  });

  it('rejects a token whose header decodes to base64 but not JSON', async () => {
    // "abcd" base64url-decodes cleanly but the bytes aren't valid JSON.
    await expect(verifyFirebaseIdToken('abcd.abcd.abcd', 'trusthire-bdapps')).rejects.toBeInstanceOf(
      AuthError,
    );
  });

  it('rejects a well-formed-JSON header with the wrong algorithm', async () => {
    const header = btoa(JSON.stringify({ alg: 'none', typ: 'JWT' }))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
    await expect(verifyFirebaseIdToken(`${header}.abcd.abcd`, 'trusthire-bdapps')).rejects.toBeInstanceOf(
      AuthError,
    );
  });
});
