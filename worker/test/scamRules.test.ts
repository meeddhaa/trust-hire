import { describe, expect, it } from 'vitest';
import { bandTrustBadge, computeRuleScore, computeScamRuleFlags, triggeredCount } from '../src/scamRules';
import type { JobListingDoc } from '../src/types';

function listing(overrides: Partial<JobListingDoc> = {}): JobListingDoc {
  return {
    title: 'Software Engineer',
    company: 'Brigade Ltd.',
    companyDomain: 'brigade.com.bd',
    location: 'Dhaka',
    salaryMin: 40000,
    salaryMax: 60000,
    salaryCurrency: 'BDT',
    description: 'We are hiring a backend engineer with Node.js experience.',
    requiredSkills: ['Node.js', 'PostgreSQL', 'AWS'],
    contactMethod: 'applicationPortal',
    applicationFeeRequired: false,
    ...overrides,
  };
}

describe('computeScamRuleFlags', () => {
  it('flags nothing for a clean, legitimate-looking listing', () => {
    const flags = computeScamRuleFlags(listing());
    expect(flags).toEqual({
      upfrontFeesRequested: false,
      unrealisticSalary: false,
      noVerifiableDomain: false,
      urgencyLanguage: false,
      whatsappOnlyContact: false,
    });
    expect(triggeredCount(flags)).toBe(0);
  });

  it('flags an explicit application fee', () => {
    const flags = computeScamRuleFlags(listing({ applicationFeeRequired: true }));
    expect(flags.upfrontFeesRequested).toBe(true);
  });

  it('flags a fee mentioned only in the listing text', () => {
    const flags = computeScamRuleFlags(
      listing({ description: 'Pay a small registration fee to secure your slot.' }),
    );
    expect(flags.upfrontFeesRequested).toBe(true);
  });

  it('flags an implausibly high salary for an unskilled-sounding role', () => {
    const flags = computeScamRuleFlags(
      listing({ salaryMin: 50000, salaryMax: 500000, requiredSkills: ['Typing'] }),
    );
    expect(flags.unrealisticSalary).toBe(true);
  });

  it('does not flag a high salary when the role lists real seniority signals', () => {
    const flags = computeScamRuleFlags(
      listing({
        salaryMin: 200000,
        salaryMax: 500000,
        requiredSkills: ['Kubernetes', 'Go', 'System Design'],
      }),
    );
    expect(flags.unrealisticSalary).toBe(false);
  });

  it('flags an inverted salary range regardless of magnitude', () => {
    const flags = computeScamRuleFlags(listing({ salaryMin: 80000, salaryMax: 40000 }));
    expect(flags.unrealisticSalary).toBe(true);
  });

  it('flags a missing company domain', () => {
    const flags = computeScamRuleFlags(listing({ companyDomain: undefined }));
    expect(flags.noVerifiableDomain).toBe(true);
  });

  it('flags a free-mail domain standing in for a company domain', () => {
    const flags = computeScamRuleFlags(listing({ companyDomain: 'gmail.com' }));
    expect(flags.noVerifiableDomain).toBe(true);
  });

  it('flags urgency language in the description', () => {
    const flags = computeScamRuleFlags(
      listing({ description: 'Apply immediately, only 2 slots left!' }),
    );
    expect(flags.urgencyLanguage).toBe(true);
  });

  it('flags WhatsApp-only contact', () => {
    const flags = computeScamRuleFlags(listing({ contactMethod: 'whatsappOnly' }));
    expect(flags.whatsappOnlyContact).toBe(true);
  });

  it('flags every signal on a maximally suspicious listing', () => {
    const flags = computeScamRuleFlags(
      listing({
        companyDomain: undefined,
        salaryMin: 10000,
        salaryMax: 800000,
        requiredSkills: [],
        description: 'Urgent hiring! Apply immediately. Pay a small registration fee.',
        contactMethod: 'whatsappOnly',
        applicationFeeRequired: true,
      }),
    );
    expect(triggeredCount(flags)).toBe(5);
    expect(computeRuleScore(flags)).toBe(100);
  });
});

describe('bandTrustBadge', () => {
  it('bands 0 to verified-leaning', () => {
    expect(bandTrustBadge(0)).toBe('verifiedLeaning');
  });

  it('bands a single flag (20) to caution', () => {
    expect(bandTrustBadge(20)).toBe('caution');
  });

  it('bands two or more flags (40+) to high risk', () => {
    expect(bandTrustBadge(40)).toBe('highRisk');
    expect(bandTrustBadge(100)).toBe('highRisk');
  });
});
