import 'package:flutter/material.dart';

import '../../core/strings_ko.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _accessibility = true;
  String _mode = StringsKo.settingModeLocal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(StringsKo.settingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: StringsKo.settingModeLocal,
                label: Text(StringsKo.settingModeLocal),
                icon: Icon(Icons.storage),
              ),
              ButtonSegment(
                value: StringsKo.settingModeDebug,
                label: Text(StringsKo.settingModeDebug),
                icon: Icon(Icons.science_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() {
              _mode = value.single;
            }),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text(StringsKo.settingNotifications),
            value: _notifications,
            onChanged: (value) => setState(() => _notifications = value),
          ),
          SwitchListTile(
            title: const Text(StringsKo.settingAccessibility),
            value: _accessibility,
            onChanged: (value) => setState(() => _accessibility = value),
          ),
        ],
      ),
    );
  }
}
