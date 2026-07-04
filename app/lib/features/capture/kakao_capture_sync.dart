import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../parcels/models/parcel.dart';
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
    final snapshot = await _ref
        .read(kakaoCaptureBridgeProvider)
        .getLatestCapture();
    if (snapshot == null || !snapshot.isUsable) return false;

    final capturedAt = snapshot.capturedAt;
    final status = ParcelStatus.fromCode(snapshot.status);
    final parcel = Parcel(
      id: '',
      courierCode: snapshot.courierCode,
      trackingNumber: snapshot.trackingNumber,
      status: status,
      mallName: snapshot.sender,
      sourceChannels: const {SourceChannel.kakao},
      expectedArrivalDate: _expectedDate(status, capturedAt),
      deliveredAt: status == ParcelStatus.delivered ? capturedAt : null,
      registeredAt: capturedAt,
    );

    await _ref
        .read(parcelRepositoryProvider)
        .upsert(parcel, eventNote: '카카오톡 알림톡');
    return true;
  }

  DateTime? _expectedDate(ParcelStatus status, DateTime capturedAt) {
    if (status != ParcelStatus.outForDelivery) return null;
    return DateTime(capturedAt.year, capturedAt.month, capturedAt.day);
  }
}
