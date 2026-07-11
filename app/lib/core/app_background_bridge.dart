import 'package:flutter/services.dart';

class AppBackgroundBridge {
  static const _channel = MethodChannel('check_shipping/app_control');

  /// Registers both native-initiated calls this app responds to:
  /// [onGoHome] for the back-gesture "send to background" request, and
  /// [onSyncNow] when MainActivity.requestForegroundSync() asks the
  /// already-running app to sync a just-captured notification instead of
  /// Android spinning up a separate headless engine for it.
  static void setHandlers({
    required Future<void> Function() onGoHome,
    required Future<void> Function() onSyncNow,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'goHome':
          await onGoHome();
        case 'syncNow':
          await onSyncNow();
      }
    });
  }

  Future<void> moveToBackground() async {
    try {
      await _channel.invokeMethod<void>('moveTaskToBack');
    } on MissingPluginException {
      await SystemNavigator.pop();
    } on PlatformException {
      await SystemNavigator.pop();
    }
  }
}
