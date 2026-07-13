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
///
/// Card/mall order placeholders (see [isOrderPlaceholder]) are the one
/// exception: a payment or order confirmation is a point-in-time event,
/// not an ongoing shipment, so it only ever occupies its registration
/// day — carrying it forward would make a same-day-vs-carried-over
/// payment indistinguishable from the calendar alone.
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
    if (isOrderPlaceholder(parcel)) {
      endDay = startDay;
    } else if (parcel.status.isTerminal) {
      // A finished parcel stops occupying days at its terminal moment.
      final terminalTime =
          parcel.deliveredAt ??
          (parcelEvents.isNotEmpty
              ? parcelEvents.last.eventTime
              : parcel.registeredAt);
      endDay = _dateOnly(terminalTime);
    } else {
      endDay = todayDay;
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
