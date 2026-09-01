/// Normalizes a Bangladeshi phone number to the bare-digits form AppsPro's
/// own webhook payloads use internally (e.g. `subscriberId: "tel:8801712345678"`
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
String normalizeBdPhoneNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('880')) return digits;
  if (digits.startsWith('0')) return '880${digits.substring(1)}';
  return '880$digits';
}

/// A light sanity check (11-13 digits after normalization, since a valid
/// BD mobile number is 11 digits as dialed locally or 13 with the 880
/// country code) — not a full carrier/format validator, just enough to
/// catch an obviously-wrong or empty input before it's saved.
bool isPlausibleBdPhoneNumber(String raw) {
  final normalized = normalizeBdPhoneNumber(raw);
  return normalized.length == 13 && normalized.startsWith('880');
}
