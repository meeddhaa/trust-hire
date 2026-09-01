import { describe, expect, it } from 'vitest';
import { signRs256Jwt } from '../src/jwtSign';

/**
 * A throwaway 2048-bit RSA keypair generated once for this test only
 * (`node -e "crypto.generateKeyPairSync('rsa', ...)"`) — not a real
 * credential, never used anywhere outside this file. Verifying the
 * signature against the matching public key (rather than just checking
 * the JWT "looks like" three dot-separated segments) is what actually
 * proves `signRs256Jwt` produces something a real RS256 verifier accepts
 * — this is the primitive both the Firestore service-account token
 * exchange and Firebase custom-token minting rest on, so a subtly wrong
 * encoding here would be a real, hard-to-notice auth bug, not a cosmetic
 * one.
 */
const TEST_PRIVATE_KEY_PEM = `-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDksBY/weTCghwk
rtI18XcW0Ru5sC6Sww/e3zXHNol6i4tEQs53hK5B8GGlctHOe7LHvNW/L35pI8sQ
wsnnM2R9PupphrPTEoP002XNdAxvjPqgT3A4A5KhO5Ck577d97YPlVkm+Z4X9cco
MYvn9UPGcLYguY0xzOHyUI+IUFER3mRoacsC7gvXLpTwXF6gJO5Z03cz8RhohLgt
R94XHCsuPsHV2PgTQG5rBoBlzvWIej1t28rkZl3e5bQ6oVHLBiOyNpu6iewzTqUN
HXWgThdUvXX+ayLaesAAW33L6iDvpmT6HXi61HiXxDzboLhVJIs327CDfMSgof97
FLvpywufAgMBAAECggEAHQyPGZ84FKBxZxQmk1VDrYwiFkwecQ8XziroCmZPlVec
zll2ykYk2oRolZsdso8STn6atN6ZaKKe0gIO9/BBH2BlZ20wcis5GYQxkM+2dVm2
S7R7ipSi728ruFQlxyKxp44ZlTKtFdm8aCB5vJ0c9FvvOVNIml8DroOe5Tpf6exq
tJ/wFhCRMuTSGofXNWwGNQ3R06CiXuZdSCbdXpZw9mO+rf02EJsHcuOlkbuw4ykj
8HUaukQp3DihwcMY2Iv90gcEs9Lkp3L1yezTIsmNleJcRtivZVZaawoUKi2JePXP
GVKwjAKDsw7CBk6+epTGJ00Us2g4YK5DnCPrl7m4aQKBgQD2+eEuMYoxX8N+d9pv
zdn18jPPK2Us5h6N/+xhS1c/4A6wLeaIkYChb4Vdh06J1boNCtTdgkL2i8kLeZBu
hjyNcOT3H6CcvrRbj94g4oyLbYFskiN0a+xyiFXvccCiN9E6Aek7cJK15H7EDBV7
ydo+gDY2o38aKxQzDdN2SbVJCQKBgQDtCyVcddqYyGLUw8dCdlQvx8w4Af4a3tx4
TO88pRw9wpnXXrC7zn3SbY2eDsSmLoDuLRZ7VexQU4BwE9kXWhpn1dusdjooCX3+
XgAhRS8zFHIg7l/1DordsOA+RdrX/+kNSljzRpCYchhcvOKKg7J2dHUrteJqoKXH
4jY0XoyhZwKBgEvyUT18PGuscBhe0MwauBC6dxYY2RbyeKjf7xeILH9W7g1dQAv0
+mIqQg+dwRf/oiPKleS73s2j9KHTswdZvhscgTxA/InW1u1lE0B3ihKCDQ+O7Nor
Kd2acRqdl0gK9ArrdYYyutq2NgkhUiXrz3HyyTkKE9a/Mon0kXdJeTbJAoGBAIVo
RHqpCYH7JURBex94oSDS/ah31p8g1kwOYIZtFlvb7eE8NZM9P6ryZUWTYjF08rMZ
RRHc5ca/eAWb5g4yc7IEtkF1uH1X+kTyeng/C7VfyGuoPPEaYiUqqsnhXq06JduJ
AE7KZA6oB/YJiCYUwJfSKy+Sif8gsqywL3mBzPv5AoGAJVK1PrgFGdI41KefW6Qw
ISh7pFPp81cBlktJ0qoZW1zYLisKm8xZQv/yIq7HdFrJWDV5YbyY3QOundT8uG2N
iejkNj72goztwqi7yQXN3mCbw5boyWj+XCS8vw6WGXVCYDwOWrV09+/CmFJ7BenT
mqLBUNxEb2RXcOKES6ckfC0=
-----END PRIVATE KEY-----`;

const TEST_PUBLIC_KEY_PEM = `-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5LAWP8HkwoIcJK7SNfF3
FtEbubAuksMP3t81xzaJeouLRELOd4SuQfBhpXLRznuyx7zVvy9+aSPLEMLJ5zNk
fT7qaYaz0xKD9NNlzXQMb4z6oE9wOAOSoTuQpOe+3fe2D5VZJvmeF/XHKDGL5/VD
xnC2ILmNMczh8lCPiFBREd5kaGnLAu4L1y6U8FxeoCTuWdN3M/EYaIS4LUfeFxwr
Lj7B1dj4E0BuawaAZc71iHo9bdvK5GZd3uW0OqFRywYjsjabuonsM06lDR11oE4X
VL11/msi2nrAAFt9y+og76Zk+h14utR4l8Q826C4VSSLN9uwg3zEoKH/exS76csL
nwIDAQAB
-----END PUBLIC KEY-----`;

function base64UrlDecode(segment: string): Uint8Array {
  const base64 = segment.replace(/-/g, '+').replace(/_/g, '/').padEnd(segment.length + ((4 - (segment.length % 4)) % 4), '=');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function pemToSpki(pem: string): ArrayBuffer {
  const base64 = pem.replace(/-----BEGIN PUBLIC KEY-----/, '').replace(/-----END PUBLIC KEY-----/, '').replace(/\s/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function splitJwt(jwt: string): [string, string, string] {
  const parts = jwt.split('.');
  if (parts.length !== 3) throw new Error(`Not a 3-part JWT: ${jwt}`);
  return [parts[0]!, parts[1]!, parts[2]!];
}

async function verify(jwt: string): Promise<boolean> {
  const [headerB64, payloadB64, signatureB64] = splitJwt(jwt);
  const key = await crypto.subtle.importKey(
    'spki',
    pemToSpki(TEST_PUBLIC_KEY_PEM),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  return crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64UrlDecode(signatureB64),
    new TextEncoder().encode(`${headerB64}.${payloadB64}`),
  );
}

describe('signRs256Jwt', () => {
  it('produces a JWT whose signature verifies against the matching public key', async () => {
    const jwt = await signRs256Jwt(TEST_PRIVATE_KEY_PEM, { uid: 'bdapps_8801812345678', iat: 1000, exp: 4600 });
    await expect(verify(jwt)).resolves.toBe(true);
  });

  it('encodes a standard RS256 header', async () => {
    const jwt = await signRs256Jwt(TEST_PRIVATE_KEY_PEM, { uid: 'x' });
    const [headerB64] = splitJwt(jwt);
    const header = JSON.parse(new TextDecoder().decode(base64UrlDecode(headerB64)));
    expect(header).toEqual({ alg: 'RS256', typ: 'JWT' });
  });

  it('round-trips the exact payload given', async () => {
    const payload = { iss: 'svc@example.iam.gserviceaccount.com', uid: 'bdapps_8801612345678', iat: 1, exp: 2 };
    const jwt = await signRs256Jwt(TEST_PRIVATE_KEY_PEM, payload);
    const [, payloadB64] = splitJwt(jwt);
    expect(JSON.parse(new TextDecoder().decode(base64UrlDecode(payloadB64)))).toEqual(payload);
  });

  it('fails verification if the payload is tampered with after signing', async () => {
    const jwt = await signRs256Jwt(TEST_PRIVATE_KEY_PEM, { uid: 'bdapps_8801812345678' });
    const [headerB64, , signatureB64] = splitJwt(jwt);
    const tamperedPayloadB64 = Buffer.from(JSON.stringify({ uid: 'bdapps_8801999999999' }))
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
    const tampered = `${headerB64}.${tamperedPayloadB64}.${signatureB64}`;
    await expect(verify(tampered)).resolves.toBe(false);
  });
});
