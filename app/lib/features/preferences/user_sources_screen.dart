import 'package:flutter/material.dart';

import '../../core/strings_ko.dart';

class UserSourcesScreen extends StatefulWidget {
  const UserSourcesScreen({super.key});

  @override
  State<UserSourcesScreen> createState() => _UserSourcesScreenState();
}

class _UserSourcesScreenState extends State<UserSourcesScreen> {
  bool _emailEnabled = false;
  bool _kakaoEnabled = true;
  bool _secureStorage = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(StringsKo.userTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: StringsKo.userEmailSection,
            actionLabel: StringsKo.addSource,
            onPressed: () {},
          ),
          SwitchListTile(
            title: const Text('Gmail'),
            subtitle: Text(
              _emailEnabled
                  ? StringsKo.sourceEnabled
                  : StringsKo.sourceDisabled,
            ),
            value: _emailEnabled,
            onChanged: (value) => setState(() => _emailEnabled = value),
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: StringsKo.userSnsSection,
            actionLabel: StringsKo.addSource,
            onPressed: () {},
          ),
          SwitchListTile(
            title: const Text('카카오톡'),
            subtitle: Text(
              _kakaoEnabled
                  ? StringsKo.sourceEnabled
                  : StringsKo.sourceDisabled,
            ),
            value: _kakaoEnabled,
            onChanged: (value) => setState(() => _kakaoEnabled = value),
          ),
          SwitchListTile(
            title: const Text(StringsKo.userSecureStorage),
            value: _secureStorage,
            onChanged: (value) => setState(() => _secureStorage = value),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onPressed;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}
