import 'package:equatable/equatable.dart';

import '../../core/utils/firestore_codec.dart';

/// How an applicant is expected to make contact. `whatsappOnly` is one of
/// the five deterministic scam-rule signals in the brief — a listing that
/// gives no email/phone/portal, only a WhatsApp number, is a red flag on
/// its own regardless of what the text says.
enum ContactMethod {
  email,
  phone,
  whatsappOnly,
  applicationPortal;

  static ContactMethod fromString(String value) => ContactMethod.values.firstWhere(
        (v) => v.name == value,
        orElse: () => ContactMethod.applicationPortal,
      );
}

enum EmploymentType {
  fullTime,
  partTime,
  contract,
  internship;

  static EmploymentType fromString(String value) => EmploymentType.values.firstWhere(
        (v) => v.name == value,
        orElse: () => EmploymentType.fullTime,
      );
}

/// A single job posting in the feed, seeded from real BD listings.
///
/// Field choices here double as the raw inputs to the rule-based scam
/// scorer (`data/services/scam_rule_engine.dart`, step 3) — `companyDomain`,
/// `salaryMin`/`Max`, `contactMethod`, and `applicationFeeRequired` map
/// directly onto the five signals in the brief (no verifiable domain,
/// unrealistic salary, WhatsApp-only contact, upfront fees, and urgency
/// language parsed from `description` at scoring time).
class JobListing extends Equatable {
  const JobListing({
    required this.id,
    required this.title,
    required this.company,
    this.companyDomain,
    required this.location,
    this.isRemote = false,
    this.employmentType = EmploymentType.fullTime,
    this.salaryMin,
    this.salaryMax,
    this.salaryCurrency = 'BDT',
    required this.description,
    this.requiredSkills = const [],
    this.contactMethod = ContactMethod.applicationPortal,
    this.contactValue,
    this.applicationFeeRequired = false,
    required this.sourceUrl,
    required this.sourceName,
    required this.postedAt,
    required this.fetchedAt,
  });

  final String id;
  final String title;
  final String company;

  /// e.g. `"brigade.com.bd"`. Null (or a free-mail domain like gmail.com,
  /// which the rule engine checks for separately) is the "no verifiable
  /// company domain" scam signal from the brief.
  final String? companyDomain;

  final String location;
  final bool isRemote;
  final EmploymentType employmentType;

  /// Null when a listing doesn't disclose salary at all — itself neutral,
  /// distinct from a disclosed-but-implausible range, which the rule
  /// engine flags as "unrealistic salary".
  final int? salaryMin;
  final int? salaryMax;
  final String salaryCurrency;

  /// Full listing text. Scanned by the rule engine for urgency language
  /// ("apply immediately", "limited slots") and passed as context to the
  /// Gemini call for both match-gap reasoning and scam-risk reasoning.
  final String description;

  final List<String> requiredSkills;

  final ContactMethod contactMethod;

  /// The email address / phone number / portal URL itself, shown in the UI
  /// next to the contact method.
  final String? contactValue;

  /// True if the listing text asks the applicant to pay anything upfront
  /// (registration fee, "training deposit", etc.) — an unambiguous scam
  /// signal on its own.
  final bool applicationFeeRequired;

  /// Original posting URL, opened in the in-app WebView — this is the
  /// "live web browsing" capability the bdapps brief requires, not just a
  /// static description screen.
  final String sourceUrl;

  /// Where the listing was sourced from (e.g. "bdjobs.com", "LinkedIn"),
  /// shown as attribution and used by the rule engine as a mild trust
  /// prior (a known aggregator vs. an unknown standalone posting).
  final String sourceName;

  final DateTime postedAt;

  /// When this document was written to Firestore by the seed script —
  /// distinct from `postedAt` (which reflects the original posting date)
  /// so "freshness" and "ingestion time" don't get conflated.
  final DateTime fetchedAt;

  factory JobListing.fromMap(Map<String, dynamic> map, {required String id}) {
    return JobListing(
      id: id,
      title: map['title'] as String? ?? '',
      company: map['company'] as String? ?? '',
      companyDomain: map['companyDomain'] as String?,
      location: map['location'] as String? ?? '',
      isRemote: map['isRemote'] as bool? ?? false,
      employmentType: EmploymentType.fromString(map['employmentType'] as String? ?? ''),
      salaryMin: map['salaryMin'] as int?,
      salaryMax: map['salaryMax'] as int?,
      salaryCurrency: map['salaryCurrency'] as String? ?? 'BDT',
      description: map['description'] as String? ?? '',
      requiredSkills: List<String>.from(map['requiredSkills'] as List? ?? const []),
      contactMethod: ContactMethod.fromString(map['contactMethod'] as String? ?? ''),
      contactValue: map['contactValue'] as String?,
      applicationFeeRequired: map['applicationFeeRequired'] as bool? ?? false,
      sourceUrl: map['sourceUrl'] as String? ?? '',
      sourceName: map['sourceName'] as String? ?? '',
      postedAt: dateTimeFromValue(map['postedAt']),
      fetchedAt: dateTimeFromValue(map['fetchedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'company': company,
      'companyDomain': companyDomain,
      'location': location,
      'isRemote': isRemote,
      'employmentType': employmentType.name,
      'salaryMin': salaryMin,
      'salaryMax': salaryMax,
      'salaryCurrency': salaryCurrency,
      'description': description,
      'requiredSkills': requiredSkills,
      'contactMethod': contactMethod.name,
      'contactValue': contactValue,
      'applicationFeeRequired': applicationFeeRequired,
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'postedAt': timestampFromDateTime(postedAt),
      'fetchedAt': timestampFromDateTime(fetchedAt),
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        company,
        companyDomain,
        location,
        isRemote,
        employmentType,
        salaryMin,
        salaryMax,
        salaryCurrency,
        description,
        requiredSkills,
        contactMethod,
        contactValue,
        applicationFeeRequired,
        sourceUrl,
        sourceName,
        postedAt,
        fetchedAt,
      ];
}
