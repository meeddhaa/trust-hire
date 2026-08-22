import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared date conversion for every model's `fromMap`/`toMap`.
///
/// Models are read from and written to Firestore, which stores dates as
/// [Timestamp], not [DateTime]. Every model needs the same conversion, so it
/// lives here once instead of five copies of the same two-line helper.
///
/// `dateTimeFromValue` also accepts a plain [DateTime] or an ISO-8601
/// [String] so model unit tests can build maps by hand (e.g. from a JSON
/// fixture for seed data) without touching the Firestore SDK.
DateTime dateTimeFromValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw ArgumentError('Cannot convert $value (${value.runtimeType}) to DateTime');
}

/// Nullable counterpart of [dateTimeFromValue], for optional date fields
/// (e.g. a subscription that hasn't renewed yet).
DateTime? dateTimeFromValueOrNull(Object? value) {
  if (value == null) return null;
  return dateTimeFromValue(value);
}

/// Converts a [DateTime] to the [Timestamp] Firestore expects on write.
Timestamp timestampFromDateTime(DateTime dateTime) => Timestamp.fromDate(dateTime);
