import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../capture/capture_models.dart';
import '../capture/rules_provider.dart';
import 'capture_test_samples.dart';

final captureTestRunnerProvider = Provider<CaptureTestRunner>(
  (ref) => CaptureTestRunner(ref),
);

class CaptureTestRunner {
  final Ref _ref;

  CaptureTestRunner(this._ref);

  Future<CaptureTestOutcome> send(CaptureTestSample sample) async {
    final engine = await _ref.read(ruleEngineProvider.future);
    final capture = sample.toCapture(DateTime.now());
    final result = engine.parse(capture);

    if (result.matched) {
      await _ref
          .read(parcelRepositoryProvider)
          .upsert(
            result.parcel!.toParcel(capture),
            eventNote: '${sample.labelKo} 테스트 주입',
          );
    }

    return CaptureTestOutcome(sample: sample, capture: capture, result: result);
  }
}

class CaptureTestOutcome {
  final CaptureTestSample sample;
  final RawCapture capture;
  final ParseResult result;

  const CaptureTestOutcome({
    required this.sample,
    required this.capture,
    required this.result,
  });
}
