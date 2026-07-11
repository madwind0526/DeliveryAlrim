import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/system_user_font.dart';
// Not called from here — importing pulls this library into the release
// AOT snapshot so Android's headless FlutterEngine can resolve
// 'package:check_shipping/background_sync.dart' by URI and run its
// @pragma('vm:entry-point') entrypoint (see BackgroundCaptureSync.kt).
// ignore: unused_import
import 'background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemUserFont.load();
  // Korean date formats are used across list and calendar views.
  await initializeDateFormatting('ko');
  runApp(const ProviderScope(child: CheckShippingApp()));
}
