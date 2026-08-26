import 'package:flutter_test/flutter_test.dart';
import 'package:trusthire/data/models/job_listing.dart';
import 'package:trusthire/data/models/scam_assessment.dart';
import 'package:trusthire/data/services/scam_rule_engine.dart';

/// Mirrors `worker/test/scamRules.test.ts` — same signals, same
/// thresholds, same cases, since `ScamRuleEngine` is a hand-kept-in-sync
/// Dart port of `worker/src/scamRules.ts` (see that file's doc comment).
/// Keeping the two test suites parallel makes it obvious if the two
/// implementations ever drift.
JobListing _listing({
  String title = 'Software Engineer',
  String? companyDomain = 'brigade.com.bd',
  int? salaryMin = 40000,
  int? salaryMax = 60000,
  String description = 'We are hiring a backend engineer with Node.js experience.',
  List<String> requiredSkills = const ['Node.js', 'PostgreSQL', 'AWS'],
  ContactMethod contactMethod = ContactMethod.applicationPortal,
  bool applicationFeeRequired = false,
}) {
  return JobListing(
    id: 'test-listing',
    title: title,
    company: 'Brigade Ltd.',
    companyDomain: companyDomain,
    location: 'Dhaka',
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    salaryCurrency: 'BDT',
    description: description,
    requiredSkills: requiredSkills,
    contactMethod: contactMethod,
    applicationFeeRequired: applicationFeeRequired,
    sourceUrl: 'https://brigade.com.bd/careers/1',
    sourceName: 'test',
    postedAt: DateTime(2026, 1, 1),
    fetchedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ScamRuleEngine.computeFlags', () {
    test('flags nothing for a clean, legitimate-looking listing', () {
      final flags = ScamRuleEngine.computeFlags(_listing());
      expect(flags.upfrontFeesRequested, isFalse);
      expect(flags.unrealisticSalary, isFalse);
      expect(flags.noVerifiableDomain, isFalse);
      expect(flags.urgencyLanguage, isFalse);
      expect(flags.whatsappOnlyContact, isFalse);
      expect(flags.triggeredCount, 0);
    });

    test('flags an explicit application fee', () {
      final flags = ScamRuleEngine.computeFlags(_listing(applicationFeeRequired: true));
      expect(flags.upfrontFeesRequested, isTrue);
    });

    test('flags a fee mentioned only in the listing text', () {
      final flags = ScamRuleEngine.computeFlags(
        _listing(description: 'Pay a small registration fee to secure your slot.'),
      );
      expect(flags.upfrontFeesRequested, isTrue);
    });

    test('flags an implausibly high salary for an unskilled-sounding role', () {
      final flags = ScamRuleEngine.computeFlags(
        _listing(salaryMin: 50000, salaryMax: 500000, requiredSkills: const ['Typing']),
      );
      expect(flags.unrealisticSalary, isTrue);
    });

    test('does not flag a high salary when the role lists real seniority signals', () {
      final flags = ScamRuleEngine.computeFlags(
        _listing(
          salaryMin: 200000,
          salaryMax: 500000,
          requiredSkills: const ['Kubernetes', 'Go', 'System Design'],
        ),
      );
      expect(flags.unrealisticSalary, isFalse);
    });

    test('flags an inverted salary range regardless of magnitude', () {
      final flags = ScamRuleEngine.computeFlags(_listing(salaryMin: 80000, salaryMax: 40000));
      expect(flags.unrealisticSalary, isTrue);
    });

    test(
      'flags a large figure in free text combined with no-qualification language, '
      'when structured salary is absent',
      () {
        final flags = ScamRuleEngine.computeFlags(
          _listing(
            salaryMin: null,
            salaryMax: null,
            title: 'Data Entry Job - Earn \$50,000/year, No Experience Needed',
          ),
        );
        expect(flags.unrealisticSalary, isTrue);
      },
    );

    test(
      'does not flag a large figure in free text without no-qualification language '
      '(a real senior/remote role)',
      () {
        final flags = ScamRuleEngine.computeFlags(
          _listing(
            salaryMin: null,
            salaryMax: null,
            title: 'Engineering Director (OTE \$100,000/year USD)',
            description: 'Lead our platform engineering team. 8+ years experience required.',
          ),
        );
        expect(flags.unrealisticSalary, isFalse);
      },
    );

    test('does not double-flag via text when structured salary is already present', () {
      final flags = ScamRuleEngine.computeFlags(
        _listing(
          salaryMin: 40000,
          salaryMax: 60000,
          title: 'Entry level role, no experience needed, \$50,000',
        ),
      );
      // Structured range (40k-60k BDT) is plausible on its own -- the text
      // mention shouldn't override that via the fallback path.
      expect(flags.unrealisticSalary, isFalse);
    });

    test('flags a missing company domain', () {
      final flags = ScamRuleEngine.computeFlags(_listing(companyDomain: null));
      expect(flags.noVerifiableDomain, isTrue);
    });

    test('flags a free-mail domain standing in for a company domain', () {
      final flags = ScamRuleEngine.computeFlags(_listing(companyDomain: 'gmail.com'));
      expect(flags.noVerifiableDomain, isTrue);
    });

    test('flags urgency language in the description', () {
      final flags = ScamRuleEngine.computeFlags(
        _listing(description: 'Apply immediately, only 2 slots left!'),
      );
      expect(flags.urgencyLanguage, isTrue);
    });

    test('flags WhatsApp-only contact', () {
      final flags = ScamRuleEngine.computeFlags(_listing(contactMethod: ContactMethod.whatsappOnly));
      expect(flags.whatsappOnlyContact, isTrue);
    });

    test('flags every signal on a maximally suspicious listing', () {
      final flags = ScamRuleEngine.computeFlags(
        _listing(
          companyDomain: null,
          salaryMin: 10000,
          salaryMax: 800000,
          requiredSkills: const [],
          description: 'Urgent hiring! Apply immediately. Pay a small registration fee.',
          contactMethod: ContactMethod.whatsappOnly,
          applicationFeeRequired: true,
        ),
      );
      expect(flags.triggeredCount, 5);
      expect(ScamRuleEngine.computeRuleScore(flags), 100);
    });
  });

  group('ScamRuleEngine.bandTrustBadge', () {
    test('bands 0 to verified-leaning', () {
      expect(ScamRuleEngine.bandTrustBadge(0), TrustBadge.verifiedLeaning);
    });

    test('bands a single flag (20) to caution', () {
      expect(ScamRuleEngine.bandTrustBadge(20), TrustBadge.caution);
    });

    test('bands two or more flags (40+) to high risk', () {
      expect(ScamRuleEngine.bandTrustBadge(40), TrustBadge.highRisk);
      expect(ScamRuleEngine.bandTrustBadge(100), TrustBadge.highRisk);
    });
  });
}
