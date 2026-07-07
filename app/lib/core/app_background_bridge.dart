import 'package:flutter/services.dart';

class AppBackgroundBridge {
  static const _channel = MethodChannel('check_shipping/app_control');

  static void setGoHomeHandler(Future<void> Function() handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'goHome') {
        await handler();
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
