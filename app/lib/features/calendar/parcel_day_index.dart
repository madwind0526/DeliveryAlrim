import 'package:flutter/foundation.dart';

import '../parcels/models/order_placeholder.dart';
import '../parcels/models/parcel.dart';
import '../parcels/models/tracking_event.dart';

/// One parcel as it appeared on a specific calendar day.
@immutable
class DayParcelEntry {
  final Parcel parcel;

  /// Date-only day this entry belongs to.
  final DateTime day;

  /// Status the parcel had at the end of [day], reconstructed from the
  /// tracking-event log (not the parcel's current status).
  final ParcelStatus statusOnDay;

  /// True for future-day entries that only preview an expected arrival.
  final bool isExpectedPreview;

  const DayParcelEntry({
    required this.parcel,
    required this.day,
    required this.statusOnDay,
    this.isExpectedPreview = false,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Builds the calendar index: day → parcels visible that day with their
/// as-of-that-day status.
///
/// A parcel occupies every day from its registration until it reaches a
/// terminal status (delivered/expired/invalid); while still active it
/// carries forward up to [today]. The status shown for a past day is the
/// last tracking event recorded up to the end of that day, so updating a
/// parcel later never rewrites how earlier days looked. Active parcels
/// with a future expected arrival additionally appear on that future day
/// as a preview.
Map<DateTime, List<DayParcelEntry>> buildParcelDayIndex({
  required List<Parcel> parcels,
  required List<TrackingEvent> events,
  required DateTime today,
}) {
  final todayDay = _dateOnly(today);

  // Group events per parcel, sorted oldest-first for the day scan.
  final eventsByParcel = <String, List<TrackingEvent>>{};
  for (final e in events) {
    (eventsByParcel[e.parcelId] ??= []).add(e);
  }
  for (final list in eventsByParcel.values) {
    list.sort((a, b) => a.eventTime.compareTo(b.eventTime));
  }

  final index = <DateTime, List<DayParcelEntry>>{};

  // Pre-normalize every non-placeholder parcel's match text once, up
  // front, instead of re-lowercasing/stripping the same strings on every
  // placeholder × candidate comparison inside the loop below.
  final resolveCandidates = [
    for (final p in parcels)
      if (!isOrderPlaceholder(p)) _ResolveCandidate.from(p),
  ];

  for (final parcel in parcels) {
    final parcelEvents = eventsByParcel[parcel.id] ?? const <TrackingEvent>[];

    final startDay = _dateOnly(parcel.registeredAt);
    DateTime endDay;
    if (parcel.status.isTerminal) {
      // A finished parcel stops occupying days at its terminal moment.
      final terminalTime =
          parcel.deliveredAt ??
          (parcelEvents.isNotEmpty
              ? parcelEvents.last.eventTime
              : parcel.registeredAt);
      endDay = _dateOnly(terminalTime);
    } else {
      endDay = todayDay;
      // Card/mall order placeholders have no shipment info of their own
      // and no reliable ID to link to the real courier notification that
      // eventually arrives (different systems, nothing shared). Best
      // effort: if a real shipment registered on or after this order
      // looks like the same purchase (matching mall/product text), stop
      // carrying the placeholder forward from that shipment's day —
      // earlier days keep showing it as registered, unaffected.
      if (isOrderPlaceholder(parcel)) {
        final resolvedEnd = _resolvedEndDay(parcel, resolveCandidates);
        if (resolvedEnd != null && resolvedEnd.isBefore(endDay)) {
          endDay = resolvedEnd;
        }
      }
    }
    if (endDay.isBefore(startDay)) endDay = startDay;

    for (
      var day = startDay;
      !day.isAfter(endDay);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      (index[day] ??= []).add(
        DayParcelEntry(
          parcel: parcel,
          day: day,
          statusOnDay: _statusAtEndOf(day, parcelEvents, parcel),
        ),
      );
    }

    // Preview a future expected arrival for parcels still in flight.
    final expected = parcel.expectedArrivalDate;
    if (!parcel.status.isTerminal && expected != null) {
      final expectedDay = _dateOnly(expected);
      if (expectedDay.isAfter(todayDay)) {
        (index[expectedDay] ??= []).add(
          DayParcelEntry(
            parcel: parcel,
            day: expectedDay,
            statusOnDay: parcel.status,
            isExpectedPreview: true,
          ),
        );
      }
    }
  }

  return index;
}

/// Status as of the end of [day]: the last event recorded up to that
/// moment. Parcels captured before the event log existed have no events,
/// so fall back to the current status.
ParcelStatus _statusAtEndOf(
  DateTime day,
  List<TrackingEvent> sortedEvents,
  Parcel parcel,
) {
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  ParcelStatus? status;
  for (final e in sortedEvents) {
    if (!e.eventTime.isBefore(dayEnd)) break;
    status = e.status;
  }
  if (status != null) return status;
  if (sortedEvents.isNotEmpty) return sortedEvents.first.status;
  return parcel.status;
}

/// A non-placeholder parcel's registration time plus its match text,
/// normalized once so [_resolvedEndDay] never re-normalizes the same
/// mallName/productName on every placeholder it's compared against.
class _ResolveCandidate {
  final DateTime registeredAt;
  final String? mallName;
  final String? productName;

  const _ResolveCandidate({
    required this.registeredAt,
    required this.mallName,
    required this.productName,
  });

  factory _ResolveCandidate.from(Parcel p) => _ResolveCandidate(
    registeredAt: p.registeredAt,
    mallName: p.mallName == null
        ? null
        : normalizeForOrderMatch(p.mallName!),
    productName: p.productName == null
        ? null
        : normalizeForOrderMatch(p.productName!),
  );
}

/// Earliest day an order [placeholder] should stop being carried forward,
/// or null if no matching real shipment has shown up yet, checked against
/// the pre-normalized [candidates] (every non-placeholder parcel). The
/// match is deliberately best-effort since there is no shared ID between
/// a card/mall order alert and the courier's own notification.
DateTime? _resolvedEndDay(
  Parcel placeholder,
  List<_ResolveCandidate> candidates,
) {
  final placeholderMall = placeholder.mallName == null
      ? null
      : normalizeForOrderMatch(placeholder.mallName!);
  final placeholderProduct = placeholder.productName == null
      ? null
      : normalizeForOrderMatch(placeholder.productName!);

  _ResolveCandidate? resolver;
  for (final candidate in candidates) {
    if (candidate.registeredAt.isBefore(placeholder.registeredAt)) continue;
    final sameAsCandidate =
        orderMatchTextOverlaps(placeholderMall, candidate.mallName) ||
        orderMatchTextOverlaps(placeholderProduct, candidate.productName) ||
        orderMatchTextOverlaps(placeholderMall, candidate.productName) ||
        orderMatchTextOverlaps(placeholderProduct, candidate.mallName);
    if (!sameAsCandidate) continue;
    if (resolver == null ||
        candidate.registeredAt.isBefore(resolver.registeredAt)) {
      resolver = candidate;
    }
  }
  if (resolver == null) return null;
  return _dateOnly(resolver.registeredAt).subtract(const Duration(days: 1));
}
