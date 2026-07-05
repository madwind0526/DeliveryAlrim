import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class SystemUserFont {
  static const family = 'SystemUserFont';
  static const _channel = MethodChannel('check_shipping/kakao_capture');

  static String? activeFamily;

  static Future<void> load() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final bytes = await _channel.invokeMethod<Uint8List>(
        'getSamsungFlipFont',
      );
      if (bytes == null || bytes.isEmpty) return;
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      activeFamily = family;
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
