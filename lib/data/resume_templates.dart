/// Five original, genuinely different ATS-friendly resume structures —
/// not five cosmetic variations of the same layout. Each is a written
/// guide (section order + what goes in each), not a live editor: no
/// specific named template design was copied from anywhere (that would
/// be someone else's copyrighted layout); these follow well-known,
/// generic ATS conventions — single-column, standard section headers, no
/// tables/graphics/columns that risk garbling on parsing.
class ResumeTemplate {
  const ResumeTemplate({
    required this.name,
    required this.description,
    required this.bestFor,
    required this.sections,
  });

  final String name;
  final String description;
  final String bestFor;

  /// (section title, guidance) pairs, in the order they should appear.
  final List<(String, String)> sections;
}

const resumeTemplates = <ResumeTemplate>[
  ResumeTemplate(
    name: 'Classic ATS',
    description: 'Single-column, conservative, maximum ATS compatibility. The safest default.',
    bestFor: 'Any role, especially when you\'re unsure what the employer\'s system can parse.',
    sections: [
      ('Contact info', 'Full name, phone, email, city. A LinkedIn/portfolio link only if you have one.'),
      (
        'Summary (2–3 lines)',
        'What you do, your strongest skill area, what role you want. Plain sentences, no graphics.',
      ),
      ('Skills', 'A plain comma- or line-separated list — no skill "bars" or ratings (ATS can\'t parse those).'),
      (
        'Experience',
        'Title, company, dates (Month Year – Month Year). 2–4 bullets per role, action verb first, '
            'a number where you can: "Built a Flutter app used by 500+ daily users."',
      ),
      ('Education', 'Degree, institution, graduation year.'),
    ],
  ),
  ResumeTemplate(
    name: 'Modern Professional',
    description: 'Same ATS-safe single column, slightly more contemporary section framing.',
    bestFor: 'Mid-level roles where the resume might also be read by a person before an ATS.',
    sections: [
      ('Header', 'Name as a clear heading, then contact info on one line beneath it.'),
      (
        'Professional summary',
        '3–4 lines: years of experience, specialty, one standout achievement, target role.',
      ),
      ('Core skills', 'Grouped by category if you have several (e.g. "Languages," "Tools") — still plain text.'),
      ('Professional experience', 'Same structure as Classic ATS, but group similar roles if you\'ve had several short ones.'),
      ('Education & certifications', 'Combine these into one section if you don\'t have much of either.'),
    ],
  ),
  ResumeTemplate(
    name: 'Technical',
    description: 'For software/data/engineering roles — projects carry as much weight as job titles.',
    bestFor: 'Software engineering, data, AI/ML, and other build-things roles.',
    sections: [
      ('Contact info', 'Same as Classic ATS — keep it plain.'),
      (
        'Summary',
        'Your stack/specialty and what you build. e.g. "Backend engineer focused on Flutter/Firebase '
            'mobile apps, 2 years professional experience."',
      ),
      (
        'Technical skills',
        'Group by type: Languages, Frameworks, Tools/Platforms, Databases — plain lists, not proficiency bars.',
      ),
      (
        'Projects',
        '2–4 projects (work or personal): name, one-line description, your specific contribution, tech used. '
            'This section often matters more than job titles for junior/mid roles.',
      ),
      ('Experience', 'Same bullet structure as Classic ATS.'),
      ('Education', 'Degree, institution, year — add relevant coursework only if you\'re early-career.'),
    ],
  ),
  ResumeTemplate(
    name: 'Entry-Level / New Graduate',
    description: 'Education and projects lead, since work history is naturally short — not weaker for it.',
    bestFor: 'Students, recent graduates, or a first professional role.',
    sections: [
      ('Contact info', 'Same as Classic ATS.'),
      (
        'Objective',
        '1–2 lines: what you\'re looking for and what you bring. e.g. "Recent CSE graduate seeking a '
            'junior mobile developer role, with hands-on Flutter/Firebase project experience."',
      ),
      ('Education', 'Moved up front here: degree, institution, graduation year, relevant coursework, GPA if strong.'),
      (
        'Projects',
        'Academic or personal projects, same structure as the Technical template\'s Projects section — '
            'this is often your strongest material at this stage.',
      ),
      ('Skills', 'Plain list, most relevant first.'),
      ('Experience', 'Internships, part-time work, or campus activities with real responsibility — same bullet structure.'),
    ],
  ),
  ResumeTemplate(
    name: 'Executive / Minimal',
    description: 'Extremely clean, spacious, typography-led — for candidates with substantial experience.',
    bestFor: 'Senior/lead/management roles where achievements should speak with little decoration.',
    sections: [
      ('Contact info', 'Name, phone, email, city — nothing else.'),
      (
        'Executive summary',
        '3–5 lines: scope of experience (years, domains, team/budget size if relevant), one or two '
            'headline achievements, career focus going forward.',
      ),
      (
        'Experience',
        'Fewer, more senior roles — 3–5 bullets each, weighted toward outcomes and scale '
            '("Led a team of 8," "Reduced infra cost by 30%") over day-to-day tasks.',
      ),
      ('Core competencies', 'A short plain list — leadership/domain areas, not tools (those matter less at this level).'),
      ('Education', 'Degree, institution — condensed to one line; omit graduation year if it\'s been 10+ years.'),
    ],
  ),
];
