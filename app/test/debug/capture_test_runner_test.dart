import 'package:check_shipping/core/local_db/local_db.dart';
import 'package:check_shipping/core/providers.dart';
import 'package:check_shipping/features/debug/capture_test_runner.dart';
import 'package:check_shipping/features/debug/capture_test_samples.dart';
import 'package:check_shipping/features/parcels/models/parcel.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gmail and SMS test samples are parsed and stored', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final runner = container.read(captureTestRunnerProvider);
    final gmail = await runner.send(CaptureTestSamples.gmail);
    final sms = await runner.send(CaptureTestSamples.sms);

    expect(gmail.result.matched, isTrue);
    expect(sms.result.matched, isTrue);

    final parcels = await container
        .read(parcelRepositoryProvider)
        .watchAll()
        .first;
    expect(parcels, hasLength(2));
    expect(
      parcels.map((p) => p.sourceChannels).expand((channels) => channels),
      containsAll([SourceChannel.gmail, SourceChannel.sms]),
    );
  });
}
