import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/secure_credentials.dart';
import 'capture_models.dart';
import 'quarantine_store.dart';
import 'rules_provider.dart';
import 'kakao_capture_bridge.dart';

final kakaoCaptureBridgeProvider = Provider<KakaoCaptureBridge>(
  (ref) => KakaoCaptureBridge(),
);

final kakaoCaptureSyncProvider = Provider<KakaoCaptureSync>(
  (ref) => KakaoCaptureSync(ref),
);

class KakaoCaptureSync {
  final Ref _ref;

  KakaoCaptureSync(this._ref);

  Future<bool> syncLatest({bool rescanActiveNotifications = false}) async {
    final bridge = _ref.read(kakaoCaptureBridgeProvider);
    if (rescanActiveNotifications) {
      await bridge.scanActiveNotifications();
    }
    final pending = await bridge.getPendingCaptures();
    final latest = pending.isEmpty ? await bridge.getLatestCapture() : null;
    final snapshots = pending.isNotEmpty ? pending : [?latest];
    if (snapshots.isEmpty) return false;

    final engine = await _ref.read(ruleEngineProvider.future);
    var synced = false;
    for (final snapshot in snapshots) {
      if (!snapshot.isUsable) continue;
      final capture = snapshot.toCapture();
      if (!await _sourceEnabled(capture)) continue;

      final result = engine.parse(capture);
      if (result.reason == ParseRejectReason.suspectedPhishing) {
        await _ref
            .read(quarantineStoreProvider)
            .add(
              capture,
              reason: result.screeningNote ?? ParseRejectReason.suspectedPhishing.labelKo,
            );
        continue;
      }
      if (!result.matched) continue;

      await _ref
          .read(parcelRepositoryProvider)
          .upsert(
            result.parcel!.toParcel(capture),
            eventNote: _eventNote(capture),
          );
      synced = true;
    }

    await bridge.clearPendingCaptures();
    return synced;
  }

  Future<bool> _sourceEnabled(RawCapture capture) {
    final source = switch (capture.channel) {
      CaptureChannel.kakao => MonitorSource.kakao,
      CaptureChannel.sms => MonitorSource.sms,
      CaptureChannel.gmail =>
        _isGmailPackage(capture.packageName)
            ? MonitorSource.gmail
            : MonitorSource.otherEmail,
      CaptureChannel.mallApp => MonitorSource.otherEmail,
    };
    final defaultValue = source == MonitorSource.kakao;
    return _ref
        .read(monitorSourceStoreProvider)
        .isEnabled(source, defaultValue: defaultValue);
  }

  bool _isGmailPackage(String? packageName) =>
      packageName == 'com.google.android.gm';

  String _eventNote(RawCapture capture) => switch (capture.channel) {
    CaptureChannel.kakao => '카카오톡 알림톡',
    CaptureChannel.sms => 'SMS 알림',
    CaptureChannel.gmail =>
      _isGmailPackage(capture.packageName) ? 'Gmail 알림' : '이메일 알림',
    CaptureChannel.mallApp => '앱 알림',
  };
}
