import { describe, expect, it } from 'vitest';
import { verifyAppsProSignature, AppsProSignatureError } from '../src/appspro';

/**
 * Ground truth for these expected values came from running the exact
 * payload below through Python itself:
 *   json.dumps(body, sort_keys=True)
 *   hmac.new(key.encode(), canonical.encode(), hashlib.sha256).hexdigest()
 * — not guessed. If this test ever starts failing after touching
 * `canonicalize` in appspro.ts, that's a real signature-verification
 * regression, not a stale fixture; re-derive the expected values from
 * Python again rather than updating them to match new TS output.
 */
const SAMPLE_BODY = {
  event: 'subscriber.created',
  data: {
    applicationId: 'BDAPPS_123',
    frequency: 'daily',
    internal_subscriber_id: '550e8400-1234-5678-9abc-def012345678',
    status: 'REGISTERED',
    subscriberId: 'tel:8801712345678',
    timeStamp: '2026-05-11T10:30:00Z',
  },
};
const SAMPLE_KEY = 'test_secret_key';
const EXPECTED_HMAC_HEX = '3d50da97498a9a1c4b4e7200ec1ab67113ae74b98b8cdf0776036c02762bac42';

describe('verifyAppsProSignature', () => {
  const env = { APPSPRO_SECRET_KEY: SAMPLE_KEY } as never;

  it('accepts a signature matching Python-computed HMAC of the canonical body', async () => {
    await expect(verifyAppsProSignature(env, SAMPLE_BODY, EXPECTED_HMAC_HEX)).resolves.toBeUndefined();
  });

  it('accepts an uppercase-hex signature (hex comparison is case-insensitive)', async () => {
    await expect(verifyAppsProSignature(env, SAMPLE_BODY, EXPECTED_HMAC_HEX.toUpperCase())).resolves.toBeUndefined();
  });

  it('rejects a wrong signature', async () => {
    await expect(verifyAppsProSignature(env, SAMPLE_BODY, `${EXPECTED_HMAC_HEX.slice(0, -1)}0`)).rejects.toThrow(
      AppsProSignatureError,
    );
  });

  it('rejects a missing signature header', async () => {
    await expect(verifyAppsProSignature(env, SAMPLE_BODY, null)).rejects.toThrow(AppsProSignatureError);
  });

  it('rejects when the body has been tampered with after signing', async () => {
    const tampered = { ...SAMPLE_BODY, data: { ...SAMPLE_BODY.data, status: 'CANCELLED' } };
    await expect(verifyAppsProSignature(env, tampered, EXPECTED_HMAC_HEX)).rejects.toThrow(AppsProSignatureError);
  });

  it('produces a different signature for key order alone (guards against a naive JSON.stringify)', async () => {
    // Same data, keys inserted in a different order — a canonicalizer that
    // forgot to sort would produce a different signature here and this
    // test would catch it, since the correct behavior is IDENTICAL output
    // regardless of insertion order.
    const reordered = {
      data: {
        timeStamp: SAMPLE_BODY.data.timeStamp,
        subscriberId: SAMPLE_BODY.data.subscriberId,
        status: SAMPLE_BODY.data.status,
        internal_subscriber_id: SAMPLE_BODY.data.internal_subscriber_id,
        frequency: SAMPLE_BODY.data.frequency,
        applicationId: SAMPLE_BODY.data.applicationId,
      },
      event: SAMPLE_BODY.event,
    };
    await expect(verifyAppsProSignature(env, reordered, EXPECTED_HMAC_HEX)).resolves.toBeUndefined();
  });
});
