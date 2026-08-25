/// Suggestion dictionary for the onboarding skill input's autocomplete —
/// covers the same categories seeded in `scripts/seed-listings/` (software,
/// marketing, accounting, customer support, design) plus general
/// cross-cutting skills, so suggestions actually line up with what's in
/// the feed. Free text is still accepted; this only drives suggestions,
/// never restricts what a user can add — see `OnboardingScreen`.
abstract final class SkillKeywords {
  static const List<String> all = [
    // Software / tech
    'JavaScript', 'TypeScript', 'Python', 'Java', 'PHP', 'React', 'Node.js', 'Angular', 'Vue',
    'Android', 'Kotlin', 'Swift', 'Flutter', 'Laravel', 'Django', 'WordPress',
    'SQL', 'MySQL', 'PostgreSQL', 'MongoDB', 'AWS', 'Docker', 'Kubernetes', 'Git', 'CI/CD',
    'HTML', 'CSS', '.NET', 'C#', 'C++', 'REST API', 'Salesforce', 'SAP',
    // Design
    'Figma', 'Photoshop', 'Illustrator', 'Adobe XD', 'UI/UX Design', 'Canva',
    // Marketing
    'SEO', 'Google Ads', 'Facebook Ads', 'Social Media Marketing', 'Content Marketing',
    'Email Marketing', 'Google Analytics', 'Copywriting',
    // Accounting / finance
    'Excel', 'QuickBooks', 'Tally', 'Bookkeeping', 'Financial Reporting', 'Tax Preparation',
    // Cross-cutting
    'Communication', 'Customer Service', 'Project Management', 'Leadership',
    'Microsoft Office', 'Data Entry', 'Problem Solving', 'Team Management',
  ];

  /// Case-insensitive prefix/substring match, existing selections excluded,
  /// capped so the suggestion list never overwhelms the field.
  static List<String> suggestionsFor(String query, {required List<String> exclude, int limit = 6}) {
    if (query.trim().isEmpty) return const [];
    final lowerQuery = query.toLowerCase();
    final lowerExclude = exclude.map((s) => s.toLowerCase()).toSet();
    return all
        .where((skill) => skill.toLowerCase().contains(lowerQuery) && !lowerExclude.contains(skill.toLowerCase()))
        .take(limit)
        .toList();
  }
}
