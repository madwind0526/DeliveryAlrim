import 'package:flutter/foundation.dart';

import '../../core/constants/couriers.dart';
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
      if (_isOrderPlaceholder(parcel)) {
        final resolvedEnd = _resolvedEndDay(parcel, parcels);
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

bool _isOrderPlaceholder(Parcel p) =>
    p.courierCode == Couriers.cardOrder.code ||
    p.courierCode == Couriers.mallOrder.code;

/// Loose text match: lowercased, whitespace/punctuation stripped, then
/// containment either direction. Real shipment text never matches an
/// order-confirmation's wording exactly, so this stays forgiving on
/// purpose — it only needs to avoid matching unrelated orders, not be
/// precise about *how* similar two strings are.
String _normalizeForMatch(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s\W]+'), '');

bool _sameOrderText(String? a, String? b) {
  if (a == null || b == null) return false;
  final na = _normalizeForMatch(a);
  final nb = _normalizeForMatch(b);
  if (na.length < 2 || nb.length < 2) return false;
  return na.contains(nb) || nb.contains(na);
}

bool _looksLikeSamePurchase(Parcel placeholder, Parcel candidate) =>
    _sameOrderText(placeholder.mallName, candidate.mallName) ||
    _sameOrderText(placeholder.productName, candidate.productName);

/// Earliest day an order [placeholder] should stop being carried forward,
/// or null if no matching real shipment has shown up yet. The match is
/// deliberately best-effort (see [_looksLikeSamePurchase]) since there is
/// no shared ID between a card/mall order alert and the courier's own
/// notification.
DateTime? _resolvedEndDay(Parcel placeholder, List<Parcel> allParcels) {
  Parcel? resolver;
  for (final other in allParcels) {
    if (other.id == placeholder.id) continue;
    if (_isOrderPlaceholder(other)) continue;
    if (other.registeredAt.isBefore(placeholder.registeredAt)) continue;
    if (!_looksLikeSamePurchase(placeholder, other)) continue;
    if (resolver == null || other.registeredAt.isBefore(resolver.registeredAt)) {
      resolver = other;
    }
  }
  if (resolver == null) return null;
  return _dateOnly(resolver.registeredAt).subtract(const Duration(days: 1));
}
