import 'package:flutter/services.dart';

import 'capture_models.dart';

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

  Future<List<KakaoCaptureSnapshot>> getPendingCaptures() async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>(
        'getPendingCaptures',
      );
      return raw
              ?.whereType<Map<dynamic, dynamic>>()
              .map(
                (item) => KakaoCaptureSnapshot.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList() ??
          const [];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
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

  Future<void> clearPendingCaptures() async {
    try {
      await _channel.invokeMethod<void>('clearPendingCaptures');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

class KakaoCaptureSnapshot {
  final String channel;
  final String? packageName;
  final String? title;
  final String? sender;
  final String body;
  final int capturedAtMillis;

  const KakaoCaptureSnapshot({
    required this.channel,
    required this.packageName,
    required this.title,
    required this.sender,
    required this.body,
    required this.capturedAtMillis,
  });

  factory KakaoCaptureSnapshot.fromMap(Map<String, dynamic> raw) {
    return KakaoCaptureSnapshot(
      channel: _stringValue(raw['channel']) ?? CaptureChannel.kakao.code,
      packageName: _stringValue(raw['packageName']),
      title: _stringValue(raw['title']),
      sender: _stringValue(raw['sender']),
      body: _stringValue(raw['body']) ?? '',
      capturedAtMillis: _intValue(raw['capturedAtMillis']),
    );
  }

  bool get isUsable => body.isNotEmpty;

  RawCapture toCapture() {
    return RawCapture(
      channel: CaptureChannel.fromCode(channel),
      packageName: packageName,
      sender: sender,
      title: title,
      body: body,
      capturedAt: capturedAt,
    );
  }

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
