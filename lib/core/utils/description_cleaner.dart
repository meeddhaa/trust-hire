/// Strips scraped-page boilerplate that rides along with a JSearch
/// listing's real description text — confirmed live on real seeded data:
/// a repeated company-name header and a stray "Follow" (a webpage
/// follow-button label), both artifacts of the page JSearch scraped, not
/// anything the original poster wrote.
///
/// Deliberately conservative: only trims an exact-match prefix run of
/// blank/noise lines from the very START of the text, never scans or
/// removes matches later in the body. A company name mentioned mid-
/// sentence in real content ("As part of Acme Corp's growth...") must
/// never be touched — only a *repeated, standalone* leading occurrence is
/// noise. Purely a display-time cleanup; the stored `description` field
/// itself is untouched; see docs/ARCHITECTURE.md `Decision: JSearch for
/// real listings` for why the raw field is never rewritten server-side.
abstract final class DescriptionCleaner {
  static String clean(String description, String company) {
    final companyLower = company.trim().toLowerCase();
    var lines = description.split('\n');

    while (lines.isNotEmpty) {
      final trimmed = lines.first.trim();
      final isNoise = trimmed.isEmpty || trimmed.toLowerCase() == companyLower || trimmed.toLowerCase() == 'follow';
      if (!isNoise) break;
      lines = lines.skip(1).toList();
    }

    final result = lines.join('\n').trimLeft();
    // If everything looked like noise (a genuinely empty/garbage
    // description), fall back to the untouched original rather than
    // showing a blank section — a raw, ugly description still beats no
    // description at all.
    return result.isEmpty ? description : result;
  }
}
