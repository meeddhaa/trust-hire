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

// Whether a posting is remote, per its OWN text — not overriding
// JSearch's `job_is_remote` flag, supplementing it. Confirmed live: that
// flag came back `false` for every single Bangladesh-scoped result
// tested, including ones whose own title says "(UK only, fully remote)"
// — it just doesn't reflect reality for this dataset. Querying with
// "remote"-worded search terms instead (tried first) broke the
// `country=bd` scoping entirely and returned US/UK postings, so isn't a
// fix either. A text scan of the posting JSearch itself already returned
// is the honest middle ground: no invented data, just reading what the
// posting already says.
const REMOTE_PATTERN = /\bremote\b|work[\s-]?from[\s-]?home|\bwfh\b/i;

function isActuallyRemote(job) {
  if (job.job_is_remote) return true;
  return REMOTE_PATTERN.test(`${job.job_title ?? ''} ${job.job_description ?? ''}`);
}

// The old fallback defaulted every posting with no city/state to
// "Bangladesh" — fine when every query was BD-scoped, wrong now that
// `fetchJSearch.mjs` also pulls international "work from anywhere" roles
// (see that file's `REMOTE_QUERIES`), which often carry no city/state at
// all. Falls back to the posting's own country only as a last resort
// before assuming BD.
function locationLabel(job, remote) {
  const cityState = [job.job_city, job.job_state].filter(Boolean).join(', ');
  if (cityState) return cityState;
  if (job.job_location) return job.job_location;
  if (remote) return job.job_country && job.job_country !== 'BD' ? `Remote (${job.job_country})` : 'Remote — Worldwide';
  return job.job_country && job.job_country !== 'BD' ? job.job_country : 'Bangladesh';
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
  const remote = isActuallyRemote(job);

  return {
    id: stableId(job.job_id),
    title: job.job_title ?? 'Untitled role',
    company: job.employer_name ?? 'Unknown company',
    companyDomain: domainFromUrl(job.employer_website),
    location: locationLabel(job, remote),
    isRemote: remote,
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
