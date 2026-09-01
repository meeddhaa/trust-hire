import { describe, expect, it } from 'vitest';
import { bdOperatorForNormalizedPhone, normalizeBdPhoneNumber } from '../src/bdPhone';

describe('normalizeBdPhoneNumber', () => {
  it('normalizes a local 01XXXXXXXXX number', () => {
    expect(normalizeBdPhoneNumber('01812345678')).toBe('8801812345678');
  });

  it('normalizes an 8801XXXXXXXXX number unchanged', () => {
    expect(normalizeBdPhoneNumber('8801812345678')).toBe('8801812345678');
  });

  it('strips a leading "+"', () => {
    expect(normalizeBdPhoneNumber('+8801812345678')).toBe('8801812345678');
  });

  it('strips spaces and dashes', () => {
    expect(normalizeBdPhoneNumber('01812-345 678')).toBe('8801812345678');
  });
});

describe('bdOperatorForNormalizedPhone', () => {
  it('identifies Robi (018)', () => {
    expect(bdOperatorForNormalizedPhone(normalizeBdPhoneNumber('01812345678'))).toBe('robi');
  });

  it('identifies Cirkle (016)', () => {
    expect(bdOperatorForNormalizedPhone(normalizeBdPhoneNumber('01612345678'))).toBe('cirkle');
  });

  it('rejects 019 (Banglalink/Airtel-legacy — not a supported operator)', () => {
    expect(bdOperatorForNormalizedPhone(normalizeBdPhoneNumber('01912345678'))).toBeNull();
  });

  it('rejects Grameenphone (017)', () => {
    expect(bdOperatorForNormalizedPhone(normalizeBdPhoneNumber('01712345678'))).toBeNull();
  });

  it('rejects Banglalink (014)', () => {
    expect(bdOperatorForNormalizedPhone(normalizeBdPhoneNumber('01412345678'))).toBeNull();
  });

  it('rejects a malformed/short number', () => {
    expect(bdOperatorForNormalizedPhone('880181234')).toBeNull();
  });
});
