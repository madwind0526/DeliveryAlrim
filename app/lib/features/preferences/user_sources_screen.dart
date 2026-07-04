import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings_ko.dart';
import '../capture/kakao_capture_sync.dart';

class UserSourcesScreen extends ConsumerStatefulWidget {
  const UserSourcesScreen({super.key});

  @override
  ConsumerState<UserSourcesScreen> createState() => _UserSourcesScreenState();
}

class _UserSourcesScreenState extends ConsumerState<UserSourcesScreen> {
  bool _emailEnabled = false;
  bool _kakaoEnabled = true;
  bool _secureStorage = true;
  bool _syncingKakao = false;

  Future<void> _syncKakao() async {
    if (_syncingKakao) return;
    setState(() => _syncingKakao = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final synced = await ref.read(kakaoCaptureSyncProvider).syncLatest();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            synced ? StringsKo.userKakaoSyncDone : StringsKo.userKakaoSyncEmpty,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncingKakao = false);
    }
  }

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
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _syncingKakao || !_kakaoEnabled ? null : _syncKakao,
              icon: _syncingKakao
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text(StringsKo.userKakaoSync),
            ),
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
