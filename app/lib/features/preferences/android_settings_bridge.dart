import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidSettingsBridge {
  static const _channel = MethodChannel('check_shipping/system_settings');

  Future<LocalPermissionState> readState() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const LocalPermissionState(
        notificationAccess: false,
        accessibilityAccess: false,
      );
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('readState');
      return LocalPermissionState.fromMap(raw ?? const {});
    } on MissingPluginException {
      return const LocalPermissionState(
        notificationAccess: false,
        accessibilityAccess: false,
      );
    } on PlatformException {
      return const LocalPermissionState(
        notificationAccess: false,
        accessibilityAccess: false,
      );
    }
  }

  Future<bool> openNotificationAccessSettings() async {
    return _open('openNotificationAccessSettings');
  }

  Future<bool> openAccessibilitySettings() async {
    return _open('openAccessibilitySettings');
  }

  Future<bool> _open(String method) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

class LocalPermissionState {
  final bool notificationAccess;
  final bool accessibilityAccess;

  const LocalPermissionState({
    required this.notificationAccess,
    required this.accessibilityAccess,
  });

  factory LocalPermissionState.fromMap(Map<String, dynamic> raw) {
    return LocalPermissionState(
      notificationAccess: raw['notificationAccess'] == true,
      accessibilityAccess: raw['accessibilityAccess'] == true,
    );
  }
}
