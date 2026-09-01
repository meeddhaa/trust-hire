/// Normalizes a Bangladeshi phone number to the bare-digits form AppsPro's
/// own webhook/API payloads use internally (e.g. `subscriberId: "tel:8801712345678"`
/// minus the "tel:" prefix) — "8801XXXXXXXXX", no "+", no leading "0".
///
/// AppsPro's checkout/OTP endpoints accept three input shapes
/// (`01XXXXXXXXX`, `8801XXXXXXXXX`, `+8801XXXXXXXXX` per their docs), but
/// their webhook always reports the subscriber back in the third form
/// stripped of its "+". Storing that exact same normalized form on the
/// profile (see `ProfileRepository.setPhoneNumber`) is what lets the
/// Worker's webhook handler join a `subscriber.created` event back to a
/// Firestore user by an exact-match query — any other stored shape would
/// silently never match.
///
/// Mirrored server-side in `worker/src/bdPhone.ts` — kept in lockstep
/// deliberately, since the Worker independently re-derives the operator
/// from whatever phone number it receives rather than trusting this
/// client's validation (see `bdOperatorForNormalizedPhone`'s doc comment).
String normalizeBdPhoneNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('880')) return digits;
  if (digits.startsWith('0')) return '880${digits.substring(1)}';
  return '880$digits';
}

/// The two BD mobile operators this app's bdapps subscription actually
/// supports — a business requirement (which operators bdapps DCB is
/// configured for), not something AppsPro's own API enforces or exposes.
enum BdOperator {
  robi('Robi', '018'),
  cirkle('Cirkle', '016');

  const BdOperator(this.label, this.prefix);

  /// Display name for the operator picker.
  final String label;

  /// The local-dial prefix ("01" + this) shown as field hint text.
  final String prefix;
}

/// Derives the supported operator from a normalized (`normalizeBdPhoneNumber`)
/// phone number, purely from its digits — this is the authoritative check;
/// an operator picker in the UI is a convenience for the user, never the
/// source of truth for which operator a number belongs to. Returns `null`
/// for any prefix other than Robi's 018 or Cirkle's 016 (Airtel/Grameenphone/
/// Banglalink/Teletalk numbers are all rejected the same way — this app's
/// bdapps subscription isn't configured for them).
BdOperator? bdOperatorForNormalizedPhone(String normalized) {
  if (normalized.length != 13 || !normalized.startsWith('8801')) return null;
  return switch (normalized[4]) {
    '8' => BdOperator.robi,
    '6' => BdOperator.cirkle,
    _ => null,
  };
}

/// A light sanity check — normalizes, then confirms it's a supported
/// operator (Robi/Cirkle) rather than just "13 digits starting with 880".
/// Not a full carrier/format validator, just enough to catch an obviously
/// wrong, empty, or unsupported-operator input before it's sent anywhere.
bool isPlausibleBdPhoneNumber(String raw) {
  return bdOperatorForNormalizedPhone(normalizeBdPhoneNumber(raw)) != null;
}
