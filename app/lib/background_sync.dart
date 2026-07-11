import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider_android/path_provider_android.dart';

import 'features/capture/kakao_capture_sync.dart';

const _captureChannel = MethodChannel('check_shipping/kakao_capture');

/// Headless entrypoint run by Android's BackgroundCaptureSync when a
/// delivery-looking capture arrives while the app isn't in the
/// foreground. Executes the same parse/merge pipeline the app runs on
/// resume, in a throwaway engine, then tells the native side to tear
/// that engine down.
@pragma('vm:entry-point')
void backgroundCaptureSync() {
  WidgetsFlutterBinding.ensureInitialized();
  // path_provider_android is a federated plugin whose Dart-side platform
  // implementation is normally registered by Flutter's generated main()
  // wrapper. A custom entrypoint like this one bypasses that wrapper, so
  // it must be registered explicitly — drift_flutter needs it to locate
  // the app's documents directory. flutter_secure_storage's Android
  // implementation is a classic (non-federated) plugin already
  // registered natively via GeneratedPluginRegistrant, so it needs no
  // Dart-side call here.
  if (Platform.isAndroid) {
    PathProviderAndroid.registerWith();
  }
  _run();
}

Future<void> _run() async {
  final container = ProviderContainer();
  try {
    final changed = await container
        .read(kakaoCaptureSyncProvider)
        .syncLatest(rescanActiveNotifications: true);
    // Only badge for activity found while the user wasn't looking — this
    // entrypoint only ever runs headless (see BackgroundCaptureSync.kt),
    // so any change here happened without the user seeing it live.
    if (changed > 0) {
      try {
        await _captureChannel.invokeMethod('notifyNewCaptures', {
          'count': changed,
        });
      } on Exception {
        // Non-fatal: the parcel is still saved, just no badge this time.
      }
    }
  } catch (_) {
    // Best-effort: anything left unsynced stays queued for the next
    // attempt (app resume or the next triggered background run).
  } finally {
    container.dispose();
    try {
      await _captureChannel.invokeMethod('backgroundSyncDone');
    } on Exception {
      // Native side has its own timeout fallback if this never arrives.
    }
  }
}
