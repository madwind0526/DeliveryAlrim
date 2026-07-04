import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Korean date formats (M월 d일 (E)) used across list/calendar views.
  await initializeDateFormatting('ko');
  runApp(const ProviderScope(child: CheckShippingApp()));
}
