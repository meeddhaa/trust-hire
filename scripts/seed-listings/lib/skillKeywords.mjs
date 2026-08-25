/**
 * JSearch doesn't return a structured skills list (its `job_highlights`
 * come back empty for BD listings in practice — confirmed against real
 * responses, not assumed), so `requiredSkills` is extracted by scanning
 * `job_description` against this dictionary instead. It only needs to be
 * broad enough to cover the five categories seeded (software, marketing,
 * accounting, customer support, design) — not exhaustive.
 *
 * This is a display/rule-engine input (card chips, and the scam rule
 * engine's "high salary needs a seniority signal" check), not what the
 * match-gap LLM call relies on — that call always gets the full
 * `description` text regardless of what this extracts.
 */
export const SKILL_KEYWORDS = [
  // Software / tech
  'JavaScript', 'TypeScript', 'Python', 'Java', 'PHP', 'React', 'Node.js', 'Angular', 'Vue',
  'Android', 'Kotlin', 'Swift', 'Flutter', 'Laravel', 'Django', 'WordPress', 'MERN',
  'SQL', 'MySQL', 'PostgreSQL', 'MongoDB', 'AWS', 'Docker', 'Kubernetes', 'Git', 'CI/CD',
  'HTML', 'CSS', '.NET', 'C#', 'C++', 'REST API', 'Salesforce', 'SAP',
  // Design
  'Figma', 'Photoshop', 'Illustrator', 'Adobe XD', 'UI/UX', 'Canva',
  // Marketing
  'SEO', 'Google Ads', 'Facebook Ads', 'Social Media Marketing', 'Content Marketing',
  'Email Marketing', 'Google Analytics',
  // Accounting / finance
  'Excel', 'QuickBooks', 'Tally', 'Bookkeeping', 'Financial Reporting', 'Tax',
  // Cross-cutting
  'Communication', 'Customer Service', 'Project Management', 'Leadership', 'Microsoft Office',
];

/** Returns up to 8 dictionary terms that appear in `text`, longest-match
 * first so e.g. "Node.js" wins over a coincidental "Java" substring. */
export function extractSkills(text) {
  if (!text) return [];
  const found = [];
  const lower = text.toLowerCase();
  const sorted = [...SKILL_KEYWORDS].sort((a, b) => b.length - a.length);
  for (const skill of sorted) {
    if (lower.includes(skill.toLowerCase()) && !found.includes(skill)) {
      found.push(skill);
    }
    if (found.length >= 8) break;
  }
  return found;
}
