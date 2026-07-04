import 'package:flutter/services.dart';

class KakaoCaptureBridge {
  static const _channel = MethodChannel('check_shipping/kakao_capture');

  Future<KakaoCaptureSnapshot?> getLatestCapture() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getLatestCapture',
      );
      return raw == null ? null : KakaoCaptureSnapshot.fromMap(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> clearLatestCapture() async {
    try {
      await _channel.invokeMethod<void>('clearLatestCapture');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

class KakaoCaptureSnapshot {
  final String courierCode;
  final String trackingNumber;
  final String status;
  final String? sender;
  final int capturedAtMillis;

  const KakaoCaptureSnapshot({
    required this.courierCode,
    required this.trackingNumber,
    required this.status,
    required this.sender,
    required this.capturedAtMillis,
  });

  factory KakaoCaptureSnapshot.fromMap(Map<String, dynamic> raw) {
    return KakaoCaptureSnapshot(
      courierCode: _stringValue(raw['courierCode']) ?? 'unknown',
      trackingNumber: _stringValue(raw['trackingNumber']) ?? '',
      status: _stringValue(raw['status']) ?? 'registered',
      sender: _stringValue(raw['sender']),
      capturedAtMillis: _intValue(raw['capturedAtMillis']),
    );
  }

  bool get isUsable => trackingNumber.isNotEmpty;

  DateTime get capturedAt {
    if (capturedAtMillis <= 0) return DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(capturedAtMillis);
  }

  static String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
