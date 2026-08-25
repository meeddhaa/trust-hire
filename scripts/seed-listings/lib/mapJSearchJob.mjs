import { createHash } from 'node:crypto';
import { extractSkills } from './skillKeywords.mjs';

const EMPLOYMENT_TYPE_MAP = {
  FULLTIME: 'fullTime',
  PARTTIME: 'partTime',
  CONTRACTOR: 'contract',
  INTERN: 'internship',
};

function domainFromUrl(url) {
  if (!url) return null;
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return null;
  }
}

function stableId(jobId) {
  // Deterministic, Firestore-safe (no reserved __..__ pattern), and
  // idempotent across re-runs of the seed script — re-seeding overwrites
  // the same doc rather than duplicating it.
  return `js-${createHash('sha1').update(jobId).digest('hex').slice(0, 16)}`;
}

/** Maps one JSearch job object to the `JobListing` Firestore shape (see
 * `lib/data/models/job_listing.dart`). Every field JSearch doesn't
 * reliably provide (salary, structured skills) degrades to the same
 * "unknown, not disclosed" value the model already treats as neutral —
 * see that model's doc comments for why null salary isn't itself a scam
 * signal, only an inverted or implausible range is. */
export function mapJSearchJob(job) {
  const location = [job.job_city, job.job_state].filter(Boolean).join(', ') || job.job_location || 'Bangladesh';

  return {
    id: stableId(job.job_id),
    title: job.job_title ?? 'Untitled role',
    company: job.employer_name ?? 'Unknown company',
    companyDomain: domainFromUrl(job.employer_website),
    location,
    isRemote: Boolean(job.job_is_remote),
    employmentType: EMPLOYMENT_TYPE_MAP[job.job_employment_type] ?? 'fullTime',
    salaryMin: job.job_min_salary ?? null,
    salaryMax: job.job_max_salary ?? null,
    salaryCurrency: job.job_salary_currency ?? 'BDT',
    description: job.job_description ?? '',
    requiredSkills: extractSkills(job.job_description),
    contactMethod: 'applicationPortal',
    contactValue: job.job_apply_link ?? null,
    applicationFeeRequired: false,
    sourceUrl: job.job_apply_link ?? job.job_google_link ?? '',
    sourceName: job.job_publisher ?? 'JSearch',
    postedAt: job.job_posted_at_datetime_utc ? new Date(job.job_posted_at_datetime_utc) : new Date(),
    fetchedAt: new Date(),
  };
}
