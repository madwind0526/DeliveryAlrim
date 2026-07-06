import 'package:flutter/material.dart';

/// Delivery status. Order matters: transitions are monotonic —
/// a parcel never moves to a status with a lower index (docs/DESIGN.md §4).
enum ParcelStatus {
  registered('registered', '등록됨'),
  preparing('preparing', '상품준비'),
  pickedUp('picked_up', '집화'),
  inTransit('in_transit', '배송중'),
  outForDelivery('out_for_delivery', '배송출발'),
  delivered('delivered', '배달완료'),
  expired('expired', '만료'),
  invalid('invalid', '번호오류');

  final String code;
  final String labelKo;
  const ParcelStatus(this.code, this.labelKo);

  static ParcelStatus fromCode(String code) =>
      values.firstWhere((s) => s.code == code, orElse: () => registered);

  /// Maps Sweet Tracker's raw numeric level to the local status enum.
  static ParcelStatus fromSweettrackerLevel(int? level) => switch (level) {
    1 => preparing,
    2 => pickedUp,
    3 || 4 => inTransit,
    5 => outForDelivery,
    6 => delivered,
    _ => registered,
  };

  /// Statuses shown in the terminal tab and excluded from polling.
  bool get isTerminal =>
      this == delivered || this == expired || this == invalid;

  /// Monotonic guard: only allow forward transitions.
  bool canTransitionTo(ParcelStatus next) => next.index > index;

  Color get color => switch (this) {
    registered || preparing => const Color(0xFF9E9E9E),
    pickedUp || inTransit => const Color(0xFF42A5F5),
    outForDelivery => const Color(0xFF7C6AF7),
    delivered => const Color(0xFF4ADE80),
    expired || invalid => const Color(0xFFF87171),
  };
}

/// Source channel a parcel was captured from.
abstract final class SourceChannel {
  static const kakao = 'kakao';
  static const sms = 'sms';
  static const gmail = 'gmail';
  static const coupangApp = 'coupang_app';
  static const manual = 'manual';
}

/// Domain model for one delivery.
@immutable
class Parcel {
  final String id;
  final String courierCode;
  final String trackingNumber;
  final ParcelStatus status;
  final String? productName;
  final String? mallName;
  final Set<String> sourceChannels;
  final DateTime? expectedArrivalDate;
  final DateTime? deliveredAt;
  final DateTime registeredAt;

  const Parcel({
    required this.id,
    required this.courierCode,
    required this.trackingNumber,
    required this.status,
    this.productName,
    this.mallName,
    this.sourceChannels = const {},
    this.expectedArrivalDate,
    this.deliveredAt,
    required this.registeredAt,
  });

  Parcel copyWith({
    ParcelStatus? status,
    String? productName,
    String? mallName,
    Set<String>? sourceChannels,
    DateTime? expectedArrivalDate,
    DateTime? deliveredAt,
  }) {
    return Parcel(
      id: id,
      courierCode: courierCode,
      trackingNumber: trackingNumber,
      status: status ?? this.status,
      productName: productName ?? this.productName,
      mallName: mallName ?? this.mallName,
      sourceChannels: sourceChannels ?? this.sourceChannels,
      expectedArrivalDate: expectedArrivalDate ?? this.expectedArrivalDate,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      registeredAt: registeredAt,
    );
  }

  /// Merge a re-captured sighting of the same parcel into this one:
  /// union channels, fill missing fields, advance status monotonically.
  /// [other] is the newer sighting, so its dates win when present
  /// (an arrival estimate can shift between notifications).
  Parcel merge(Parcel other) {
    return copyWith(
      status: status.canTransitionTo(other.status) ? other.status : status,
      productName: productName ?? other.productName,
      mallName: mallName ?? other.mallName,
      sourceChannels: {...sourceChannels, ...other.sourceChannels},
      expectedArrivalDate: other.expectedArrivalDate ?? expectedArrivalDate,
      deliveredAt: deliveredAt ?? other.deliveredAt,
    );
  }
}
