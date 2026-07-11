import 'dart:convert';

import 'package:http/http.dart' as http;

import '../parcels/models/parcel.dart';

/// One row of the courier-side tracking history from the API.
class TrackingDetail {
  final DateTime? time;
  final String? where;
  final String? kind;
  final ParcelStatus status;

  const TrackingDetail({
    required this.time,
    required this.where,
    required this.kind,
    required this.status,
  });
}

/// Parsed result of one trackingInfo query.
class TrackingQueryResult {
  final ParcelStatus status;
  final bool complete;
  final String? itemName;
  final List<TrackingDetail> details;

  const TrackingQueryResult({
    required this.status,
    required this.complete,
    this.itemName,
    this.details = const [],
  });

  TrackingDetail? get lastDetail => details.isEmpty ? null : details.last;
}

class SweettrackerException implements Exception {
  final String message;
  const SweettrackerException(this.message);

  @override
  String toString() => message;
}

/// Thin client for the Sweet Tracker trackingInfo API.
/// Optional feature: only used when the user registered an API key.
/// The free key is rate-limited (~100 calls/day), so callers must go
/// through the daily quota guard — never poll this in a loop.
class SweettrackerClient {
  static const _host = 'info.sweettracker.co.kr';

  final http.Client _http;

  SweettrackerClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  /// Queries one invoice. [courierApiCode] is the Sweet Tracker company
  /// code (Courier.sweettrackerCode), not the app's courier code.
  Future<TrackingQueryResult> fetchTrackingInfo({
    required String apiKey,
    required String courierApiCode,
    required String invoice,
  }) async {
    final uri = Uri.https(_host, '/api/v1/trackingInfo', {
      't_key': apiKey,
      't_code': courierApiCode,
      't_invoice': invoice,
    });

    final http.Response response;
    try {
      response = await _http.get(uri).timeout(const Duration(seconds: 15));
    } on Exception {
      throw const SweettrackerException('네트워크 오류로 조회하지 못했습니다');
    }
    if (response.statusCode != 200) {
      throw SweettrackerException('조회 서버 오류 (HTTP ${response.statusCode})');
    }
    return parseResponse(utf8.decode(response.bodyBytes));
  }

  /// Parses a raw trackingInfo JSON body. Split out for fixture tests.
  static TrackingQueryResult parseResponse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SweettrackerException('조회 응답을 해석할 수 없습니다');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SweettrackerException('조회 응답을 해석할 수 없습니다');
    }

    // Error responses carry code/msg (invalid invoice, bad key, quota)
    // and no level field.
    final level = decoded['level'];
    if (level is! num) {
      final msg = decoded['msg'];
      throw SweettrackerException(
        msg is String && msg.isNotEmpty ? msg : '조회에 실패했습니다',
      );
    }

    final details = <TrackingDetail>[];
    final rawDetails = decoded['trackingDetails'];
    if (rawDetails is List) {
      for (final raw in rawDetails) {
        if (raw is! Map<String, dynamic>) continue;
        details.add(
          TrackingDetail(
            time: _detailTime(raw),
            where: raw['where'] as String?,
            kind: raw['kind'] as String?,
            status: ParcelStatus.fromSweettrackerLevel(
              (raw['level'] as num?)?.toInt(),
            ),
          ),
        );
      }
      // A null time carries no ordering signal, so it can't just compare
      // equal to everything (that's not transitive and can leave dated
      // entries out of order around it) — sort unknown-time entries first
      // so `lastDetail` prefers a dated entry over an undated one.
      details.sort((a, b) {
        final at = a.time;
        final bt = b.time;
        if (at == null && bt == null) return 0;
        if (at == null) return -1;
        if (bt == null) return 1;
        return at.compareTo(bt);
      });
    }

    return TrackingQueryResult(
      status: ParcelStatus.fromSweettrackerLevel(level.toInt()),
      complete: decoded['complete'] == true || decoded['completeYN'] == 'Y',
      itemName: decoded['itemName'] as String?,
      details: details,
    );
  }

  /// Detail rows carry epoch-millis `time` and a human `timeString`;
  /// prefer the numeric one.
  static DateTime? _detailTime(Map<String, dynamic> raw) {
    final time = raw['time'];
    if (time is num && time > 0) {
      return DateTime.fromMillisecondsSinceEpoch(time.toInt());
    }
    final timeString = raw['timeString'];
    if (timeString is String) return DateTime.tryParse(timeString);
    return null;
  }

  void close() => _http.close();
}
