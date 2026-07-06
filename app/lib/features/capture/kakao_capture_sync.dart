import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
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

  Future<bool> syncLatest() async {
    final bridge = _ref.read(kakaoCaptureBridgeProvider);
    final snapshot = await bridge.getLatestCapture();
    if (snapshot == null || !snapshot.isUsable) return false;

    final capture = snapshot.toCapture();
    final engine = await _ref.read(ruleEngineProvider.future);
    final result = engine.parse(capture);
    if (!result.matched) {
      await bridge.clearLatestCapture();
      return false;
    }

    await _ref
        .read(parcelRepositoryProvider)
        .upsert(result.parcel!.toParcel(capture), eventNote: '카카오톡 알림톡');
    await bridge.clearLatestCapture();
    return true;
  }
}
