/**
 * Hand-authored, deliberately fraudulent-pattern listings — JSearch only
 * ever returns real, legitimate aggregator data (confirmed against live
 * responses: no upfront fees, no WhatsApp-only contact, no urgency
 * language, salary essentially always undisclosed), so it can never
 * supply the brief's explicit requirement for "realistic scam-pattern
 * examples" for the risk detector to actually catch. These fill that gap.
 *
 * Company names are invented, not references to any real organization.
 * Patterns are drawn from well-documented real-world job-scam tactics
 * (upfront "training/registration fees," WhatsApp-only recruiting,
 * unrealistic no-experience pay, artificial urgency), not copied from any
 * specific posting.
 *
 * Spread deliberately across the badge spectrum — not all five signals
 * maxed out on every example — so the demo shows caution *and* high-risk,
 * not just one extreme.
 */
export const SCAM_EXAMPLES = [
  {
    id: 'scam-example-data-entry-wfh',
    title: 'Data Entry Executive - Work From Home',
    company: 'Prime Earnings BD',
    companyDomain: null,
    location: 'Dhaka (Remote)',
    isRemote: true,
    employmentType: 'partTime',
    salaryMin: 80000,
    salaryMax: 450000,
    salaryCurrency: 'BDT',
    description:
      'Urgent hiring! Apply immediately, only 4 seats left. No experience needed — earn a huge salary ' +
      'working from home just 2 hours a day. A small refundable registration fee is required to book ' +
      'your training slot and receive your starter kit. Message us on WhatsApp to begin today.',
    requiredSkills: ['Typing'],
    contactMethod: 'whatsappOnly',
    contactValue: '+8801XXXXXXXXX',
    applicationFeeRequired: true,
    sourceUrl: 'https://example.com/scam-listing-data-entry',
    sourceName: 'Curated example',
    postedAt: new Date(),
    fetchedAt: new Date(),
  },
  {
    id: 'scam-example-trainee-recruiter',
    title: 'Trainee Recruitment Officer',
    company: 'Bright Future Consultancy',
    companyDomain: null,
    location: 'Dhaka',
    isRemote: false,
    employmentType: 'fullTime',
    salaryMin: 35000,
    salaryMax: 45000,
    salaryCurrency: 'BDT',
    description:
      'We are looking for enthusiastic freshers to join our HR team. Fresh graduates welcome, no ' +
      'experience required. A one-time training fee of 2,500 BDT applies, deducted from your first ' +
      'salary. Contact our HR only via WhatsApp for a fast response.',
    requiredSkills: [],
    contactMethod: 'whatsappOnly',
    contactValue: '+8801XXXXXXXXX',
    applicationFeeRequired: true,
    sourceUrl: 'https://example.com/scam-listing-trainee-recruiter',
    sourceName: 'Curated example',
    postedAt: new Date(),
    fetchedAt: new Date(),
  },
  {
    // Deliberately only ONE flag (urgency language) — a "caution", not
    // "high risk", example. Real scams aren't always maximal; the badge
    // spectrum should show that.
    id: 'scam-example-urgent-sales',
    title: 'Urgent! Sales Associate Needed Today',
    company: 'MegaDeal Traders',
    companyDomain: 'megadeal-traders.com',
    location: 'Dhaka',
    isRemote: false,
    employmentType: 'fullTime',
    salaryMin: 25000,
    salaryMax: 30000,
    salaryCurrency: 'BDT',
    description:
      'Hiring today! Limited slots — apply immediately to join our growing sales team. Great incentives ' +
      'for the right candidate. Please email your CV directly; no calls.',
    requiredSkills: ['Communication'],
    contactMethod: 'email',
    contactValue: 'megadealtraders.hr@gmail.com',
    applicationFeeRequired: false,
    sourceUrl: 'https://example.com/scam-listing-urgent-sales',
    sourceName: 'Curated example',
    postedAt: new Date(),
    fetchedAt: new Date(),
  },
  {
    // Also deliberately ONE flag (no verifiable domain) — everything else
    // about it reads as plausible on its own, which is the point: a
    // single red flag should read as "caution," not full alarm.
    id: 'scam-example-online-typing',
    title: 'Online Typing Job - Earn From Home',
    company: 'QuickCash Ventures',
    companyDomain: null,
    location: 'Anywhere in Bangladesh (Remote)',
    isRemote: true,
    employmentType: 'partTime',
    salaryMin: 20000,
    salaryMax: 28000,
    salaryCurrency: 'BDT',
    description:
      'Simple typing work from home, flexible hours. Steady part-time income for students and homemakers. ' +
      'Email your CV to apply — no experience required.',
    requiredSkills: [],
    contactMethod: 'email',
    contactValue: 'hiring@quickcashventures.example',
    applicationFeeRequired: false,
    sourceUrl: 'https://example.com/scam-listing-online-typing',
    sourceName: 'Curated example',
    postedAt: new Date(),
    fetchedAt: new Date(),
  },
];
