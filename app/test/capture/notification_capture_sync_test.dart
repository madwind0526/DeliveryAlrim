import 'package:check_shipping/core/local_db/local_db.dart';
import 'package:check_shipping/core/providers.dart';
import 'package:check_shipping/core/secure_credentials.dart';
import 'package:check_shipping/features/capture/kakao_capture_bridge.dart';
import 'package:check_shipping/features/capture/kakao_capture_sync.dart';
import 'package:check_shipping/features/debug/capture_test_samples.dart';
import 'package:check_shipping/features/parcels/models/parcel.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pending Gmail and SMS notification captures sync into parcels',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final bridge = _FakeCaptureBridge([
        _snapshotFrom(
          CaptureTestSamples.gmail,
          packageName: 'com.google.android.gm',
        ),
        _snapshotFrom(
          CaptureTestSamples.sms,
          packageName: 'com.samsung.android.messaging',
        ),
      ]);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          kakaoCaptureBridgeProvider.overrideWithValue(bridge),
          monitorSourceStoreProvider.overrideWithValue(_EnabledMonitorStore()),
        ],
      );
      addTearDown(container.dispose);

      final synced = await container
          .read(kakaoCaptureSyncProvider)
          .syncLatest();

      expect(synced, 2);
      expect(bridge.cleared, isTrue);

      final parcels = await container
          .read(parcelRepositoryProvider)
          .watchAll()
          .first;
      expect(parcels, hasLength(2));
      expect(
        parcels.map((p) => p.sourceChannels).expand((channels) => channels),
        containsAll([SourceChannel.gmail, SourceChannel.sms]),
      );
    },
  );
}

KakaoCaptureSnapshot _snapshotFrom(
  CaptureTestSample sample, {
  required String packageName,
}) {
  return KakaoCaptureSnapshot(
    channel: sample.channel.code,
    packageName: packageName,
    title: sample.title,
    sender: sample.sender,
    body: sample.body,
    capturedAtMillis: DateTime(2026, 7, 7, 10).millisecondsSinceEpoch,
  );
}

class _FakeCaptureBridge extends KakaoCaptureBridge {
  final List<KakaoCaptureSnapshot> captures;
  bool cleared = false;

  _FakeCaptureBridge(this.captures);

  @override
  Future<List<KakaoCaptureSnapshot>> getPendingCaptures() async => captures;

  @override
  Future<void> clearPendingCaptures() async {
    cleared = true;
  }
}

class _EnabledMonitorStore implements MonitorSourceStore {
  @override
  Future<bool> isEnabled(
    MonitorSource source, {
    bool defaultValue = false,
  }) async {
    return true;
  }

  @override
  Future<void> setEnabled(MonitorSource source, bool enabled) async {}
}
