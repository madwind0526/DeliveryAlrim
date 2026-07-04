import 'package:flutter/foundation.dart';

import 'parcel.dart';

/// One entry on a parcel's status timeline.
@immutable
class TrackingEvent {
  final int? id;
  final String parcelId;
  final DateTime eventTime;
  final ParcelStatus status;
  final String? location;
  final String? description;

  const TrackingEvent({
    this.id,
    required this.parcelId,
    required this.eventTime,
    required this.status,
    this.location,
    this.description,
  });
}
