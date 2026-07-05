import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/system_user_font.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemUserFont.load();
  // Korean date formats are used across list and calendar views.
  await initializeDateFormatting('ko');
  runApp(const ProviderScope(child: CheckShippingApp()));
}
