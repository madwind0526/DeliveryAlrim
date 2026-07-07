import 'package:flutter/material.dart';

import 'app_background_bridge.dart';
import 'strings_ko.dart';

class AppBackgroundButton extends StatelessWidget {
  const AppBackgroundButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: StringsKo.sendAppToBackground,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.power_settings_new, size: 22),
      onPressed: () => AppBackgroundBridge().moveToBackground(),
    );
  }
}
