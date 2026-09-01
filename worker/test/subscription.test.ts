import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const grantPaidSubscription = vi.fn();
const revokePaidSubscription = vi.fn();
vi.mock('../src/appspro', () => ({
  grantPaidSubscription: (...args: unknown[]) => grantPaidSubscription(...args),
  revokePaidSubscription: (...args: unknown[]) => revokePaidSubscription(...args),
}));

const getDocument = vi.fn();
vi.mock('../src/firestoreClient', () => ({
  getDocument: (...args: unknown[]) => getDocument(...args),
}));

// Imported after the mocks above so subscription.ts picks up the mocked
// modules rather than the real Firestore/appspro implementations — this
// file only exercises the AppsPro API + gating logic, not Firestore I/O
// (already covered separately: grant/revoke's own shape lives in
// appspro.ts, unit-tested there implicitly via handleAppsProWebhook).
import { AppsProApiError, refreshSubscriptionStatus, requestOtp, verifyOtpAndActivate } from '../src/subscription';

const env = { APPSPRO_SECRET_KEY: 'sk_test' } as never;

function jsonResponse(body: unknown, ok = true, status = 200): Response {
  return { ok, status, json: async () => body } as Response;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('requestOtp', () => {
  it('rejects an unsupported operator (Grameenphone 017) before ever calling AppsPro', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    await expect(requestOtp(env, '01712345678')).rejects.toThrow(AppsProApiError);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('rejects a 019 number the same way — only 018 (Robi) and 016 (Cirkle) are supported', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    await expect(requestOtp(env, '01912345678')).rejects.toThrow(AppsProApiError);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('accepts a Robi (018) number and returns AppsPro\'s reference_no', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse({ reference_no: 'ref_123', status_code: 'S1000', status_detail: 'Success' }));
    vi.stubGlobal('fetch', fetchMock);

    const result = await requestOtp(env, '01812345678');

    expect(result).toEqual({ referenceNo: 'ref_123', statusDetail: 'Success' });
    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.appspro.dev/api/v1/sdk/otp/request',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({ Authorization: 'Bearer sk_test' }),
        body: JSON.stringify({ phone: '8801812345678' }),
      }),
    );
  });

  it('accepts a Cirkle (016) number', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(jsonResponse({ reference_no: 'ref_456', status_code: 'S1000', status_detail: 'Success' })),
    );

    await expect(requestOtp(env, '01612345678')).resolves.toEqual({ referenceNo: 'ref_456', statusDetail: 'Success' });
  });

  it("surfaces AppsPro's own status_detail verbatim when status_code isn't S1000", async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonResponse({ status_code: 'E429', status_detail: 'Rate limit exceeded' })));

    await expect(requestOtp(env, '01812345678')).rejects.toThrow('Rate limit exceeded');
  });

  it('wraps a network failure in AppsProApiError rather than letting it propagate raw', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockRejectedValue(new Error('fetch failed')),
    );

    await expect(requestOtp(env, '01812345678')).rejects.toThrow(AppsProApiError);
  });
});

describe('verifyOtpAndActivate', () => {
  beforeEach(() => {
    grantPaidSubscription.mockReset();
    revokePaidSubscription.mockReset();
  });

  it('grants access only once BOTH otp/verify AND the follow-up /sdk/verify agree', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        jsonResponse({ subscriber_id: 'tel:8801812345678', status_code: 'S1000', status_detail: 'Success' }),
      )
      .mockResolvedValueOnce(jsonResponse({ valid: true, subscriber: { status: 'ACTIVE' } }));
    vi.stubGlobal('fetch', fetchMock);

    await verifyOtpAndActivate(env, 'uid123', 'ref_123', '1234');

    expect(grantPaidSubscription).toHaveBeenCalledWith(env, 'uid123', 'tel:8801812345678');
    expect(revokePaidSubscription).not.toHaveBeenCalled();
    // The follow-up call hits /sdk/verify/<subscriber_id>, URL-encoded.
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      'https://api.appspro.dev/api/v1/sdk/verify/tel%3A8801812345678',
      expect.objectContaining({ method: 'GET' }),
    );
  });

  it('does NOT grant access if OTP verification itself fails (e.g. wrong OTP)', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonResponse({ status_code: 'E400', status_detail: 'Invalid OTP' })));

    await expect(verifyOtpAndActivate(env, 'uid123', 'ref_123', '0000')).rejects.toThrow('Invalid OTP');
    expect(grantPaidSubscription).not.toHaveBeenCalled();
  });

  it('does NOT grant access if otp/verify succeeds but /sdk/verify says invalid', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        jsonResponse({ subscriber_id: 'tel:8801812345678', status_code: 'S1000', status_detail: 'Success' }),
      )
      .mockResolvedValueOnce(jsonResponse({ valid: false, reason: 'UNREGISTERED' }));
    vi.stubGlobal('fetch', fetchMock);

    await expect(verifyOtpAndActivate(env, 'uid123', 'ref_123', '1234')).rejects.toThrow('UNREGISTERED');
    expect(grantPaidSubscription).not.toHaveBeenCalled();
  });
});

describe('refreshSubscriptionStatus', () => {
  beforeEach(() => {
    grantPaidSubscription.mockReset();
    revokePaidSubscription.mockReset();
    getDocument.mockReset();
  });

  it('is a no-op for a user who has never subscribed', async () => {
    getDocument.mockResolvedValue(null);
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    await refreshSubscriptionStatus(env, 'uid123');

    expect(fetchMock).not.toHaveBeenCalled();
    expect(grantPaidSubscription).not.toHaveBeenCalled();
    expect(revokePaidSubscription).not.toHaveBeenCalled();
  });

  it('re-grants when still valid', async () => {
    getDocument.mockResolvedValue({ bdappsSubscriptionId: 'tel:8801812345678' });
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonResponse({ valid: true })));

    await refreshSubscriptionStatus(env, 'uid123');

    expect(grantPaidSubscription).toHaveBeenCalledWith(env, 'uid123', 'tel:8801812345678');
  });

  it('revokes as "expired" when the reason mentions expiry', async () => {
    getDocument.mockResolvedValue({ bdappsSubscriptionId: 'tel:8801812345678' });
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonResponse({ valid: false, reason: 'Subscription expired' })));

    await refreshSubscriptionStatus(env, 'uid123');

    expect(revokePaidSubscription).toHaveBeenCalledWith(env, 'uid123', 'tel:8801812345678', 'expired');
  });

  it('revokes as "canceled" for any other invalid reason', async () => {
    getDocument.mockResolvedValue({ bdappsSubscriptionId: 'tel:8801812345678' });
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonResponse({ valid: false, reason: 'UNREGISTERED' })));

    await refreshSubscriptionStatus(env, 'uid123');

    expect(revokePaidSubscription).toHaveBeenCalledWith(env, 'uid123', 'tel:8801812345678', 'canceled');
  });
});
