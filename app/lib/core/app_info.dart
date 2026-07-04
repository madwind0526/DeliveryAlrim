import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appBuildInfoProvider = FutureProvider<AppBuildInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppBuildInfo(version: info.version, buildNumber: info.buildNumber);
});

class AppBuildInfo {
  final String version;
  final String buildNumber;

  const AppBuildInfo({required this.version, required this.buildNumber});

  String get display {
    if (buildNumber.isEmpty) return version;
    return '$version+$buildNumber';
  }
}
